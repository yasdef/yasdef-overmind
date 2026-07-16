import { mkdirSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { runFeatureFlow, type FeatureFlowDeps } from "../src/orchestrator/index.js";
import {
  defaultStepExecutorDeps,
  type StepBindings,
  type StepResult
} from "../src/runner/index.js";
import { StubAgentRunner } from "../src/runner/agent-runner.js";
import type { ConfirmRequest } from "../src/interaction/index.js";
import type { StepDefinition } from "../src/sequencing/step-catalog.js";
import { CHECKPOINT_LABELS, type CheckpointResult, type ProjectGitPort } from "../src/git/index.js";
import { writeFeatureState } from "../src/state/index.js";
import {
  RecordingCheckpoint,
  RecordingTerminalChain,
  StubInteraction,
  passingTerminalChain,
  seedCompleteFeature,
  stubExecutorDeps,
  withWorkspace
} from "./orchestrator-fixtures.js";

interface FakeExecutorOptions {
  failStep?: string;
  /** step 3 creates this complete feature and returns its path. */
  scaffoldComplete?: { projectDir: string; root: string; name: string };
}

function fakeExecutor(options: FakeExecutorOptions = {}): {
  calls: Array<{ id: string; targetClass?: string }>;
  execute: (step: StepDefinition, bindings: StepBindings) => Promise<StepResult>;
} {
  const calls: Array<{ id: string; targetClass?: string }> = [];
  const execute = async (step: StepDefinition, bindings: StepBindings): Promise<StepResult> => {
    calls.push({
      id: step.id,
      ...(bindings.targetClass ? { targetClass: bindings.targetClass } : {})
    });

    if (step.id === "7" && bindings.targetClass) {
      writeFileSync(
        path.join(
          bindings.runtimeRoot,
          bindings.featurePath,
          `project_surface_struct_resp_map_${bindings.targetClass}.md`
        ),
        "# map\n"
      );
    }

    if (step.id === "3" && options.scaffoldComplete) {
      const featureDir = seedCompleteFeature(
        options.scaffoldComplete.projectDir,
        options.scaffoldComplete.name
      );
      const featurePath = path.relative(options.scaffoldComplete.root, featureDir);
      return {
        stepId: "3",
        ok: true,
        exitCode: 0,
        diagnostics: [],
        actionResults: [
          { action: step.actions[0]!, status: "success", exitCode: 0, diagnostics: [], featurePath }
        ]
      };
    }

    const fail = options.failStep === step.id;
    return {
      stepId: step.id,
      ok: !fail,
      exitCode: fail ? 2 : 0,
      diagnostics: fail ? [{ severity: "error", source: "test", reason: `${step.id} boom` }] : [],
      actionResults: []
    };
  };
  return { calls, execute };
}

/**
 * A checkpoint result that both reports a dirty worktree and commits, so a test
 * exercises the prompted completion boundary rather than its clean-tree shortcut.
 */
function committedResult(): CheckpointResult {
  return { kind: "committed", message: `Checkpoint: ${CHECKPOINT_LABELS.featureCompletion}` };
}

function seedFeature(projectDir: string, name: string, extras: string[] = []): string {
  const dir = path.join(projectDir, name);
  mkdirSync(dir, { recursive: true });
  writeFileSync(
    path.join(dir, "feature_br_summary.md"),
    "## 1. Document Meta\n- feature_title: WIP\n- ready_to_ears: false\n"
  );
  for (const extra of extras) writeFileSync(path.join(dir, extra), "# x\n");
  return dir;
}

function baseDeps(
  root: string,
  projectDir: string,
  projectPathRel: string,
  interaction: StubInteraction,
  overrides: Partial<FeatureFlowDeps>
): { deps: FeatureFlowDeps; lines: string[] } {
  const lines: string[] = [];
  const deps: FeatureFlowDeps = {
    workspaceRoot: root,
    projectRoot: projectDir,
    projectPathRel,
    interaction,
    executorDeps: stubExecutorDeps(),
    checkpoint: new RecordingCheckpoint(),
    clock: { now: () => 1 },
    overmindCliPath: path.join(root, ".overmind", "overmind.js"),
    modelsPath: path.join(root, ".setup", "models.md"),
    // Seeded features hold placeholder artifacts that would fail the real
    // deterministic gates; orchestration tests that care about terminal
    // enforcement override this explicitly.
    terminalGateChain: passingTerminalChain,
    emit: (line) => lines.push(line),
    emitError: (line) => lines.push(line),
    ...overrides
  };
  return { deps, lines };
}

test("phases execute in catalog order with checkpoints at the right boundaries", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1", ["project_surface_struct_resp_map_backend.md"]);
    const rel = path.join(projectPathRel, "wip-1");
    const fake = fakeExecutor();
    const checkpoint = new RecordingCheckpoint(committedResult(), { forbiddenRoots: [root] });
    const interaction = new StubInteraction([
      "continue",
      rel,
      true, // 5
      true, // 5.1
      true, // 6
      true, // 7 (confirm before per-class loop)
      "forward", // 7 loop
      true, // 7.1
      true, // 8
      true, // 8.1
      true, // 8.2
      true, // 8.3
      true, // 8.4
      true // completion commit boundary
    ]);
    const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "5",
      executeStep: fake.execute,
      checkpoint
    });
    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "completed");
    assert.deepEqual(
      fake.calls.map((call) => call.id),
      ["5", "5.1", "6", "7.1", "8", "8.1", "8.2", "8.3", "8.4"]
    );
    // Step 7 had a completed class and none pending -> the analyze option is absent.
    assert.ok(lines.some((line) => /Pending classes: none/.test(line)));
    assert.ok(
      interaction.selectRequests.some(
        (opts) => opts.includes("forward") && !opts.includes("analyze")
      ),
      "phase 7 with no pending classes must not offer the analyze option"
    );
    assert.deepEqual(checkpoint.labels, [
      CHECKPOINT_LABELS.before51,
      CHECKPOINT_LABELS.before71,
      CHECKPOINT_LABELS.before84,
      CHECKPOINT_LABELS.featureCompletion
    ]);
    assert.deepEqual(checkpoint.roots, [projectDir, projectDir, projectDir, projectDir]);
  });
});

