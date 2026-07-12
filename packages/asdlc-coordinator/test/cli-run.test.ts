import { cpSync, mkdirSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { runCli, type CliAdapterOverrides } from "../src/cli/run.js";
import { StubAgentRunner } from "../src/runner/agent-runner.js";
import { writeFeatureState } from "../src/state/index.js";
import {
  RecordingCheckpoint,
  StubInteraction,
  seedCompleteFeature,
  validModelsMd,
  withWorkspace
} from "./orchestrator-fixtures.js";

interface Captured {
  stdout: string;
  stderr: string;
}

function capture(): {
  streams: { stdout: { write: (s: string) => boolean }; stderr: { write: (s: string) => boolean } };
  out: Captured;
} {
  const out: Captured = { stdout: "", stderr: "" };
  return {
    streams: {
      stdout: { write: (s: string) => ((out.stdout += s), true) },
      stderr: { write: (s: string) => ((out.stderr += s), true) }
    },
    out
  };
}

async function run(
  argv: string[],
  cwd: string,
  overrides: CliAdapterOverrides = {}
): Promise<{ code: number; out: Captured }> {
  const { streams, out } = capture();
  const code = await runCli(["node", "overmind", ...argv], streams, cwd, overrides);
  return { code, out };
}

test("run --help prints usage and exits zero", async () => {
  await withWorkspace({}, async ({ root }) => {
    const { code, out } = await run(["run", "--help"], root);
    assert.equal(code, 0);
    assert.match(out.stdout, /overmind run \[--path <project>\] \[--resume <step>\]/);
  });
});

test("unknown option and missing value are rejected", async () => {
  await withWorkspace({}, async ({ root }) => {
    assert.equal((await run(["run", "--bogus"], root)).code, 2);
    assert.equal((await run(["run", "--path"], root)).code, 2);
  });
});

test("an invalid project path exits non-zero without starting feature work", async () => {
  await withWorkspace({}, async ({ root }) => {
    const agent = new StubAgentRunner(0);
    const { code } = await run(["run", "--path", "projects"], root, { agentRunner: agent });
    assert.equal(code, 2);
    assert.equal(agent.specs.length, 0);
  });
});

test("project reconciliation-pending refuses before any feature side effects", async () => {
  await withWorkspace(
    { definition: { classRepoPaths: { backend: { state: "ready" } } } },
    async ({ root, projectPathRel }) => {
      const agent = new StubAgentRunner(0);
      const checkpoint = new RecordingCheckpoint();
      const { code, out } = await run(["run", "--path", projectPathRel], root, {
        interaction: new StubInteraction([]),
        agentRunner: agent,
        checkpoint
      });
      assert.equal(code, 1);
      assert.match(out.stderr, /overmind project reconcile --path/);
      assert.equal(agent.specs.length, 0);
      assert.equal(checkpoint.labels.length, 0);
    }
  );
});

test("malformed runner config refuses at startup with no feature side effects", async () => {
  await withWorkspace({}, async ({ root, projectPathRel }) => {
    rmSync(path.join(root, ".setup", "models.md"));
    const agent = new StubAgentRunner(0);
    const checkpoint = new RecordingCheckpoint();
    const { code, out } = await run(["run", "--path", projectPathRel], root, {
      interaction: new StubInteraction([]),
      agentRunner: agent,
      checkpoint
    });
    assert.equal(code, 1);
    assert.match(out.stderr, /models\.md/);
    assert.equal(agent.specs.length, 0);
    assert.equal(checkpoint.labels.length, 0);
  });
});

test("an unregistered runner command refuses at startup with no feature side effects", async () => {
  await withWorkspace({}, async ({ root, projectPathRel }) => {
    // A required phase row uses an unregistered command (claude, not codex).
    writeFileSync(
      path.join(root, ".setup", "models.md"),
      validModelsMd().replace("task_to_br | codex | gpt-5.4", "task_to_br | claude | sonnet")
    );
    const agent = new StubAgentRunner(0);
    const checkpoint = new RecordingCheckpoint();
    const { code, out } = await run(["run", "--path", projectPathRel], root, {
      interaction: new StubInteraction([]),
      agentRunner: agent,
      checkpoint
    });
    assert.equal(code, 1);
    assert.match(out.stderr, /models\.md/);
    assert.match(out.stderr, /Unsupported command 'claude'/);
    assert.equal(agent.specs.length, 0);
    assert.equal(checkpoint.labels.length, 0);
  });
});

test("an unsupported --resume alias exits non-zero", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedCompleteFeature(projectDir, "done-1");
    const { code } = await run(["run", "--path", projectPathRel, "--resume", "not-a-step"], root, {
      interaction: new StubInteraction([]),
      agentRunner: new StubAgentRunner(0)
    });
    assert.equal(code, 1);
  });
});

