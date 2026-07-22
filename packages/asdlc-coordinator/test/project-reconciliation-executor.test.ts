import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { loadRunnerConfig, resolveRunnerPhase } from "../src/config/index.js";
import { buildContractReconciliationContext } from "../src/context/index.js";
import {
  buildSessionPrompt,
  defaultStepExecutorDeps,
  executeStep,
  type AgentRunner,
  type StepExecutorDeps
} from "../src/runner/index.js";
import { PROJECT_RECONCILIATION_STEP } from "../src/sequencing/index.js";

interface Fixture {
  root: string;
  projectDir: string;
  projectPathRel: string;
}

function initGitRepo(dir: string): string {
  mkdirSync(dir, { recursive: true });
  execFileSync("git", ["init", "-q"], { cwd: dir });
  return dir;
}

function makeFixture(options: { sharedRepo?: boolean; withPhase?: boolean } = {}): Fixture {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-reconcile-exec-"));
  writeFileSync(path.join(root, "asdlc_metadata.yaml"), "project: overmind\n");
  mkdirSync(path.join(root, ".setup"), { recursive: true });
  writeFileSync(
    path.join(root, ".setup", "models.md"),
    options.withPhase === false
      ? "task_to_br | codex | gpt-5.4\n"
      : "project_contract_reconciliation | codex | gpt-5.4 | --config | model_reasoning_effort='high'\n"
  );
  const projectDir = path.join(root, "projects", "p1");
  mkdirSync(projectDir, { recursive: true });
  const apiRepo = initGitRepo(path.join(root, "repos", "api"));
  const webRepo = options.sharedRepo ? apiRepo : initGitRepo(path.join(root, "repos", "web"));
  writeFileSync(
    path.join(projectDir, "init_progress_definition.yaml"),
    `meta_info:
  project_type_code: A
  project_classes: [backend, frontend]
  class_repo_paths:
    backend:
      state: "ready"
      path: "${apiRepo}"
      policy: "C"
    frontend:
      state: "ready"
      path: "${webRepo}"
      policy: "C"
steps:
  - id: "1"
`
  );
  writeFileSync(path.join(projectDir, "common_contract_definition.md"), "# Common contract\n");
  return { root, projectDir, projectPathRel: path.relative(root, projectDir) };
}

function deps(agentRunner: AgentRunner): StepExecutorDeps {
  return {
    agentRunner,
    loadRunnerConfig,
    resolveRunnerPhase,
    buildSessionPrompt,
    context: {},
    classListContext: {
      "contract-reconciliation": (projectPath, classes, cwd) =>
        buildContractReconciliationContext(projectPath, classes, cwd)
    },
    sync: {},
    readiness: {},
    projectGit: defaultStepExecutorDeps.projectGit,
    write: {}
  };
}

function bindings(fx: Fixture, classes: string[]) {
  return {
    step: PROJECT_RECONCILIATION_STEP,
    runtimeRoot: fx.root,
    featurePath: fx.projectPathRel,
    overmindCliPath: ".overmind/overmind.js",
    classes
  };
}

test("one class-list session launches exactly one agent carrying every class binding", async () => {
  const fx = makeFixture();
  try {
    let calls = 0;
    let prompt = "";
    const result = await executeStep(
      PROJECT_RECONCILIATION_STEP,
      bindings(fx, ["backend", "frontend"]),
      deps({
        run: async (spec) => {
          calls += 1;
          prompt = spec.prompt;
          return { exitCode: 0 };
        }
      })
    );
    assert.equal(result.ok, true, result.diagnostics.map((d) => d.reason).join("; "));
    assert.equal(calls, 1);
    assert.match(prompt, /--class backend --class frontend/);
    assert.match(prompt, /overmind-contract-reconciliation/);
  } finally {
    rmSync(fx.root, { recursive: true, force: true });
  }
});

test("shared repo is deduplicated in inspection while both class mappings persist", async () => {
  const fx = makeFixture({ sharedRepo: true });
  try {
    const result = buildContractReconciliationContext(fx.projectDir, ["backend", "frontend"]);
    assert.equal(result.exitCode, 0, result.errorMessage);
    const inspection = result.text!.split("Unique Repository Inspection Paths")[1]!.split("##")[0]!;
    assert.equal((inspection.match(/repos\/api/g) ?? []).length, 1);
    const mappings = result.text!.split("In-Scope Classes")[1]!.split("## Unique")[0]!;
    assert.equal((mappings.match(/repos\/api/g) ?? []).length, 2);
  } finally {
    rmSync(fx.root, { recursive: true, force: true });
  }
});

test("invalid runner config fails before agent launch", async () => {
  const fx = makeFixture({ withPhase: false });
  try {
    let calls = 0;
    const result = await executeStep(
      PROJECT_RECONCILIATION_STEP,
      bindings(fx, ["backend"]),
      deps({
        run: async () => {
          calls += 1;
          return { exitCode: 0 };
        }
      })
    );
    assert.equal(result.ok, false);
    assert.equal(calls, 0);
  } finally {
    rmSync(fx.root, { recursive: true, force: true });
  }
});

test("class binding failure fails before agent launch", async () => {
  const fx = makeFixture();
  try {
    let calls = 0;
    const result = await executeStep(
      PROJECT_RECONCILIATION_STEP,
      bindings(fx, ["mobile"]),
      deps({
        run: async () => {
          calls += 1;
          return { exitCode: 0 };
        }
      })
    );
    assert.equal(result.ok, false);
    assert.equal(calls, 0);
  } finally {
    rmSync(fx.root, { recursive: true, force: true });
  }
});

test("non-zero agent exit propagates as a failed session", async () => {
  const fx = makeFixture();
  try {
    const result = await executeStep(
      PROJECT_RECONCILIATION_STEP,
      bindings(fx, ["backend"]),
      deps({ run: async () => ({ exitCode: 5 }) })
    );
    assert.equal(result.ok, false);
    assert.match(result.diagnostics.map((d) => d.reason).join("\n"), /exited with code 5/);
  } finally {
    rmSync(fx.root, { recursive: true, force: true });
  }
});

test("definition mutation fails the session even when the agent exits zero", async () => {
  const fx = makeFixture();
  try {
    const result = await executeStep(
      PROJECT_RECONCILIATION_STEP,
      bindings(fx, ["backend"]),
      deps({
        run: async () => {
          writeFileSync(
            path.join(fx.projectDir, "init_progress_definition.yaml"),
            "meta_info:\n  tampered: true\n"
          );
          return { exitCode: 0 };
        }
      })
    );
    assert.equal(result.ok, false);
    assert.match(result.diagnostics.map((d) => d.reason).join("\n"), /mustExistUnchanged/);
  } finally {
    rmSync(fx.root, { recursive: true, force: true });
  }
});

test("missing required contract output fails the session", async () => {
  const fx = makeFixture();
  try {
    const result = await executeStep(
      PROJECT_RECONCILIATION_STEP,
      bindings(fx, ["backend"]),
      deps({
        run: async () => {
          rmSync(path.join(fx.projectDir, "common_contract_definition.md"));
          return { exitCode: 0 };
        }
      })
    );
    assert.equal(result.ok, false);
    assert.match(result.diagnostics.map((d) => d.reason).join("\n"), /Required output not found/);
  } finally {
    rmSync(fx.root, { recursive: true, force: true });
  }
});