test("non-worktree checkpoint notices render and the feature flow continues", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1", ["project_surface_struct_resp_map_backend.md"]);
    const rel = path.join(projectPathRel, "wip-1");
    const fake = fakeExecutor();
    const checkpoint = new RecordingCheckpoint({ kind: "notWorktree" }, { forbiddenRoots: [root] });
    const interaction = new StubInteraction([
      "continue",
      rel,
      true, // 5
      true, // 5.1
      true, // 6
      true, // 7
      "forward",
      true, // 7.1
      true, // 8
      true, // 8.1
      true, // 8.2
      true, // 8.3
      true, // 8.4
      true // completion commit boundary
    ]);
    const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "5",
      executeStep: fake.execute,
      checkpoint
    });
    const outcome = await runFeatureFlow(deps);

    assert.equal(outcome.kind, "completed");
    assert.deepEqual(checkpoint.roots, [projectDir, projectDir, projectDir, projectDir]);
    assert.equal(
      lines.filter((line) => /repository root is not a git worktree/.test(line)).length,
      4
    );
    assert.ok(lines.every((line) => !/runtime root/.test(line)));
  });
});

test("a default run (no resume) starts at the typed next step", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    // Complete feature minus implementation_plan.md -> next step is 8.3.
    const featureDir = seedCompleteFeature(projectDir, "wip-1");
    rmSync(path.join(featureDir, "implementation_plan.md"));
    const rel = path.join(projectPathRel, "wip-1");
    const fake = fakeExecutor();
    const interaction = new StubInteraction(["continue", rel, true, true]); // 8.3, 8.4
    const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
      executeStep: fake.execute
    });
    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "completed");
    assert.deepEqual(
      fake.calls.map((call) => call.id),
      ["8.3", "8.4"]
    );
  });
});

test("a phase-7 analyze failure stops with the phase-7 resume step", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1"); // backend pending
    const rel = path.join(projectPathRel, "wip-1");
    const fake = fakeExecutor({ failStep: "7" });
    const interaction = new StubInteraction(["continue", rel, true, "analyze"]);
    const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "7",
      executeStep: fake.execute
    });
    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "failed");
    if (outcome.kind === "failed") assert.equal(outcome.resumeStep, "7");
  });
});

test("declining an optional phase before required work skips and continues", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1", ["project_surface_struct_resp_map_backend.md"]);
    const rel = path.join(projectPathRel, "wip-1");
    const fake = fakeExecutor();
    const interaction = new StubInteraction(["continue", rel, true, false, false]);
    const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "5",
      executeStep: fake.execute
    });
    const outcome = await runFeatureFlow(deps);
    // 5 confirmed, 5.1 declined (skipped), 6 declined (required -> stop).
    assert.equal(outcome.kind, "stoppedByOperator");
    assert.ok(lines.some((line) => /Optional phase declined at 5.1; skipping\./.test(line)));
    assert.ok(lines.some((line) => /user denied phase progression at 6/.test(line)));
    assert.deepEqual(
      fake.calls.map((call) => call.id),
      ["5"]
    );
  });
});

test("declining the final optional phase finishes cleanly and reaches the completion boundary", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const checkpoint = new RecordingCheckpoint(committedResult(), { forbiddenRoots: [root] });
    const interaction = new StubInteraction(["continue", rel, false, true]);
    const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "8.4",
      executeStep: fakeExecutor().execute,
      checkpoint
    });
    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "finished");
    assert.ok(
      lines.some((line) =>
        /no remaining required phases after declined optional phase 8.4/.test(line)
      )
    );
    assert.deepEqual(checkpoint.labels, [
      CHECKPOINT_LABELS.before84,
      CHECKPOINT_LABELS.featureCompletion
    ]);
    assert.deepEqual(checkpoint.roots, [projectDir, projectDir]);
  });
});

test("closing the input stream during a confirmation stops cleanly", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const interaction = new StubInteraction(["continue", rel]); // nothing left for the 6 confirm
    const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "6",
      executeStep: fakeExecutor().execute
    });
    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "stoppedByOperator");
    assert.ok(lines.some((line) => /input stream closed during confirmation at 6/.test(line)));
  });
});

/**
 * Executor double for a review step whose post-session mutable-artifact gate fails
 * with the given classification. Records calls so tests can prove no auto-retry.
 */
function gateFailingExecutor(
  stepId: string,
  exitCode: number
): {
  calls: string[];
  execute: (step: StepDefinition, bindings: StepBindings) => Promise<StepResult>;
} {
  const calls: string[] = [];
  const execute = async (step: StepDefinition): Promise<StepResult> => {
    calls.push(step.id);
    if (step.id !== stepId) {
      return { stepId: step.id, ok: true, exitCode: 0, diagnostics: [], actionResults: [] };
    }
    return {
      stepId: step.id,
      ok: false,
      exitCode,
      diagnostics: [
        {
          severity: "error",
          source: "step-executor:post-session-gate",
          reason: `Post-session gate failed for ${step.id} (exit ${exitCode}).`
        }
      ],
      actionResults: []
    };
  };
  return { calls, execute };
}

