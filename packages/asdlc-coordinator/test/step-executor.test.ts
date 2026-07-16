import { rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import assert from "node:assert/strict";
import test from "node:test";

import { loadRunnerConfig, resolveRunnerPhase } from "../src/config/index.js";
import { STEP_CATALOG } from "../src/sequencing/index.js";
import {
  StubAgentRunner,
  buildSessionPrompt,
  defaultStepExecutorDeps,
  executeStep,
  type StepExecutorDeps
} from "../src/runner/index.js";
import type { ContextResult, GateResult } from "../src/types/index.js";
import type { GateValidator } from "../src/validate/gate-registry.js";

import { withRunnerWorkspace } from "./runner-fixtures.js";

function step(stepId: string) {
  const found = STEP_CATALOG.find((candidate) => candidate.id === stepId);
  assert.ok(found, `Missing step ${stepId}`);
  return found;
}

/** Gate stub the executor invokes for post-session re-gating; passes by default. */
function passingGate(): GateResult {
  return { exitCode: 0, passMessage: "gate passed", problems: [] };
}

function gateReturning(exitCode: 0 | 1 | 2, problems: string[] = []): GateValidator {
  return () => ({
    exitCode,
    passMessage: exitCode === 0 ? "gate passed" : "",
    problems,
    ...(exitCode === 2 ? { errorMessage: problems.join("; ") || "gate runtime error" } : {})
  });
}

/**
 * Default deps pass every review gate so guard-focused tests keep asserting guard
 * behavior; gate-specific tests override `gateRegistry` (CRP-165).
 */
function baseDeps(overrides: Partial<StepExecutorDeps> = {}): StepExecutorDeps {
  return {
    agentRunner: new StubAgentRunner(0),
    loadRunnerConfig,
    resolveRunnerPhase,
    buildSessionPrompt,
    context: {},
    sync: {},
    readiness: {},
    gateRegistry: {
      "requirements-ears": passingGate,
      "ears-review": passingGate,
      "implementation-plan": passingGate,
      "plan-semantic-review": passingGate
    },
    projectGit: defaultStepExecutorDeps.projectGit,
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
    // repo-br-scan and task-to-br carry no from-context guard, so the executor launches them
    // without pre-building their deterministic context.
    assert.deepEqual(order, ["sync:repo-br-scan", "agent:repo-br-scan", "agent:task-to-br"]);
  });
});

test("executeStep runs stack-blueprint then agents-md for a project class", async () => {
  await withRunnerWorkspace(async ({ root, projectDir }) => {
    const order: string[] = [];
    const projectPath = path.relative(root, projectDir);
    const deps = baseDeps({
      agentRunner: {
        run: async (spec) => {
          if (spec.prompt.includes("overmind-stack-blueprint")) {
            order.push("agent:stack-blueprint");
            writeFileSync(path.join(projectDir, "project_stack_blueprint_backend.md"), "# bp\n");
          } else if (spec.prompt.includes("overmind-agents-md")) {
            order.push("agent:agents-md");
            writeFileSync(
              path.join(projectDir, "project_agents_md_claude_md_backend.md"),
              "# agents\n"
            );
          }
          return { exitCode: 0 };
        }
      },
      context: {
        "stack-blueprint": () => {
          order.push("context:stack-blueprint");
          return { exitCode: 0, text: "stack-blueprint context" };
        },
        "agents-md": () => {
          order.push("context:agents-md");
          return { exitCode: 0, text: "agents-md context" };
        }
      }
    });

    const result = await executeStep(
      step("1.1"),
      {
        step: step("1.1"),
        runtimeRoot: root,
        featurePath: projectPath,
        overmindCliPath: ".overmind/overmind.js",
        targetClass: "backend"
      },
      deps
    );

    assert.equal(result.ok, true);
    // stack-blueprint has no from-context guard, so only agents-md pre-builds its context.
    assert.deepEqual(order, ["agent:stack-blueprint", "context:agents-md", "agent:agents-md"]);
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
    assert.deepEqual(order, ["sync:repo-br-scan", "agent:repo-br-scan"]);
  });
});

