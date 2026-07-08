import { writeFileSync } from "node:fs";
import path from "node:path";
import assert from "node:assert/strict";
import test from "node:test";

import { loadRunnerConfig, resolveRunnerPhase } from "../src/config/index.js";
import { STEP_CATALOG } from "../src/sequencing/index.js";
import {
  StubAgentRunner,
  buildSessionPrompt,
  executeStep,
  type StepExecutorDeps
} from "../src/runner/index.js";
import type { ContextResult } from "../src/types/index.js";

import { withRunnerWorkspace } from "./runner-fixtures.js";

function step(stepId: string) {
  const found = STEP_CATALOG.find((candidate) => candidate.id === stepId);
  assert.ok(found, `Missing step ${stepId}`);
  return found;
}

function baseDeps(overrides: Partial<StepExecutorDeps> = {}): StepExecutorDeps {
  return {
    agentRunner: new StubAgentRunner(0),
    loadRunnerConfig,
    resolveRunnerPhase,
    buildSessionPrompt,
    context: {},
    sync: {},
    readiness: {},
    write: {},
    ...overrides
  };
}

test("executeStep runs multi-action steps in declared order", async () => {
  await withRunnerWorkspace(async ({ root, featurePath }) => {
    const order: string[] = [];
    const deps = baseDeps({
      agentRunner: {
        run: async (spec) => {
          order.push(
            `agent:${spec.prompt.includes("repo-br-scan") ? "repo-br-scan" : "task-to-br"}`
          );
          return { exitCode: 0 };
        }
      },
      context: {
        "repo-br-scan": () => {
          order.push("context:repo-br-scan");
          return { exitCode: 0, text: "repo-br-scan context" };
        },
        "task-to-br": () => {
          order.push("context:task-to-br");
          return { exitCode: 0, text: "task-to-br context" };
        }
      },
      sync: {
        "repo-br-scan": () => {
          order.push("sync:repo-br-scan");
          return { exitCode: 0 };
        }
      }
    });

    const result = await executeStep(
      step("4.1"),
      {
        step: step("4.1"),
        runtimeRoot: root,
        featurePath,
        overmindCliPath: ".overmind/overmind.js"
      },
      deps
    );

    assert.equal(result.ok, true);
    assert.deepEqual(order, [
      "sync:repo-br-scan",
      "context:repo-br-scan",
      "agent:repo-br-scan",
      "context:task-to-br",
      "agent:task-to-br"
    ]);
  });
});

test("executeStep stops after the first failing action", async () => {
  await withRunnerWorkspace(async ({ root, featurePath }) => {
    const order: string[] = [];
    const deps = baseDeps({
      agentRunner: {
        run: async () => {
          order.push("agent:repo-br-scan");
          return { exitCode: 7 };
        }
      },
      context: {
        "repo-br-scan": () => {
          order.push("context:repo-br-scan");
          return { exitCode: 0, text: "repo-br-scan context" };
        },
        "task-to-br": () => {
          order.push("context:task-to-br");
          return { exitCode: 0, text: "task-to-br context" };
        }
      },
      sync: {
        "repo-br-scan": () => {
          order.push("sync:repo-br-scan");
          return { exitCode: 0 };
        }
      }
    });

    const result = await executeStep(
      step("4.1"),
      {
        step: step("4.1"),
        runtimeRoot: root,
        featurePath,
        overmindCliPath: ".overmind/overmind.js"
      },
      deps
    );

    assert.equal(result.ok, false);
    assert.deepEqual(order, ["sync:repo-br-scan", "context:repo-br-scan", "agent:repo-br-scan"]);
  });
});

test("executeStep skips runIf=false sessions as success", async () => {
  await withRunnerWorkspace(async ({ root, featurePath }) => {
    const deps = baseDeps({
      context: {
        "surface-map": () => {
          throw new Error("context should not run");
        }
      }
    });

    const result = await executeStep(
      step("7"),
      {
        step: step("7"),
        runtimeRoot: root,
        featurePath,
        overmindCliPath: ".overmind/overmind.js",
        targetClass: "frontend"
      },
      deps
    );

    assert.equal(result.ok, true);
    assert.equal(result.actionResults[0]!.status, "skipped");
    assert.match(result.actionResults[0]!.diagnostics[0]!.reason, /hasReadyClassRepo/);
  });
});