test("post-session exit 1 propagates into the flow result and is not checkpointed or retried", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const fake = gateFailingExecutor("5.1", 1);
    const checkpoint = new RecordingCheckpoint({ kind: "clean" }, { forbiddenRoots: [root] });
    const interaction = new StubInteraction(["continue", rel, true]); // confirm 5.1
    const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "5.1",
      executeStep: fake.execute,
      checkpoint
    });
    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "failed");
    if (outcome.kind === "failed") {
      assert.equal(outcome.exitCode, 1);
      assert.equal(outcome.resumeStep, "5.1");
    }
    // The before-5.1 checkpoint fired, but no advance/after-checkpoint happened.
    assert.deepEqual(checkpoint.labels, [CHECKPOINT_LABELS.before51]);
    // The failing review step ran exactly once: no automatic re-dispatch.
    assert.deepEqual(fake.calls, ["5.1"]);
  });
});

test("post-session exit 2 propagates its higher-severity classification into the flow result", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const fake = gateFailingExecutor("8.4", 2);
    const checkpoint = new RecordingCheckpoint({ kind: "clean" }, { forbiddenRoots: [root] });
    const interaction = new StubInteraction(["continue", rel, true]); // confirm 8.4
    const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "8.4",
      executeStep: fake.execute,
      checkpoint
    });
    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "failed");
    if (outcome.kind === "failed") {
      assert.equal(outcome.exitCode, 2);
      assert.equal(outcome.resumeStep, "8.4");
    }
    // Only the before-8.4 checkpoint fired; the after-8.4 checkpoint never ran.
    assert.deepEqual(checkpoint.labels, [CHECKPOINT_LABELS.before84]);
    assert.deepEqual(fake.calls, ["8.4"]);
  });
});

test("an operator-driven later 8.4 run whose gates pass follows the existing checkpoint path", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const fake = fakeExecutor(); // step 8.4 succeeds
    const checkpoint = new RecordingCheckpoint(committedResult(), { forbiddenRoots: [root] });
    const interaction = new StubInteraction(["continue", rel, true, true]); // 8.4, commit
    const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "8.4",
      executeStep: fake.execute,
      checkpoint
    });
    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "completed");
    assert.deepEqual(
      fake.calls.map((call) => call.id),
      ["8.4"]
    );
    // The passing run checkpoints before 8.4 and again at the completion boundary.
    assert.deepEqual(checkpoint.labels, [
      CHECKPOINT_LABELS.before84,
      CHECKPOINT_LABELS.featureCompletion
    ]);
  });
});

test("a required action failure stops the phase and reports its resume step", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const interaction = new StubInteraction(["continue", rel, true]);
    const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "6",
      executeStep: fakeExecutor({ failStep: "6" }).execute
    });
    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "failed");
    if (outcome.kind === "failed") assert.equal(outcome.resumeStep, "6");
  });
});

test("step 4.1 skips repo-br-scan without a ready repo but still runs task-to-br", async () => {
  await withWorkspace(
    { definition: { classes: ["backend"], classRepoPaths: {} } },
    async ({ root, projectDir, projectPathRel }) => {
      seedFeature(projectDir, "wip-1");
      const rel = path.join(projectPathRel, "wip-1");
      const agent = new StubAgentRunner(0);
      const interaction = new StubInteraction(["continue", rel, true, false]); // confirm 4.1, decline 4.2
      const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
        resumeInput: "4.1",
        executorDeps: { ...stubExecutorDeps(), agentRunner: agent }
      });
      const outcome = await runFeatureFlow(deps);
      assert.equal(outcome.kind, "stoppedByOperator");
      // repo-br-scan skipped, task-to-br launched exactly once.
      assert.equal(agent.specs.length, 1);
      assert.ok(lines.some((line) => /Skipped repo-br-scan|hasReadyClassRepo/.test(line)));
    }
  );
});

test("step 4.1 launches task-to-br on a freshly scaffolded feature with no user_br_input.md", async () => {
  await withWorkspace(
    { definition: { classes: ["backend"], classRepoPaths: {} } },
    async ({ root, projectDir, projectPathRel }) => {
      // A freshly scaffolded feature: only feature_br_summary.md, no user_br_input.md.
      seedFeature(projectDir, "wip-1");
      const rel = path.join(projectPathRel, "wip-1");
      const agent = new StubAgentRunner(0);
      const interaction = new StubInteraction(["continue", rel, true, false]); // confirm 4.1, decline 4.2
      const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
        resumeInput: "4.1",
        // Real executor wiring: the production task-to-br context builder aborts on a missing
        // user_br_input.md, so a pre-call would fail the step before the session launches.
        executorDeps: { ...defaultStepExecutorDeps, agentRunner: agent }
      });
      const outcome = await runFeatureFlow(deps);
      assert.equal(outcome.kind, "stoppedByOperator");
      // repo-br-scan skipped (no ready repo); task-to-br launched exactly once.
      assert.equal(agent.specs.length, 1);
    }
  );
});

test("step 4.1 runs repo-br-scan before task-to-br when a class repo is ready", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const agent = new StubAgentRunner(0);
    const interaction = new StubInteraction(["continue", rel, true, false]); // confirm 4.1, decline 4.2
    const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "4.1",
      executorDeps: { ...stubExecutorDeps(), agentRunner: agent }
    });
    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "stoppedByOperator");
    assert.equal(agent.specs.length, 2); // repo-br-scan + task-to-br
  });
});