test("executeStep skips runIf=false sessions as success", async () => {
  await withRunnerWorkspace(async ({ root, projectDir, featurePath }) => {
    writeFileSync(
      path.join(projectDir, "init_progress_definition.yaml"),
      `meta_info:
  project_type_code: A
  project_classes:
    - backend
  class_repo_paths:
    backend:
      state: deferred
      path: ""
      policy: A
steps:
`
    );
    const deps = baseDeps({
      context: {
        "repo-br-scan": () => {
          throw new Error("context should not run");
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

test("executeStep applies step 2 read-only guards to agents-md artifacts", async () => {
  await withRunnerWorkspace(async ({ root, projectDir }) => {
    const protectedFile = path.join(projectDir, "project_agents_md_claude_md_backend.md");
    const deps = baseDeps({
      agentRunner: {
        run: async () => {
          writeFileSync(path.join(projectDir, "common_contract_definition.md"), "# contract\n");
          writeFileSync(protectedFile, "# modified agents\n");
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

test("executeStep applies step 1.1 read-only guards from agents-md context", async () => {
  await withRunnerWorkspace(async ({ root, projectDir }) => {
    const protectedFile = path.join(projectDir, "project_stack_blueprint_backend.md");
    const deps = baseDeps({
      agentRunner: {
        run: async (spec) => {
          if (spec.prompt.includes("overmind-stack-blueprint")) {
            writeFileSync(protectedFile, "# approved blueprint\n");
          } else if (spec.prompt.includes("overmind-agents-md")) {
            writeFileSync(
              path.join(projectDir, "project_agents_md_claude_md_backend.md"),
              "# agents\n"
            );
            writeFileSync(protectedFile, "# modified blueprint\n");
          }
          return { exitCode: 0 };
        }
      },
      context: {
        "stack-blueprint": () => ({ exitCode: 0, text: "stack-blueprint context" }),
        "agents-md": () =>
          ({
            exitCode: 0,
            text: "agents-md context",
            readOnlyInputs: [path.relative(root, protectedFile)]
          }) satisfies ContextResult
      }
    });

    const result = await executeStep(
      step("1.1"),
      {
        step: step("1.1"),
        runtimeRoot: root,
        featurePath: path.relative(root, projectDir),
        overmindCliPath: ".overmind/overmind.js",
        targetClass: "backend"
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

test("executeStep step 5.1 rejects mutation of feature_br_summary.md on agent success", async () => {
  await withRunnerWorkspace(async ({ root, featurePath, featureDir }) => {
    const deps = baseDeps({
      agentRunner: {
        run: async () => {
          writeFileSync(path.join(featureDir, "feature_br_summary.md"), "# tampered summary\n");
          return { exitCode: 0 };
        }
      }
    });

    const result = await executeStep(
      step("5.1"),
      {
        step: step("5.1"),
        runtimeRoot: root,
        featurePath,
        overmindCliPath: ".overmind/overmind.js"
      },
      deps
    );

    assert.equal(result.ok, false);
    assert.match(
      result.diagnostics.map((item) => item.reason).join("\n"),
      /mustExistUnchanged guard violation for .*feature_br_summary\.md/
    );
  });
});

test("executeStep step 5.1 rejects mutation of user_br_input.md even when the agent exits non-zero", async () => {
  await withRunnerWorkspace(async ({ root, featurePath, featureDir }) => {
    const deps = baseDeps({
      agentRunner: {
        run: async () => {
          writeFileSync(path.join(featureDir, "user_br_input.md"), "# tampered input\n");
          return { exitCode: 9 };
        }
      }
    });

    const result = await executeStep(
      step("5.1"),
      {
        step: step("5.1"),
        runtimeRoot: root,
        featurePath,
        overmindCliPath: ".overmind/overmind.js"
      },
      deps
    );

    assert.equal(result.ok, false);
    const reasons = result.diagnostics.map((item) => item.reason).join("\n");
    assert.match(reasons, /mustExistUnchanged guard violation for .*user_br_input\.md/);
    assert.match(reasons, /Agent exited with code 9/);
  });
});

test("executeStep step 5.1 rejects deletion of a guarded business source", async () => {
  await withRunnerWorkspace(async ({ root, featurePath, featureDir }) => {
    const deps = baseDeps({
      agentRunner: {
        run: async () => {
          rmSync(path.join(featureDir, "user_br_input.md"));
          return { exitCode: 0 };
        }
      }
    });

    const result = await executeStep(
      step("5.1"),
      {
        step: step("5.1"),
        runtimeRoot: root,
        featurePath,
        overmindCliPath: ".overmind/overmind.js"
      },
      deps
    );

    assert.equal(result.ok, false);
    assert.match(
      result.diagnostics.map((item) => item.reason).join("\n"),
      /mustExistUnchanged guard violation for .*user_br_input\.md/
    );
  });
});

test("executeStep step 5.1 accepts an agent run that leaves both business sources unchanged", async () => {
  await withRunnerWorkspace(async ({ root, featurePath, featureDir }) => {
    const deps = baseDeps({
      agentRunner: {
        run: async () => {
          writeFileSync(path.join(featureDir, "requirements_ears_review.md"), "# updated review\n");
          return { exitCode: 0 };
        }
      }
    });

    const result = await executeStep(
      step("5.1"),
      {
        step: step("5.1"),
        runtimeRoot: root,
        featurePath,
        overmindCliPath: ".overmind/overmind.js"
      },
      deps
    );

    assert.equal(result.ok, true);
  });
});

test("executeStep step 5 guards only feature_br_summary.md, not user_br_input.md", async () => {
  await withRunnerWorkspace(async ({ root, featurePath, featureDir }) => {
    const deps = baseDeps({
      agentRunner: {
        run: async () => {
          // Step 5 (br-to-ears) generates requirements_ears.md and only summary is guarded;
          // touching user_br_input.md must not trip the summary-only guard.
          writeFileSync(path.join(featureDir, "user_br_input.md"), "# touched input\n");
          writeFileSync(path.join(featureDir, "requirements_ears.md"), "# regenerated EARS\n");
          return { exitCode: 0 };
        }
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

    assert.equal(result.ok, true);
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

test("session with no fromContext guard launches without building context", async () => {
  await withRunnerWorkspace(async ({ root, featurePath }) => {
    let contextCalls = 0;
    let agentCalls = 0;
    const stepDef = {
      id: "custom-task-to-br",
      label: "task-to-br only",
      optional: false,
      perClass: false,
      resumeAliases: [],
      actions: [
        {
          kind: "session" as const,
          skillName: "task-to-br",
          modelPhase: "task_to_br",
          readOnlyGuards: [],
          requiredOutputs: ["feature_br_summary.md"]
        }
      ]
    };
    const result = await executeStep(
      stepDef,
      { step: stepDef, runtimeRoot: root, featurePath, overmindCliPath: ".overmind/overmind.js" },
      baseDeps({
        agentRunner: {
          run: async () => {
            agentCalls += 1;
            return { exitCode: 0 };
          }
        },
        context: {
          // A builder that would abort the step if the executor pre-called it.
          "task-to-br": () => {
            contextCalls += 1;
            return { exitCode: 2, errorMessage: "Required file not found: user_br_input.md" };
          }
        }
      })
    );

    assert.equal(result.ok, true);
    assert.equal(contextCalls, 0);
    assert.equal(agentCalls, 1);
  });
});

test("session with a fromContext guard fails on a non-zero context exit and launches no session", async () => {
  await withRunnerWorkspace(async ({ root, featurePath }) => {
    let agentCalls = 0;
    const stepDef = {
      id: "custom-from-context",
      label: "contract-delta only",
      optional: false,
      perClass: false,
      resumeAliases: [],
      actions: [
        {
          kind: "session" as const,
          skillName: "contract-delta",
          modelPhase: "feature_contract_delta",
          readOnlyGuards: [{ mode: "fromContext" as const }],
          requiredOutputs: []
        }
      ]
    };
    const result = await executeStep(
      stepDef,
      { step: stepDef, runtimeRoot: root, featurePath, overmindCliPath: ".overmind/overmind.js" },
      baseDeps({
        agentRunner: {
          run: async () => {
            agentCalls += 1;
            return { exitCode: 0 };
          }
        },
        context: {
          "contract-delta": () => ({ exitCode: 2, errorMessage: "context builder blew up" })
        }
      })
    );

    assert.equal(result.ok, false);
    assert.equal(result.exitCode, 2);
    assert.equal(agentCalls, 0);
    assert.match(
      result.diagnostics.map((item) => item.reason).join("\n"),
      /context builder blew up/
    );
  });
});

test("executeStep runs a blueprint-backed surface-map session without a ready class repo", async () => {
  await withRunnerWorkspace(async ({ root, projectDir, featurePath, featureDir }) => {
    writeFileSync(
      path.join(projectDir, "init_progress_definition.yaml"),
      `meta_info:
  project_type_code: A
  project_classes:
    - backend
  class_repo_paths:
    backend:
      state: deferred
      path: ""
      policy: A
steps:
`
    );
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

// --- CRP-165 post-session mutable-artifact gates ---

function run51(root: string, featurePath: string, deps: StepExecutorDeps) {
  return executeStep(
    step("5.1"),
    { step: step("5.1"), runtimeRoot: root, featurePath, overmindCliPath: ".overmind/overmind.js" },
    deps
  );
}

test("executeStep step 5.1 runs post-session gates in declared order and passes when all pass", async () => {
  await withRunnerWorkspace(async ({ root, featurePath, featureDir }) => {
    const order: string[] = [];
    const deps = baseDeps({
      agentRunner: {
        run: async () => {
          writeFileSync(path.join(featureDir, "requirements_ears_review.md"), "# review\n");
          return { exitCode: 0 };
        }
      },
      gateRegistry: {
        "requirements-ears": () => {
          order.push("requirements-ears");
          return passingGate();
        },
        "ears-review": () => {
          order.push("ears-review");
          return passingGate();
        }
      }
    });

    const result = await run51(root, featurePath, deps);

    assert.equal(result.ok, true);
    assert.equal(result.exitCode, 0);
    // Normative artifact first, ledger second (contract order).
    assert.deepEqual(order, ["requirements-ears", "ears-review"]);
  });
});

test("executeStep step 5.1 runs every gate even after the first fails and keeps all diagnostics", async () => {
  await withRunnerWorkspace(async ({ root, featurePath }) => {
    const order: string[] = [];
    const deps = baseDeps({
      gateRegistry: {
        "requirements-ears": () => {
          order.push("requirements-ears");
          return { exitCode: 1, passMessage: "", problems: ["req 12 invalid EARS"] };
        },
        "ears-review": () => {
          order.push("ears-review");
          return { exitCode: 1, passMessage: "", problems: ["ledger finding open"] };
        }
      }
    });

    const result = await run51(root, featurePath, deps);

    assert.equal(result.ok, false);
    assert.deepEqual(order, ["requirements-ears", "ears-review"]);
    const reasons = result.diagnostics.map((item) => item.reason).join("\n");
    assert.match(reasons, /requirements_ears\.md/);
    assert.match(reasons, /req 12 invalid EARS/);
    assert.match(reasons, /requirements_ears_review\.md/);
    assert.match(reasons, /ledger finding open/);
  });
});

test("executeStep step 5.1 returns exit 1 when a gate is recoverably invalid and none are exit 2", async () => {
  await withRunnerWorkspace(async ({ root, featurePath }) => {
    const deps = baseDeps({
      gateRegistry: {
        "requirements-ears": gateReturning(1, ["invalid EARS"]),
        "ears-review": gateReturning(0)
      }
    });

    const result = await run51(root, featurePath, deps);

    assert.equal(result.ok, false);
    assert.equal(result.exitCode, 1);
    assert.match(
      result.diagnostics.map((item) => item.reason).join("\n"),
      /Post-session gate 'requirements-ears' failed for requirements_ears\.md/
    );
  });
});

test("executeStep step 5.1 returns exit 2 when any gate returns exit 2, retaining both diagnostics", async () => {
  await withRunnerWorkspace(async ({ root, featurePath }) => {
    const deps = baseDeps({
      gateRegistry: {
        "requirements-ears": gateReturning(1, ["invalid EARS"]),
        "ears-review": gateReturning(2, ["cannot read ledger"])
      }
    });

    const result = await run51(root, featurePath, deps);

    assert.equal(result.ok, false);
    assert.equal(result.exitCode, 2);
    const reasons = result.diagnostics.map((item) => item.reason).join("\n");
    assert.match(reasons, /invalid EARS/);
    assert.match(reasons, /cannot read ledger/);
  });
});

test("executeStep step 5.1 treats an unregistered declared gate as exit 2 but runs the rest", async () => {
  await withRunnerWorkspace(async ({ root, featurePath }) => {
    const order: string[] = [];
    const deps = baseDeps({
      gateRegistry: {
        // requirements-ears intentionally absent from the injected registry.
        "ears-review": () => {
          order.push("ears-review");
          return passingGate();
        }
      }
    });

    const result = await run51(root, featurePath, deps);

    assert.equal(result.ok, false);
    assert.equal(result.exitCode, 2);
    assert.deepEqual(order, ["ears-review"]);
    assert.match(
      result.diagnostics.map((item) => item.reason).join("\n"),
      /Post-session gate 'requirements-ears' for requirements_ears\.md is not registered/
    );
  });
});

test("executeStep does not invoke post-session gates for a step without a declared set", async () => {
  await withRunnerWorkspace(async ({ root, featurePath, featureDir }) => {
    let gateCalls = 0;
    const deps = baseDeps({
      agentRunner: {
        run: async () => {
          writeFileSync(path.join(featureDir, "requirements_ears.md"), "# regenerated EARS\n");
          return { exitCode: 0 };
        }
      },
      gateRegistry: {
        "requirements-ears": () => {
          gateCalls += 1;
          return passingGate();
        }
      }
    });

    // Step 5 (br-to-ears) declares no postSessionGates.
    const result = await executeStep(
      step("5"),
      { step: step("5"), runtimeRoot: root, featurePath, overmindCliPath: ".overmind/overmind.js" },
      deps
    );

    assert.equal(result.ok, true);
    assert.equal(gateCalls, 0);
  });
});

test("executeStep does not invoke post-session gates when the agent exits non-zero", async () => {
  await withRunnerWorkspace(async ({ root, featurePath }) => {
    let gateCalls = 0;
    const deps = baseDeps({
      agentRunner: { run: async () => ({ exitCode: 7 }) },
      gateRegistry: {
        "requirements-ears": () => {
          gateCalls += 1;
          return passingGate();
        },
        "ears-review": () => {
          gateCalls += 1;
          return passingGate();
        }
      }
    });

    const result = await run51(root, featurePath, deps);

    assert.equal(result.ok, false);
    assert.equal(result.exitCode, 7);
    assert.equal(gateCalls, 0);
  });
});