test("executeStep preserves sync -> context -> agent order for fromContext sessions", async () => {
  await withRunnerWorkspace(async ({ root, featurePath, featureDir }) => {
    const protectedFile = path.join(featureDir, "requirements_ears.md");
    const order: string[] = [];
    const deps = baseDeps({
      agentRunner: {
        run: async () => {
          order.push("agent");
          return { exitCode: 0 };
        }
      },
      context: {
        "contract-delta": () => {
          order.push("context");
          const relative = path.relative(root, protectedFile);
          return { exitCode: 0, text: "contract-delta context", readOnlyInputs: [relative] };
        }
      },
      sync: {
        "contract-delta": () => {
          order.push("sync");
          return { exitCode: 0 };
        }
      }
    });

    const result = await executeStep(
      step("6"),
      {
        step: step("6"),
        runtimeRoot: root,
        featurePath,
        overmindCliPath: ".overmind/overmind.js"
      },
      deps
    );

    assert.equal(result.ok, true);
    assert.deepEqual(order, ["sync", "context", "agent"]);
  });
});

test("executeStep verifies guards even when the agent exits non-zero", async () => {
  await withRunnerWorkspace(async ({ root, featurePath, featureDir }) => {
    const protectedFile = path.join(featureDir, "requirements_ears.md");
    const deps = baseDeps({
      agentRunner: {
        run: async () => {
          writeFileSync(protectedFile, "# modified\n");
          return { exitCode: 9 };
        }
      },
      context: {
        "contract-delta": () =>
          ({
            exitCode: 0,
            text: "contract-delta context",
            readOnlyInputs: [path.relative(root, protectedFile)]
          }) satisfies ContextResult
      },
      sync: {
        "contract-delta": () => ({ exitCode: 0 })
      }
    });

    const result = await executeStep(
      step("6"),
      {
        step: step("6"),
        runtimeRoot: root,
        featurePath,
        overmindCliPath: ".overmind/overmind.js"
      },
      deps
    );

    assert.equal(result.ok, false);
    assert.match(
      result.diagnostics.map((item) => item.reason).join("\n"),
      /fromContext guard violation/
    );
    assert.match(
      result.diagnostics.map((item) => item.reason).join("\n"),
      /Agent exited with code 9/
    );
  });
});

test("executeStep applies step 2 read-only guards from common-contract context", async () => {
  await withRunnerWorkspace(async ({ root, projectDir }) => {
    const protectedFile = path.join(projectDir, "project_stack_blueprint_backend.md");
    const deps = baseDeps({
      agentRunner: {
        run: async () => {
          writeFileSync(path.join(projectDir, "common_contract_definition.md"), "# contract\n");
          writeFileSync(protectedFile, "# modified blueprint\n");
          return { exitCode: 0 };
        }
      },
      classListContext: {
        "common-contract": () =>
          ({
            exitCode: 0,
            text: "common-contract context",
            readOnlyInputs: [path.relative(root, protectedFile)]
          }) satisfies ContextResult
      }
    });

    const result = await executeStep(
      step("2"),
      {
        step: step("2"),
        runtimeRoot: root,
        featurePath: path.relative(root, projectDir),
        overmindCliPath: ".overmind/overmind.js",
        classes: ["backend"]
      },
      deps
    );

    assert.equal(result.ok, false);
    assert.match(
      result.diagnostics.map((item) => item.reason).join("\n"),
      /fromContext guard violation/
    );
  });
});

test("executeStep surfaces an agent launch failure as an actionable failed step", async () => {
  await withRunnerWorkspace(async ({ root, featurePath }) => {
    const deps = baseDeps({
      agentRunner: {
        run: async () => ({
          exitCode: 127,
          errorMessage: "Failed to launch 'codex': spawn codex ENOENT"
        })
      },
      context: {
        "requirements-ears": () =>
          ({ exitCode: 0, text: "requirements-ears context" }) satisfies ContextResult
      }
    });

    const result = await executeStep(
      step("5"),
      {
        step: step("5"),
        runtimeRoot: root,
        featurePath,
        overmindCliPath: ".overmind/overmind.js"
      },
      deps
    );

    assert.equal(result.ok, false);
    assert.match(
      result.diagnostics.map((item) => item.reason).join("\n"),
      /Agent failed for skill 'requirements-ears'.*ENOENT/
    );
  });
});