test("phase 7 move-forward reports remaining pending classes", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1"); // no surface map -> backend pending
    const rel = path.join(projectPathRel, "wip-1");
    const interaction = new StubInteraction(["continue", rel, true, "forward", false, false]);
    const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "7",
      executeStep: fakeExecutor().execute
    });
    await runFeatureFlow(deps);
    assert.ok(lines.some((line) => /Proceeding with pending classes: backend/.test(line)));
  });
});

test("phase 7 analyze completes a class so it is no longer pending", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1"); // backend pending
    const rel = path.join(projectPathRel, "wip-1");
    const fake = fakeExecutor();
    const interaction = new StubInteraction([
      "continue",
      rel,
      true,
      "analyze",
      "forward",
      false,
      false
    ]);
    const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "7",
      executeStep: fake.execute
    });
    await runFeatureFlow(deps);
    assert.ok(fake.calls.some((call) => call.id === "7" && call.targetClass === "backend"));
    // With a pending class, the analyze option is offered...
    assert.ok(
      interaction.selectRequests.some(
        (opts) => opts.includes("analyze") && opts.includes("forward")
      ),
      "phase 7 with a pending class must offer the analyze option"
    );
    // ...and after analyzing backend, the pending list is empty.
    assert.ok(lines.some((line) => /Pending classes: none/.test(line)));
  });
});

test("phase 7 offers a deferred policy-A class for blueprint-backed analysis", async () => {
  await withWorkspace(
    {
      definition: {
        typeCode: "B",
        classes: ["frontend"],
        classRepoPaths: {
          frontend: { state: "deferred", policy: "A" }
        }
      }
    },
    async ({ root, projectDir, projectPathRel }) => {
      writeFileSync(
        path.join(projectDir, "project_stack_blueprint_frontend.md"),
        "# frontend blueprint\n"
      );
      seedFeature(projectDir, "wip-1");
      const rel = path.join(projectPathRel, "wip-1");
      const fake = fakeExecutor();
      const interaction = new StubInteraction([
        "continue",
        rel,
        true,
        "analyze",
        "forward",
        false,
        false
      ]);
      const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
        resumeInput: "7",
        executeStep: fake.execute
      });

      await runFeatureFlow(deps);

      assert.ok(fake.calls.some((call) => call.id === "7" && call.targetClass === "frontend"));
      assert.ok(lines.some((line) => line === "Deferred/unavailable classes: none"));
    }
  );
});

test("phase 7 does not offer a deferred policy-A class when its blueprint is missing", async () => {
  await withWorkspace(
    {
      definition: {
        typeCode: "B",
        classes: ["frontend"],
        classRepoPaths: {
          frontend: { state: "deferred", policy: "A" }
        }
      }
    },
    async ({ root, projectDir, projectPathRel }) => {
      seedFeature(projectDir, "wip-1");
      const rel = path.join(projectPathRel, "wip-1");
      const fake = fakeExecutor();
      const interaction = new StubInteraction(["continue", rel, true, "forward", false, false]);
      const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
        resumeInput: "7",
        executeStep: fake.execute
      });

      await runFeatureFlow(deps);

      assert.ok(fake.calls.every((call) => call.id !== "7"));
      assert.ok(lines.some((line) => line === "Deferred/unavailable classes: frontend"));
      assert.ok(
        interaction.selectRequests.some(
          (options) => options.includes("forward") && !options.includes("analyze")
        )
      );
    }
  );
});

test("start-new scaffolds through the executor, persists the path, and finishes", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const fake = fakeExecutor({ scaffoldComplete: { projectDir, root, name: "new-feat-1" } });
    const interaction = new StubInteraction([true]); // confirm the scaffold step
    const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
      executeStep: fake.execute
    });
    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "finished");
    assert.ok(fake.calls.some((call) => call.id === "3"));
    assert.ok(lines.some((line) => /Saved feature_path: /.test(line)));
  });
});

test("continuing a feature missing its scaffold refuses instead of skipping to 4.1", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    // A stray/partial folder with no feature_br_summary.md reports next step 3.
    mkdirSync(path.join(projectDir, "broken-1"), { recursive: true });
    const rel = path.join(projectPathRel, "broken-1");
    const fake = fakeExecutor();
    const interaction = new StubInteraction(["continue", rel]);
    const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
      executeStep: fake.execute
    });
    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "startupError");
    if (outcome.kind === "startupError") {
      assert.ok(outcome.diagnostics.some((d) => /feature_br_summary\.md/.test(d.reason)));
    }
    // No phase executed after the refusal.
    assert.equal(fake.calls.length, 0);
  });
});

test("refuses when project-level reconciliation is pending, before any feature work", async () => {
  await withWorkspace(
    { definition: { classRepoPaths: { backend: { state: "ready" } } } },
    async ({ root, projectDir, projectPathRel }) => {
      const fake = fakeExecutor();
      const interaction = new StubInteraction([]);
      const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
        executeStep: fake.execute
      });
      const outcome = await runFeatureFlow(deps);
      assert.equal(outcome.kind, "refusedPendingWork");
      if (outcome.kind === "refusedPendingWork") {
        assert.ok(
          outcome.guidance.some((line) =>
            line.includes(`overmind project reconcile --path ${projectPathRel}`)
          )
        );
      }
      // Refused at the step 3 boundary: no feature ID/title prompt was consumed
      // and no catalog step (including the scaffold write) was dispatched.
      assert.equal(interaction.log.length, 0);
      assert.equal(fake.calls.length, 0);
    }
  );
});