test("resume 8.4 on a completed cached feature completes and exits zero", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const featureDir = seedCompleteFeature(projectDir, "done-1");
    writeFeatureState(projectDir, path.relative(root, featureDir));
    const { code } = await run(["run", "--path", projectPathRel, "--resume", "8.4"], root, {
      interaction: new StubInteraction([true]),
      agentRunner: new StubAgentRunner(0),
      checkpoint: new RecordingCheckpoint(),
      clock: { now: () => 1 }
    });
    assert.equal(code, 0);
  });
});

test("with no --path a single project is auto-selected", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const featureDir = seedCompleteFeature(projectDir, "done-1");
    writeFeatureState(projectDir, path.relative(root, featureDir));
    const { code, out } = await run(["run", "--resume", "8.4"], root, {
      interaction: new StubInteraction([true]),
      agentRunner: new StubAgentRunner(0),
      checkpoint: new RecordingCheckpoint(),
      clock: { now: () => 1 }
    });
    assert.equal(code, 0);
    assert.match(out.stdout, new RegExp(`Selected project: ${projectPathRel}`));
  });
});

test("with no --path and multiple projects the operator can finish without selecting", async () => {
  await withWorkspace({}, async ({ root, projectDir }) => {
    const second = path.join(root, "projects", "q");
    mkdirSync(second, { recursive: true });
    cpSync(
      path.join(projectDir, "init_progress_definition.yaml"),
      path.join(second, "init_progress_definition.yaml")
    );
    const agent = new StubAgentRunner(0);
    const { code, out } = await run(["run"], root, {
      interaction: new StubInteraction(["__finish__"]),
      agentRunner: agent
    });
    assert.equal(code, 0);
    assert.match(out.stdout, /Finished without selecting/);
    assert.equal(agent.specs.length, 0);
  });
});

test("with multiple projects the operator can select one and it becomes the target", async () => {
  await withWorkspace({}, async ({ root, projectDir }) => {
    // Second, init-complete project q with a completed cached feature only in q.
    const second = path.join(root, "projects", "q");
    mkdirSync(second, { recursive: true });
    cpSync(
      path.join(projectDir, "init_progress_definition.yaml"),
      path.join(second, "init_progress_definition.yaml")
    );
    writeFileSync(path.join(second, "common_contract_definition.md"), "complete\n");
    const featureDir = seedCompleteFeature(second, "done-1");
    writeFeatureState(second, path.relative(root, featureDir));

    // Select q (not finish), then confirm 8.4. Exit 0 only if q was targeted:
    // p has no cached feature, so targeting p would fail the resume with exit 1.
    const { code } = await run(["run", "--resume", "8.4"], root, {
      interaction: new StubInteraction([second, true]),
      agentRunner: new StubAgentRunner(0),
      checkpoint: new RecordingCheckpoint(),
      clock: { now: () => 1 }
    });
    assert.equal(code, 0);
  });
});

test("removed scaffold verb is rejected as an unknown command", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const before = readdirSync(projectDir).length;
    const { code, out } = await run(["scaffold", "feature", "--path", projectPathRel], root, {});
    assert.notEqual(code, 0);
    assert.match(out.stderr, /Usage: overmind/);
    assert.doesNotMatch(out.stderr, /scaffold/);
    assert.equal(readdirSync(projectDir).length, before);
  });
});

test("resume validates only the phases the plan reaches, not the whole catalog", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const featureDir = seedCompleteFeature(projectDir, "done-1");
    writeFeatureState(projectDir, path.relative(root, featureDir));
    // Only the semantic-review row exists; task_to_br and the rest are absent.
    writeFileSync(
      path.join(root, ".setup", "models.md"),
      "implementation_plan_semantic_review | codex | gpt-5.4\n"
    );
    const { code } = await run(["run", "--path", projectPathRel, "--resume", "8.4"], root, {
      interaction: new StubInteraction([true]),
      agentRunner: new StubAgentRunner(0),
      checkpoint: new RecordingCheckpoint(),
      clock: { now: () => 1 }
    });
    assert.equal(code, 0);
  });
});

test("a failed step exits one and prints the exact restart command", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const featureDir = seedCompleteFeature(projectDir, "done-1");
    writeFeatureState(projectDir, path.relative(root, featureDir));
    const { code, out } = await run(["run", "--path", projectPathRel, "--resume", "8.4"], root, {
      interaction: new StubInteraction([true]),
      agentRunner: new StubAgentRunner(1),
      checkpoint: new RecordingCheckpoint()
    });
    assert.equal(code, 1);
    assert.match(out.stderr, new RegExp(`overmind run --path ${projectPathRel} --resume 8\\.4`));
  });
});
