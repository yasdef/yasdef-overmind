import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { runFeatureFlow, type FeatureFlowDeps } from "../src/orchestrator/index.js";
import type { StepBindings, StepResult } from "../src/runner/index.js";
import { StubAgentRunner } from "../src/runner/agent-runner.js";
import type { StepDefinition } from "../src/sequencing/step-catalog.js";
import { CHECKPOINT_LABELS } from "../src/git/index.js";
import {
  RecordingCheckpoint,
  StubInteraction,
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
    const checkpoint = new RecordingCheckpoint({ kind: "clean" }, { forbiddenRoots: [root] });
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
      true // 8.4
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
      CHECKPOINT_LABELS.after84
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
      true // 8.4
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

test("declining the final optional phase finishes cleanly and checkpoints after 8.4", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedFeature(projectDir, "wip-1");
    const rel = path.join(projectPathRel, "wip-1");
    const checkpoint = new RecordingCheckpoint({ kind: "clean" }, { forbiddenRoots: [root] });
    const interaction = new StubInteraction(["continue", rel, false]);
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
    assert.deepEqual(checkpoint.labels, [CHECKPOINT_LABELS.before84, CHECKPOINT_LABELS.after84]);
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
      assert.equal(fake.calls.length, 0);
    }
  );
});