test("refuses when project initialization is pending, before any feature work", async () => {
  await withWorkspace(
    {
      initComplete: false,
      definition: {
        typeCode: "B",
        classRepoPaths: { backend: { state: "ready", reconciled: true } }
      }
    },
    async ({ root, projectDir, projectPathRel }) => {
      const fake = fakeExecutor();
      const interaction = new StubInteraction([]);
      const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
        executeStep: fake.execute
      });
      const outcome = await runFeatureFlow(deps);
      assert.equal(outcome.kind, "refusedPendingWork");
      if (outcome.kind === "refusedPendingWork") {
        assert.ok(
          outcome.guidance.some((line) =>
            line.includes(`overmind project init --path ${projectPathRel}`)
          )
        );
      }
      assert.equal(interaction.log.length, 0);
      assert.equal(fake.calls.length, 0);
    }
  );
});

/**
 * ProjectGitPort double whose `inspectPaths` reports a pending git-working-tree
 * state, driving the step-3 checkpoint gate inside the real `scaffoldFeature`
 * primitive (not a faked executor).
 */
function pendingCheckpointGit(
  entryFor: (path: string) => {
    hasHeadVersion: boolean;
    staged: boolean;
    unstaged: boolean;
    untracked: boolean;
  }
): ProjectGitPort {
  return {
    worktreeStatus: () => ({ kind: "clean" }),
    changedPaths: () => ({ kind: "ok", paths: [] }),
    inspectPaths: (_root, paths) => ({
      kind: "ok",
      paths: paths.map((path) => ({ path, ...entryFor(path) }))
    }),
    commitOwnedPaths: () => ({ kind: "committed" })
  };
}

// Setup where pre-flight detection passes (backend ready+reconciled, init
// complete) so the flow reaches step 3, and the real scaffold primitive runs.
const reachesStep3 = {
  definition: { classRepoPaths: { backend: { state: "ready" as const, reconciled: true } } }
};

test("run step 3 boundary refuses a type-A interrupted init-only checkpoint via the real primitive", async () => {
  await withWorkspace(
    {
      definition: {
        typeCode: "A",
        classes: ["backend"],
        classRepoPaths: { backend: { state: "ready", reconciled: true } }
      }
    },
    async ({ root, projectDir, projectPathRel }) => {
      // Type-A step 1.1 stack + agent-guidelines artifacts exist, so pre-flight
      // init detection reads step 1.1 as done and the flow reaches the step-3
      // gate ("artifact progress has moved past step 1.1").
      writeFileSync(path.join(projectDir, "project_stack_blueprint_backend.md"), "# blueprint\n");
      writeFileSync(path.join(projectDir, "project_agents_md_claude_md_backend.md"), "# agents\n");
      const before = readdirSync(projectDir);
      // The shared project-definition files are clean and committed, but one
      // applicable step 1.1 stack artifact has no finalized checkpoint -> the
      // gate must still refuse (the interrupted init-only checkpoint the
      // committed-common-contract proxy alone would miss).
      const uncommittedStackPath = "project_stack_blueprint_backend.md";
      const projectGit = pendingCheckpointGit((candidate) => ({
        hasHeadVersion: candidate !== uncommittedStackPath,
        staged: false,
        unstaged: false,
        untracked: candidate === uncommittedStackPath
      }));
      const interaction = new StubInteraction([true]); // confirm step 3 only
      const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
        // Real executeStep (no override) with production executor wiring.
        executorDeps: {
          ...defaultStepExecutorDeps,
          agentRunner: new StubAgentRunner(0),
          projectGit
        }
      });
      const outcome = await runFeatureFlow(deps);
      assert.equal(outcome.kind, "failed");
      if (outcome.kind === "failed") {
        assert.equal(outcome.resumeStep, "3");
        assert.ok(
          outcome.diagnostics.some((diagnostic) =>
            diagnostic.reason.includes(`overmind project init --path ${projectPathRel}`)
          )
        );
      }
      // Refused before the feature ID/title prompt and before any write.
      assert.ok(interaction.log.every((line) => !line.startsWith("input:")));
      assert.deepEqual(readdirSync(projectDir).sort(), before.sort());
    }
  );
});

test("run step 3 boundary refuses a declined reconciliation commit via the real primitive", async () => {
  await withWorkspace(reachesStep3, async ({ root, projectDir, projectPathRel }) => {
    const before = readdirSync(projectDir);
    // A committed common contract plus a dirty shared path -> pending reconciliation.
    const projectGit = pendingCheckpointGit((path) => ({
      hasHeadVersion: true,
      staged: false,
      unstaged: path === "init_progress_definition.yaml",
      untracked: false
    }));
    const interaction = new StubInteraction([true]); // confirm step 3 only
    const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
      executorDeps: { ...defaultStepExecutorDeps, agentRunner: new StubAgentRunner(0), projectGit }
    });
    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "failed");
    if (outcome.kind === "failed") {
      assert.equal(outcome.resumeStep, "3");
      assert.ok(
        outcome.diagnostics.some((diagnostic) =>
          diagnostic.reason.includes(`overmind project reconcile --path ${projectPathRel}`)
        )
      );
    }
    assert.ok(interaction.log.every((line) => !line.startsWith("input:")));
    assert.deepEqual(readdirSync(projectDir).sort(), before.sort());
  });
});

// --- CRP-166: terminal gate chain at the plan-completion boundary ------------

/** Chain that fails with a scripted aggregate, recording when it was invoked. */
function failingTerminalChain(
  exitCode: 1 | 2,
  repairStep: string,
  reason = "terminal gate failed"
): RecordingTerminalChain {
  return new RecordingTerminalChain({
    exitCode,
    repairStep,
    failed: 1,
    diagnostics: [{ severity: "error", source: "terminal-gate-chain", reason, stepId: repairStep }]
  });
}