test("executeStep allows an empty fromContext read-only input set", async () => {
  await withRunnerWorkspace(async ({ root, featurePath }) => {
    let agentCalls = 0;
    const result = await executeStep(
      step("6"),
      {
        step: step("6"),
        runtimeRoot: root,
        featurePath,
        overmindCliPath: ".overmind/overmind.js"
      },
      baseDeps({
        agentRunner: {
          run: async () => {
            agentCalls += 1;
            return { exitCode: 0 };
          }
        },
        context: {
          "contract-delta": () => ({
            exitCode: 0,
            text: "contract-delta context",
            readOnlyInputs: []
          })
        },
        sync: {
          "contract-delta": () => ({ exitCode: 0 })
        }
      })
    );

    assert.equal(result.ok, true);
    assert.equal(agentCalls, 1);
  });
});

test("executeStep fails before spawn when a fromContext input is missing", async () => {
  await withRunnerWorkspace(async ({ root, featurePath, featureDir }) => {
    let agentCalls = 0;
    const missingInput = path.join(featureDir, "missing.md");
    const result = await executeStep(
      step("6"),
      {
        step: step("6"),
        runtimeRoot: root,
        featurePath,
        overmindCliPath: ".overmind/overmind.js"
      },
      baseDeps({
        agentRunner: {
          run: async () => {
            agentCalls += 1;
            return { exitCode: 0 };
          }
        },
        context: {
          "contract-delta": () => ({
            exitCode: 0,
            text: "contract-delta context",
            readOnlyInputs: [path.relative(root, missingInput)]
          })
        },
        sync: {
          "contract-delta": () => ({ exitCode: 0 })
        }
      })
    );

    assert.equal(result.ok, false);
    assert.equal(agentCalls, 0);
    assert.match(result.diagnostics[0]!.reason, /must exist before the session starts/);
  });
});

test("executeStep dispatches readiness checks and reports unknown deterministic actions", async () => {
  await withRunnerWorkspace(async ({ root, featurePath }) => {
    let readinessCalls = 0;
    const readinessResult = await executeStep(
      step("4.2"),
      {
        step: step("4.2"),
        runtimeRoot: root,
        featurePath,
        overmindCliPath: ".overmind/overmind.js"
      },
      baseDeps({
        agentRunner: new StubAgentRunner(0),
        context: {
          "br-clarification": () => ({ exitCode: 0, text: "br-clarification context" })
        },
        readiness: {
          "br-clarification-readiness": () => {
            readinessCalls += 1;
            return { exitCode: 0, message: "ready" };
          }
        }
      })
    );

    assert.equal(readinessCalls, 1);
    assert.equal(readinessResult.ok, true);

    const unknownResult = await executeStep(
      {
        id: "x",
        label: "Unknown deterministic",
        optional: false,
        perClass: false,
        resumeAliases: [],
        actions: [{ kind: "check", name: "missing-check" }]
      },
      {
        step: step("4.2"),
        runtimeRoot: root,
        featurePath,
        overmindCliPath: ".overmind/overmind.js"
      },
      baseDeps()
    );

    assert.equal(unknownResult.ok, false);
    assert.match(unknownResult.diagnostics[0]!.reason, /Unknown check action/);
  });
});

test("executeStep passes a single-class binding into the per-class surface-map session", async () => {
  await withRunnerWorkspace(async ({ root, featurePath, featureDir }) => {
    let prompt = "";
    const protectedFile = path.join(featureDir, "feature_contract_delta.md");
    const deps = baseDeps({
      agentRunner: {
        run: async (spec) => {
          prompt = spec.prompt;
          return { exitCode: 0 };
        }
      },
      context: {
        "surface-map": () => ({
          exitCode: 0,
          text: "surface-map context",
          readOnlyInputs: [path.relative(root, protectedFile)]
        })
      },
      sync: {
        "surface-map": () => ({ exitCode: 0 })
      }
    });

    const result = await executeStep(
      step("7"),
      {
        step: step("7"),
        runtimeRoot: root,
        featurePath,
        overmindCliPath: ".overmind/overmind.js",
        targetClass: "backend"
      },
      deps
    );

    assert.equal(result.ok, true);
    assert.match(prompt, /Target class: backend/);
    assert.match(prompt, /project_surface_struct_resp_map_backend\.md/);
  });
});