test("terminal chain runs after an accepted 8.4 and before the completion commit boundary", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const chain = new RecordingTerminalChain({ exitCode: 0 });
    const checkpoint = new RecordingCheckpoint(committedResult());
    const interaction = new StubInteraction(["continue", rel, true, true]);
    const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "8.4",
      executeStep: fakeExecutor().execute,
      terminalGateChain: chain.run,
      checkpoint
    });

    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "completed");
    assert.equal(chain.calls.length, 1);
    assert.equal(chain.calls[0]!.featurePath, path.join(root, rel));
    assert.equal(chain.calls[0]!.cwd, root);
    assert.deepEqual(checkpoint.labels, [
      CHECKPOINT_LABELS.before84,
      CHECKPOINT_LABELS.featureCompletion
    ]);
  });
});

test("a failing terminal chain blocks the completion commit boundary and plan completion", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const chain = failingTerminalChain(1, "5", "requirements_ears.md: invalid EARS bullet");
    const checkpoint = new RecordingCheckpoint();
    const interaction = new StubInteraction(["continue", rel, true]);
    const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "8.4",
      executeStep: fakeExecutor().execute,
      terminalGateChain: chain.run,
      checkpoint
    });

    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "failed");
    if (outcome.kind === "failed") {
      assert.equal(outcome.exitCode, 1);
      // The earliest owning step is what the operator resumes from.
      assert.equal(outcome.resumeStep, "5");
      assert.match(outcome.diagnostics[0]!.reason, /invalid EARS bullet/);
    }
    // No completion commit boundary and no plan-complete output.
    assert.deepEqual(checkpoint.labels, [CHECKPOINT_LABELS.before84]);
    assert.ok(lines.every((line) => !/reached end of configured phase map/.test(line)));
  });
});

test("a declined 8.4 does not announce a finished feature when the chain then fails", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const chain = failingTerminalChain(1, "5");
    const interaction = new StubInteraction(["continue", rel, false]);
    const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "8.4",
      executeStep: fakeExecutor().execute,
      terminalGateChain: chain.run
    });

    const outcome = await runFeatureFlow(deps);

    // The optional-decline notice announces a finished feature, so it must stay
    // behind the terminal gate rather than preceding a failure.
    assert.equal(outcome.kind, "failed");
    assert.ok(lines.every((line) => !/Execution finished/.test(line)));
  });
});

test("a declined 8.4 announces the finished feature once the chain passes", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const chain = new RecordingTerminalChain({ exitCode: 0 });
    const interaction = new StubInteraction(["continue", rel, false]);
    const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "8.4",
      executeStep: fakeExecutor().execute,
      terminalGateChain: chain.run
    });

    const outcome = await runFeatureFlow(deps);

    assert.equal(outcome.kind, "finished");
    assert.ok(
      lines.some((line) =>
        /no remaining required phases after declined optional phase 8.4/.test(line)
      )
    );
  });
});

test("a terminal runtime failure carries exit two through the flow unchanged", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const chain = failingTerminalChain(2, "8.3", "implementation-plan gate cannot run");
    const interaction = new StubInteraction(["continue", rel, true]);
    const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "8.4",
      executeStep: fakeExecutor().execute,
      terminalGateChain: chain.run
    });

    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "failed");
    if (outcome.kind === "failed") {
      assert.equal(outcome.exitCode, 2);
      assert.equal(outcome.resumeStep, "8.3");
    }
  });
});

test("terminal chain runs once when 8.4 is declined, before the finished outcome", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const chain = new RecordingTerminalChain({ exitCode: 0 });
    const interaction = new StubInteraction(["continue", rel, false]);
    const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "8.4",
      executeStep: fakeExecutor().execute,
      terminalGateChain: chain.run
    });

    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "finished");
    assert.equal(chain.calls.length, 1);
  });
});

test("terminal chain runs once at the catalog end, before plan-complete output", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const chain = failingTerminalChain(1, "8.3", "implementation_plan.md: header missing");
    // Accept 8.3, then accept 8.4 so the loop runs to the end of the phase map.
    const interaction = new StubInteraction(["continue", rel, true, true]);
    const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "8.3",
      executeStep: fakeExecutor().execute,
      terminalGateChain: chain.run
    });

    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "failed");
    // The 8.4 boundary already enforced it; the catalog end must not run it again.
    assert.equal(chain.calls.length, 1);
    assert.ok(lines.every((line) => !/reached end of configured phase map/.test(line)));
  });
});

test("terminal chain is not invoked when an earlier action fails or the operator stops", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1", ["project_surface_struct_resp_map_backend.md"]);
    const rel = path.join(projectPathRel, "wip-1");

    const failChain = new RecordingTerminalChain({ exitCode: 0 });
    const failing = new StubInteraction(["continue", rel, true]);
    const { deps: failDeps } = baseDeps(root, projectDir, projectPathRel, failing, {
      resumeInput: "6",
      executeStep: fakeExecutor({ failStep: "6" }).execute,
      terminalGateChain: failChain.run
    });
    assert.equal((await runFeatureFlow(failDeps)).kind, "failed");
    assert.equal(failChain.calls.length, 0);

    const stopChain = new RecordingTerminalChain({ exitCode: 0 });
    const stopping = new StubInteraction(["continue", rel, false]);
    const { deps: stopDeps } = baseDeps(root, projectDir, projectPathRel, stopping, {
      resumeInput: "6",
      executeStep: fakeExecutor().execute,
      terminalGateChain: stopChain.run
    });
    assert.equal((await runFeatureFlow(stopDeps)).kind, "stoppedByOperator");
    assert.equal(stopChain.calls.length, 0);
  });
});

test("an explicit repair resume reopens the valid cached completed feature", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const featureDir = seedCompleteFeature(projectDir, "done-1");
    writeFeatureState(projectDir, path.relative(root, featureDir));

    // Step 5 owns the earliest terminal failure; resuming there reopens the
    // cached feature even though artifact scanning calls it complete.
    const chain = new RecordingTerminalChain({ exitCode: 0 });
    const fake = fakeExecutor();
    const interaction = new StubInteraction([
      true, // 5
      true, // 5.1
      true, // 6
      true, // 7 confirm
      "forward", // 7 class loop
      true, // 7.1
      true, // 8
      true, // 8.1
      true, // 8.2
      true, // 8.3
      true // 8.4
    ]);
    const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "5",
      executeStep: fake.execute,
      terminalGateChain: chain.run
    });

    const outcome = await runFeatureFlow(deps);
    assert.ok(
      lines.some((line) =>
        /Reopening completed cached feature at explicit repair step 5: /.test(line)
      )
    );
    assert.equal(fake.calls[0]!.id, "5");
    // Completion is only reported after the terminal chain passes.
    assert.equal(chain.calls.length, 1);
    assert.equal(outcome.kind, "completed");
  });
});

test("a repair resume with no cached feature reports actionable guidance", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedCompleteFeature(projectDir, "done-1");
    const interaction = new StubInteraction([]);
    const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "8.3",
      executeStep: fakeExecutor().execute
    });
    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "startupError");
    if (outcome.kind === "startupError") {
      assert.match(outcome.diagnostics[0]!.reason, /cached feature_path/);
      assert.doesNotMatch(outcome.diagnostics[0]!.reason, /use --resume 3 first/);
    }
  });
});

// --- CRP-169: the feature-completion commit boundary -------------------------

const COMMIT_PROMPT = "Commit completed feature work?";

/** Commit-boundary prompts only, so step confirmations do not inflate the count. */
function commitPrompts(interaction: StubInteraction): ConfirmRequest[] {
  return interaction.confirmRequests.filter((request) => request.message === COMMIT_PROMPT);
}

test("an accepted 8.4 and its catalog-end fall-through reach the commit boundary once", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const chain = new RecordingTerminalChain({ exitCode: 0 });
    const checkpoint = new RecordingCheckpoint(committedResult());
    // Accepting 8.4 completes the last catalog step, so the loop then falls
    // through to its end: one completion, one prompt, one commit.
    const interaction = new StubInteraction(["continue", rel, true, true]);
    const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "8.4",
      executeStep: fakeExecutor().execute,
      terminalGateChain: chain.run,
      checkpoint
    });

    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "completed");
    assert.equal(chain.calls.length, 1);
    assert.equal(commitPrompts(interaction).length, 1);
    assert.equal(commitPrompts(interaction)[0]!.defaultValue, true);
    assert.deepEqual(
      checkpoint.labels.filter((label) => label === CHECKPOINT_LABELS.featureCompletion),
      [CHECKPOINT_LABELS.featureCompletion]
    );
    assert.ok(
      lines.some((line) =>
        line.includes(
          `Checkpoint commit created: Checkpoint: ${CHECKPOINT_LABELS.featureCompletion}`
        )
      )
    );
  });
});

test("a declined 8.4 reaches the commit boundary before the finished outcome", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const checkpoint = new RecordingCheckpoint(committedResult());
    const interaction = new StubInteraction(["continue", rel, false, true]);
    const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "8.4",
      executeStep: fakeExecutor().execute,
      checkpoint
    });

    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "finished");
    assert.equal(commitPrompts(interaction).length, 1);
    assert.deepEqual(checkpoint.labels, [
      CHECKPOINT_LABELS.before84,
      CHECKPOINT_LABELS.featureCompletion
    ]);
    assert.ok(
      lines.some((line) =>
        /no remaining required phases after declined optional phase 8.4/.test(line)
      )
    );
  });
});

test("a run whose scanner reports nothing remaining reaches the commit boundary", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    // Scaffolding produces a complete feature, so the pre-loop scan finds no
    // remaining required step — the ordinary resumed-run shape (CRP-169 path 1).
    const fake = fakeExecutor({ scaffoldComplete: { projectDir, root, name: "new-feat-1" } });
    const checkpoint = new RecordingCheckpoint(committedResult());
    const interaction = new StubInteraction([true, true]); // scaffold, commit
    const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
      executeStep: fake.execute,
      checkpoint
    });

    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "finished");
    assert.equal(commitPrompts(interaction).length, 1);
    assert.deepEqual(checkpoint.labels, [CHECKPOINT_LABELS.featureCompletion]);
    assert.ok(
      lines.some((line) => /scanner reports no remaining required steps/.test(line)),
      "the finished message still reaches the operator"
    );
  });
});

test("declining the commit prompt leaves the work uncommitted and keeps the outcome", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const checkpoint = new RecordingCheckpoint(committedResult());
    const interaction = new StubInteraction(["continue", rel, true, false]);
    const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "8.4",
      executeStep: fakeExecutor().execute,
      checkpoint
    });

    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "completed");
    assert.deepEqual(checkpoint.labels, [CHECKPOINT_LABELS.before84]);
    assert.ok(
      lines.some((line) =>
        line.includes(
          `Checkpoint commit declined by operator (${CHECKPOINT_LABELS.featureCompletion}): completed feature work left uncommitted.`
        )
      )
    );
  });
});

test("a closed input stream at the commit boundary declines without stopping the run", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const checkpoint = new RecordingCheckpoint(committedResult());
    // Nothing scripted for the commit prompt: the stream closes while it is open.
    const interaction = new StubInteraction(["continue", rel, true]);
    const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "8.4",
      executeStep: fakeExecutor().execute,
      checkpoint
    });

    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "completed");
    assert.deepEqual(checkpoint.labels, [CHECKPOINT_LABELS.before84]);
    assert.ok(
      lines.some((line) =>
        line.includes(
          `Checkpoint commit declined (input closed) (${CHECKPOINT_LABELS.featureCompletion}): completed feature work left uncommitted.`
        )
      )
    );
    assert.ok(lines.every((line) => !/Execution stopped/.test(line)));
  });
});

test("a clean project worktree reports nothing to commit without prompting", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const checkpoint = new RecordingCheckpoint({ kind: "clean" });
    const interaction = new StubInteraction(["continue", rel, true]);
    const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "8.4",
      executeStep: fakeExecutor().execute,
      checkpoint
    });

    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "completed");
    assert.equal(commitPrompts(interaction).length, 0);
    assert.deepEqual(checkpoint.labels, [CHECKPOINT_LABELS.before84]);
    assert.ok(
      lines.some((line) =>
        line.includes(
          `Checkpoint commit skipped (${CHECKPOINT_LABELS.featureCompletion}): nothing to commit.`
        )
      )
    );
  });
});

test("every commit obstacle is a notice that preserves the flow outcome", async () => {
  const obstacles: Array<{ result: CheckpointResult; expected: RegExp }> = [
    { result: { kind: "unavailable" }, expected: /git not found in PATH/ },
    { result: { kind: "notWorktree" }, expected: /is not a git worktree/ },
    { result: { kind: "addFailed", exitCode: 3 }, expected: /git add exited 3/ },
    { result: { kind: "commitFailed", exitCode: 4 }, expected: /git commit exited 4/ }
  ];

  for (const obstacle of obstacles) {
    await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
      seedFeature(projectDir, "wip-1");
      const rel = path.join(projectPathRel, "wip-1");
      const checkpoint = new RecordingCheckpoint(obstacle.result);
      const interaction = new StubInteraction(["continue", rel, true, true]);
      const { deps, lines } = baseDeps(root, projectDir, projectPathRel, interaction, {
        resumeInput: "8.4",
        executeStep: fakeExecutor().execute,
        checkpoint
      });

      const outcome = await runFeatureFlow(deps);
      assert.equal(outcome.kind, "completed", `${obstacle.result.kind} changed the outcome`);
      assert.deepEqual(checkpoint.labels, [
        CHECKPOINT_LABELS.before84,
        CHECKPOINT_LABELS.featureCompletion
      ]);
      assert.ok(
        lines.some(
          (line) =>
            obstacle.expected.test(line) && line.includes(CHECKPOINT_LABELS.featureCompletion)
        ),
        `${obstacle.result.kind} produced no completion notice`
      );
    });
  }
});

test("a failing terminal chain reaches no commit prompt and no commit", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const checkpoint = new RecordingCheckpoint(committedResult());
    const interaction = new StubInteraction(["continue", rel, true, true]);
    const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "8.4",
      executeStep: fakeExecutor().execute,
      terminalGateChain: failingTerminalChain(1, "8.3").run,
      checkpoint
    });

    const outcome = await runFeatureFlow(deps);
    assert.equal(outcome.kind, "failed");
    if (outcome.kind === "failed") assert.equal(outcome.resumeStep, "8.3");
    assert.equal(commitPrompts(interaction).length, 0);
    assert.deepEqual(checkpoint.labels, [CHECKPOINT_LABELS.before84]);
  });
});

test("runs that never complete feature work reach no commit boundary", async () => {
  const assertNoBoundary = (
    interaction: StubInteraction,
    checkpoint: RecordingCheckpoint,
    label: string
  ): void => {
    assert.equal(commitPrompts(interaction).length, 0, `${label} prompted for a commit`);
    assert.equal(
      checkpoint.labels.includes(CHECKPOINT_LABELS.featureCompletion),
      false,
      `${label} reached the commit boundary`
    );
  };

  // A phase failure.
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const checkpoint = new RecordingCheckpoint(committedResult());
    const interaction = new StubInteraction(["continue", rel, true]);
    const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "6",
      executeStep: fakeExecutor({ failStep: "6" }).execute,
      checkpoint
    });
    assert.equal((await runFeatureFlow(deps)).kind, "failed");
    assertNoBoundary(interaction, checkpoint, "phase failure");
  });

  // An operator stop at a required phase.
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const checkpoint = new RecordingCheckpoint(committedResult());
    const interaction = new StubInteraction(["continue", rel, false]);
    const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "6",
      executeStep: fakeExecutor().execute,
      checkpoint
    });
    assert.equal((await runFeatureFlow(deps)).kind, "stoppedByOperator");
    assertNoBoundary(interaction, checkpoint, "operator stop");
  });

  // Refused pending project work.
  await withWorkspace(
    { definition: { classRepoPaths: { backend: { state: "ready" } } } },
    async ({ root, projectDir, projectPathRel }) => {
      const checkpoint = new RecordingCheckpoint(committedResult());
      const interaction = new StubInteraction([]);
      const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
        executeStep: fakeExecutor().execute,
        checkpoint
      });
      assert.equal((await runFeatureFlow(deps)).kind, "refusedPendingWork");
      assertNoBoundary(interaction, checkpoint, "refused pending work");
    }
  );

  // A startup error from an unresolvable resume token.
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const checkpoint = new RecordingCheckpoint(committedResult());
    const interaction = new StubInteraction([]);
    const { deps } = baseDeps(root, projectDir, projectPathRel, interaction, {
      resumeInput: "99",
      executeStep: fakeExecutor().execute,
      checkpoint
    });
    assert.equal((await runFeatureFlow(deps)).kind, "startupError");
    assertNoBoundary(interaction, checkpoint, "startup error");
  });
});
