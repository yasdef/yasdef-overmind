import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { runProjectReconciliationFlow } from "../src/orchestrator/run-project-reconciliation-flow.js";
import type {
  ProjectReconciliationDeps,
  ReconciliationSessionResult
} from "../src/orchestrator/run-project-reconciliation-flow.js";
import { readProjectDefinitionMetadata } from "../src/parse/project-definition.js";
import type { PathInspectionResult, ProjectGitPort, WorktreeStatus } from "../src/git/index.js";
import { InteractionClosedError, type InteractionPort } from "../src/interaction/index.js";

function initGitRepo(dir: string): string {
  mkdirSync(dir, { recursive: true });
  execFileSync("git", ["init", "-q"], { cwd: dir });
  return dir;
}

interface Ctx {
  root: string;
  projectDir: string;
  definitionPath: string;
  repo(name: string): string;
}

function withProject(defBody: string, fn: (ctx: Ctx) => Promise<void> | void): Promise<void> {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-reconcile-flow-"));
  const projectDir = path.join(root, "projects", "p1");
  mkdirSync(projectDir, { recursive: true });
  const definitionPath = path.join(projectDir, "init_progress_definition.yaml");
  writeFileSync(
    definitionPath,
    `meta_info:
  project_type_code: A
  project_classes: [backend, frontend, mobile]
  class_repo_paths:
${defBody}
steps:
  - id: "1"
`
  );
  writeFileSync(path.join(projectDir, "common_contract_definition.md"), "# Common contract\n");
  const ctx: Ctx = {
    root,
    projectDir,
    definitionPath,
    repo: (name) => initGitRepo(path.join(root, "repos", name))
  };
  return Promise.resolve(fn(ctx)).finally(() => rmSync(root, { recursive: true, force: true }));
}

function fakeInteraction(inputs: Array<string | null>, confirms: boolean[]): InteractionPort {
  const inputQueue = [...inputs];
  const confirmQueue = [...confirms];
  return {
    async input() {
      const next = inputQueue.shift();
      if (next === undefined || next === null) throw new InteractionClosedError();
      return next;
    },
    async confirm() {
      const next = confirmQueue.shift();
      if (next === undefined) throw new InteractionClosedError();
      return next;
    },
    async select() {
      throw new Error("select not expected");
    }
  };
}

function passThroughGit(): ProjectGitPort {
  return {
    worktreeStatus: (): WorktreeStatus => ({ kind: "unavailable" }),
    changedPaths: () => ({ kind: "unavailable" }),
    commitOwnedPaths: () => ({ kind: "unavailable" })
  };
}

function validCommonContract(): string {
  return `# Common Contract Definition

## 1. Document Meta
- project_id: PROJ-1
- source_repo_count: 1
- last_updated: 2026-06-27
- confidence_level: high

## 2. Source Repository Evidence
### Repository: api
- class: backend
- repo_path: /repos/api
- contract_evidence_summary: reviewed routes
- key_surfaces_reviewed: /users
- notes: none

## 3. Common Contract Baseline
### Contract: users-api
- contract_kind: http_api
- interaction_mode: sync
- producer_repositories: api
- consumer_repositories: web
- contract_surface: GET /users
- contract_status: aligned
- source_of_truth: api
- canonical_shape: request: {} -> response: {id, name}
- shared_types: User
- trust_boundary: internal
- compatibility_rule: additive-only
- planning_implication: none
- notes: none

## 4. Reconciliation Decisions
- decision_1: adopt api as source of truth

## 5. Known Risks / Uncertainties
- uncertainty_1: none

## 6. Common Planning Signals
- prep_1: wire consumer tests
`;
}

function pendingSharedCheckpointInspection(): PathInspectionResult {
  return {
    kind: "ok",
    paths: [
      {
        path: "init_progress_definition.yaml",
        hasHeadVersion: true,
        staged: false,
        unstaged: false,
        untracked: false
      },
      {
        path: "common_contract_definition.md",
        hasHeadVersion: true,
        staged: false,
        unstaged: true,
        untracked: false
      }
    ]
  };
}

function baseDeps(
  ctx: Ctx,
  overrides: Partial<ProjectReconciliationDeps> & {
    runReconciliationSession?: ProjectReconciliationDeps["runReconciliationSession"];
  }
): ProjectReconciliationDeps {
  return {
    projectRoot: ctx.projectDir,
    projectPathRel: "projects/p1",
    interaction: overrides.interaction ?? fakeInteraction([], []),
    git: overrides.git ?? passThroughGit(),
    runReconciliationSession:
      overrides.runReconciliationSession ??
      (async (): Promise<ReconciliationSessionResult> => ({ ok: true, diagnostics: [] })),
    emit: overrides.emit ?? (() => {}),
    emitError: overrides.emitError ?? (() => {}),
    ...(overrides.attach ? { attach: overrides.attach } : {})
  };
}

test("no pending work is a side-effect-free success with no git or session calls", async () => {
  await withProject(
    `    backend:
      state: "ready"
      path: "/x"
      policy: "C"
      contract_reconciled: true`,
    async (ctx) => {
      let gitCalls = 0;
      let sessionCalls = 0;
      const before = readFileSync(ctx.definitionPath, "utf8");
      const outcome = await runProjectReconciliationFlow(
        baseDeps(ctx, {
          git: {
            worktreeStatus: () => {
              gitCalls += 1;
              return { kind: "clean" };
            },
            changedPaths: () => ({ kind: "unavailable" }),
            commitOwnedPaths: () => ({ kind: "unavailable" })
          },
          runReconciliationSession: async () => {
            sessionCalls += 1;
            return { ok: true, diagnostics: [] };
          }
        })
      );
      assert.equal(outcome.kind, "noPendingWork");
      assert.equal(gitCalls, 0);
      assert.equal(sessionCalls, 0);
      assert.equal(readFileSync(ctx.definitionPath, "utf8"), before);
    }
  );
});

test("pending shared checkpoint commit completes when no reconciliation work remains", async () => {
  await withProject(
    `    backend:
      state: "ready"
      path: "/x"
      policy: "C"
      contract_reconciled: true`,
    async (ctx) => {
      writeFileSync(
        path.join(ctx.projectDir, "common_contract_definition.md"),
        validCommonContract()
      );
      const emitted: string[] = [];
      let worktreeCalls = 0;
      let sessionCalls = 0;
      let committedPaths: string[] = [];

      const outcome = await runProjectReconciliationFlow(
        baseDeps(ctx, {
          interaction: fakeInteraction([], [true]),
          git: {
            worktreeStatus: () => {
              worktreeCalls += 1;
              return { kind: "clean" };
            },
            changedPaths: () => ({ kind: "ok", paths: ["common_contract_definition.md"] }),
            inspectPaths: () => pendingSharedCheckpointInspection(),
            commitOwnedPaths: (_root, paths) => {
              committedPaths = paths;
              return { kind: "committed" };
            }
          },
          runReconciliationSession: async () => {
            sessionCalls += 1;
            return { ok: true, diagnostics: [] };
          },
          emit: (line) => emitted.push(line)
        })
      );

      assert.deepEqual(outcome, { kind: "completed", committed: true });
      assert.deepEqual(committedPaths, [
        "init_progress_definition.yaml",
        "common_contract_definition.md"
      ]);
      assert.equal(worktreeCalls, 0);
      assert.equal(sessionCalls, 0);
      assert.ok(emitted.some((line) => line.includes("Committed reconciliation unit")));
      assert.ok(!emitted.some((line) => line.includes("No pending project reconciliation work")));
    }
  );
});

test("pending shared checkpoint commit continues remaining reconciliation work", async () => {
  await withProject(
    `    backend:
      state: "ready"
      path: "/x"
      policy: "C"
      contract_reconciled: false`,
    async (ctx) => {
      writeFileSync(
        path.join(ctx.projectDir, "common_contract_definition.md"),
        validCommonContract()
      );
      const emitted: string[] = [];
      let worktreeCalls = 0;
      let changedCalls = 0;
      let sessionClasses: string[] = [];
      const commits: string[][] = [];

      const outcome = await runProjectReconciliationFlow(
        baseDeps(ctx, {
          interaction: fakeInteraction([], [true, true]),
          git: {
            worktreeStatus: () => {
              worktreeCalls += 1;
              return { kind: "clean" };
            },
            changedPaths: () => {
              changedCalls += 1;
              return {
                kind: "ok",
                paths:
                  changedCalls === 1
                    ? ["init_progress_definition.yaml"]
                    : ["init_progress_definition.yaml", "common_contract_definition.md"]
              };
            },
            inspectPaths: () => pendingSharedCheckpointInspection(),
            commitOwnedPaths: (_root, paths) => {
              commits.push(paths);
              return { kind: "committed" };
            }
          },
          runReconciliationSession: async (classes) => {
            sessionClasses = classes;
            return { ok: true, diagnostics: [] };
          },
          emit: (line) => emitted.push(line)
        })
      );

      assert.deepEqual(outcome, { kind: "completed", committed: true });
      assert.deepEqual(commits, [
        ["init_progress_definition.yaml", "common_contract_definition.md"],
        ["init_progress_definition.yaml", "common_contract_definition.md"]
      ]);
      assert.equal(worktreeCalls, 1);
      assert.deepEqual(sessionClasses, ["backend"]);
      assert.ok(emitted.some((line) => line.includes("Committed reconciliation unit")));
      assert.ok(emitted.some((line) => line.includes("Reconciling 1 pending class(es): backend")));
      const metadata = readProjectDefinitionMetadata(ctx.definitionPath);
      assert.equal(metadata.classRepoPaths.backend!.contractReconciled, true);
    }
  );
});

test("pending shared checkpoint validates reconciliation content before commit", async () => {
  await withProject(
    `    backend:
      state: "ready"
      path: "/x"
      policy: "C"
      contract_reconciled: true`,
    async (ctx) => {
      let commitCalls = 0;

      const outcome = await runProjectReconciliationFlow(
        baseDeps(ctx, {
          interaction: fakeInteraction([], [true]),
          git: {
            worktreeStatus: () => ({ kind: "clean" }),
            changedPaths: () => ({ kind: "ok", paths: ["common_contract_definition.md"] }),
            inspectPaths: () => pendingSharedCheckpointInspection(),
            commitOwnedPaths: () => {
              commitCalls += 1;
              return { kind: "committed" };
            }
          },
          runReconciliationSession: async () => {
            throw new Error("session should not run for a pending shared checkpoint");
          }
        })
      );

      assert.equal(outcome.kind, "failed");
      assert.equal(commitCalls, 0);
      if (outcome.kind === "failed") {
        assert.ok(
          outcome.diagnostics.some((diagnostic) =>
            diagnostic.reason.includes("Pending shared reconciliation checkpoint is invalid")
          )
        );
      }
    }
  );
});

test("pending shared checkpoint commit failure remains fatal", async () => {
  await withProject(
    `    backend:
      state: "ready"
      path: "/x"
      policy: "C"
      contract_reconciled: true`,
    async (ctx) => {
      writeFileSync(
        path.join(ctx.projectDir, "common_contract_definition.md"),
        validCommonContract()
      );

      const outcome = await runProjectReconciliationFlow(
        baseDeps(ctx, {
          interaction: fakeInteraction([], [true]),
          git: {
            worktreeStatus: () => ({ kind: "clean" }),
            changedPaths: () => ({ kind: "ok", paths: ["common_contract_definition.md"] }),
            inspectPaths: () => pendingSharedCheckpointInspection(),
            commitOwnedPaths: () => ({
              kind: "commitFailed",
              exitCode: 1,
              stderr: "commit refused"
            })
          },
          runReconciliationSession: async () => {
            throw new Error("session should not run for a pending shared checkpoint");
          }
        })
      );

      assert.equal(outcome.kind, "failed");
      if (outcome.kind === "failed") {
        assert.ok(
          outcome.diagnostics.some((diagnostic) => diagnostic.reason.includes("Commit failed"))
        );
        assert.ok(
          !outcome.diagnostics.some((diagnostic) => diagnostic.reason.includes("No pending"))
        );
      }
    }
  );
});

test("ordered prompts, blank defer, and all attaches precede one reconciliation session", async () => {
  await withProject(
    `    backend:
      state: "deferred"
      path: ""
      policy: "B"
    frontend:
      state: "deferred"
      path: ""
      policy: "B"
    mobile:
      state: "deferred"
      path: ""
      policy: "B"`,
    async (ctx) => {
      const backend = ctx.repo("api");
      const frontend = ctx.repo("web");
      // backend attaches, frontend blank-defers, mobile attaches.
      let sessionClasses: string[] = [];
      const outcome = await runProjectReconciliationFlow(
        baseDeps(ctx, {
          interaction: fakeInteraction(["C", backend, "B", "", "C", ctx.repo("app")], [false]),
          git: {
            worktreeStatus: () => ({ kind: "clean" }),
            changedPaths: () => ({ kind: "ok", paths: ["init_progress_definition.yaml"] }),
            commitOwnedPaths: () => ({ kind: "committed" })
          },
          runReconciliationSession: async (classes) => {
            sessionClasses = classes;
            // Confirm all attaches happened before the session ran.
            const meta = readProjectDefinitionMetadata(ctx.definitionPath);
            assert.equal(meta.classRepoPaths.backend!.state, "ready");
            assert.equal(meta.classRepoPaths.backend!.policy, "C");
            assert.equal(meta.classRepoPaths.mobile!.state, "ready");
            assert.equal(meta.classRepoPaths.mobile!.policy, "C");
            assert.equal(meta.classRepoPaths.frontend!.state, "deferred");
            assert.equal(meta.classRepoPaths.frontend!.policy, "B");
            return { ok: true, diagnostics: [] };
          }
        })
      );
      assert.equal(outcome.kind, "stoppedByOperator"); // declined commit
      assert.deepEqual(sessionClasses.sort(), ["backend", "mobile"]);
      void frontend;
    }
  );
});

test("exactly one retry after an invalid path, then the class stays deferred", async () => {
  await withProject(
    `    backend:
      state: "deferred"
      path: ""
      policy: "B"
    frontend:
      state: "ready"
      path: "/y"
      policy: "C"
      contract_reconciled: true`,
    async (ctx) => {
      let inputCount = 0;
      const interaction: InteractionPort = {
        async input() {
          inputCount += 1;
          return inputCount === 1 ? "C" : "/not/a/repo"; // policy once, path twice
        },
        async confirm() {
          return false;
        },
        async select() {
          throw new Error("no");
        }
      };
      const outcome = await runProjectReconciliationFlow(
        baseDeps(ctx, {
          interaction,
          git: passThroughGit(),
          runReconciliationSession: async () => {
            throw new Error("session should not run when nothing pending");
          }
        })
      );
      // Policy prompt plus two path attempts (initial + one retry), no third path prompt.
      assert.equal(inputCount, 3);
      // backend stayed deferred, frontend already reconciled => no pending session.
      assert.equal(outcome.kind, "noPendingWork");
      const meta = readProjectDefinitionMetadata(ctx.definitionPath);
      assert.equal(meta.classRepoPaths.backend!.state, "deferred");
      assert.equal(meta.classRepoPaths.backend!.path, "");
      assert.equal(meta.classRepoPaths.backend!.policy, "C");
    }
  );
});

test("blank policy prompt keeps existing B policy and still asks for repo path", async () => {
  await withProject(
    `    backend:
      state: "deferred"
      path: ""
      policy: "B"`,
    async (ctx) => {
      const repo = ctx.repo("api");
      let sessionClasses: string[] = [];
      const outcome = await runProjectReconciliationFlow(
        baseDeps(ctx, {
          interaction: fakeInteraction(["", repo], [false]),
          git: {
            worktreeStatus: () => ({ kind: "clean" }),
            changedPaths: () => ({ kind: "ok", paths: ["init_progress_definition.yaml"] }),
            commitOwnedPaths: () => ({ kind: "committed" })
          },
          runReconciliationSession: async (classes) => {
            sessionClasses = classes;
            return { ok: true, diagnostics: [] };
          }
        })
      );

      assert.equal(outcome.kind, "stoppedByOperator");
      assert.deepEqual(sessionClasses, ["backend"]);
      const meta = readProjectDefinitionMetadata(ctx.definitionPath);
      assert.equal(meta.classRepoPaths.backend!.state, "ready");
      assert.equal(meta.classRepoPaths.backend!.policy, "B");
      assert.equal(meta.classRepoPaths.backend!.path, realpathSync(repo));
    }
  );
});

test("exactly one retry after an invalid policy, then the class stays unchanged", async () => {
  await withProject(
    `    backend:
      state: "deferred"
      path: ""
      policy: "B"
    frontend:
      state: "ready"
      path: "/y"
      policy: "C"
      contract_reconciled: true`,
    async (ctx) => {
      let inputCount = 0;
      const emitted: string[] = [];
      const errors: string[] = [];
      const before = readFileSync(ctx.definitionPath, "utf8");
      const interaction: InteractionPort = {
        async input() {
          inputCount += 1;
          return inputCount === 1 ? "X" : "Y";
        },
        async confirm() {
          return false;
        },
        async select() {
          throw new Error("no");
        }
      };
      const outcome = await runProjectReconciliationFlow(
        baseDeps(ctx, {
          interaction,
          git: passThroughGit(),
          runReconciliationSession: async () => {
            throw new Error("session should not run when nothing pending");
          },
          emit: (line) => emitted.push(line),
          emitError: (line) => errors.push(line)
        })
      );
      assert.equal(inputCount, 2);
      assert.equal(outcome.kind, "noPendingWork");
      assert.equal(readFileSync(ctx.definitionPath, "utf8"), before);
      assert.ok(emitted.some((line) => line.includes("one attempt remaining")));
      assert.ok(emitted.some((line) => line.includes("unchanged policy")));
      assert.equal(errors.length, 2);
    }
  );
});

test("selected policy is recorded when input closes before a repo path", async () => {
  await withProject(
    `    backend:
      state: "deferred"
      path: ""
      policy: "B"
    frontend:
      state: "ready"
      path: "/y"
      policy: "C"
      contract_reconciled: true`,
    async (ctx) => {
      const outcome = await runProjectReconciliationFlow(
        baseDeps(ctx, {
          interaction: fakeInteraction(["C", null], []),
          git: passThroughGit(),
          runReconciliationSession: async () => {
            throw new Error("session should not run when no class is ready");
          }
        })
      );
      assert.equal(outcome.kind, "noPendingWork");
      const meta = readProjectDefinitionMetadata(ctx.definitionPath);
      assert.equal(meta.classRepoPaths.backend!.state, "deferred");
      assert.equal(meta.classRepoPaths.backend!.path, "");
      assert.equal(meta.classRepoPaths.backend!.policy, "C");
    }
  );
});

test("policy A deferred class can stay unchanged during reconciliation", async () => {
  await withProject(
    `    backend:
      state: "deferred"
      path: ""
      policy: "A"
    frontend:
      state: "ready"
      path: "/y"
      policy: "C"
      contract_reconciled: true`,
    async (ctx) => {
      let inputCount = 0;
      const outcome = await runProjectReconciliationFlow(
        baseDeps(ctx, {
          interaction: {
            async input() {
              inputCount += 1;
              return "";
            },
            async confirm() {
              return false;
            },
            async select() {
              throw new Error("no");
            }
          },
          git: passThroughGit(),
          runReconciliationSession: async () => {
            throw new Error("session should not run when no class is ready-unreconciled");
          }
        })
      );
      assert.equal(outcome.kind, "noPendingWork");
      assert.equal(inputCount, 1);
      const meta = readProjectDefinitionMetadata(ctx.definitionPath);
      assert.equal(meta.classRepoPaths.backend!.state, "deferred");
      assert.equal(meta.classRepoPaths.backend!.path, "");
      assert.equal(meta.classRepoPaths.backend!.policy, "A");
    }
  );
});

test("blank at policy prompt leaves the class record unchanged and prompts again on later runs", async () => {
  await withProject(
    `    backend:
      state: "deferred"
      path: ""
      policy: "B"`,
    async (ctx) => {
      const before = readFileSync(ctx.definitionPath, "utf8");
      const first = await runProjectReconciliationFlow(
        baseDeps(ctx, {
          interaction: fakeInteraction([""], []),
          git: passThroughGit(),
          runReconciliationSession: async () => {
            throw new Error("session should not run");
          }
        })
      );
      assert.equal(first.kind, "noPendingWork");
      assert.equal(readFileSync(ctx.definitionPath, "utf8"), before);

      const second = await runProjectReconciliationFlow(
        baseDeps(ctx, {
          interaction: fakeInteraction(["A"], []),
          git: passThroughGit(),
          runReconciliationSession: async () => {
            throw new Error("session should not run");
          }
        })
      );
      assert.equal(second.kind, "noPendingWork");
      assert.equal(
        readProjectDefinitionMetadata(ctx.definitionPath).classRepoPaths.backend!.policy,
        "A"
      );
    }
  );
});

test("existing ready-unreconciled class joins the batch and successful session sets all flags", async () => {
  await withProject(
    `    backend:
      state: "deferred"
      path: ""
      policy: "B"
    frontend:
      state: "ready"
      path: "__FRONTEND__"
      policy: "C"`,
    async (ctx) => {
      const frontendRepo = ctx.repo("web");
      // Patch the placeholder path with a real git repo.
      writeFileSync(
        ctx.definitionPath,
        readFileSync(ctx.definitionPath, "utf8").replace("__FRONTEND__", frontendRepo)
      );
      const backendRepo = ctx.repo("api");
      let sessionClasses: string[] = [];
      const outcome = await runProjectReconciliationFlow(
        baseDeps(ctx, {
          interaction: fakeInteraction(["B", backendRepo], [true]),
          git: {
            worktreeStatus: () => ({ kind: "clean" }),
            changedPaths: () => ({ kind: "ok", paths: ["init_progress_definition.yaml"] }),
            commitOwnedPaths: () => ({ kind: "committed" })
          },
          runReconciliationSession: async (classes) => {
            sessionClasses = classes;
            return { ok: true, diagnostics: [] };
          }
        })
      );
      assert.equal(outcome.kind, "completed");
      assert.deepEqual(sessionClasses.sort(), ["backend", "frontend"]);
      const meta = readProjectDefinitionMetadata(ctx.definitionPath);
      assert.equal(meta.classRepoPaths.backend!.policy, "B");
      assert.equal(meta.classRepoPaths.backend!.contractReconciled, true);
      assert.equal(meta.classRepoPaths.frontend!.contractReconciled, true);
    }
  );
});

test("failed session sets no flags and rolls back contract edits", async () => {
  await withProject(
    `    backend:
      state: "ready"
      path: "__BACKEND__"
      policy: "C"`,
    async (ctx) => {
      const repo = ctx.repo("api");
      writeFileSync(
        ctx.definitionPath,
        readFileSync(ctx.definitionPath, "utf8").replace("__BACKEND__", repo)
      );
      const contractPath = path.join(ctx.projectDir, "common_contract_definition.md");
      const baselineContract = readFileSync(contractPath, "utf8");
      const outcome = await runProjectReconciliationFlow(
        baseDeps(ctx, {
          interaction: fakeInteraction([], []),
          git: {
            worktreeStatus: () => ({ kind: "clean" }),
            changedPaths: () => ({ kind: "ok", paths: [] }),
            commitOwnedPaths: () => ({ kind: "committed" })
          },
          runReconciliationSession: async () => {
            // Simulate a partial model edit that must be rolled back.
            writeFileSync(contractPath, "# tampered\n");
            return {
              ok: false,
              diagnostics: [{ severity: "error", source: "agent", reason: "boom" }]
            };
          }
        })
      );
      assert.equal(outcome.kind, "failed");
      const meta = readProjectDefinitionMetadata(ctx.definitionPath);
      assert.notEqual(meta.classRepoPaths.backend!.contractReconciled, true);
      assert.equal(readFileSync(contractPath, "utf8"), baselineContract);
    }
  );
});

test("failed session reports stray paths before scoped rollback", async () => {
  await withProject(
    `    backend:
      state: "ready"
      path: "__BACKEND__"
      policy: "C"`,
    async (ctx) => {
      const repo = ctx.repo("api");
      writeFileSync(
        ctx.definitionPath,
        readFileSync(ctx.definitionPath, "utf8").replace("__BACKEND__", repo)
      );
      const contractPath = path.join(ctx.projectDir, "common_contract_definition.md");
      const baselineContract = readFileSync(contractPath, "utf8");
      const strayPath = path.join(ctx.projectDir, "stray.txt");
      const reported: string[] = [];

      const outcome = await runProjectReconciliationFlow({
        projectRoot: ctx.projectDir,
        projectPathRel: "projects/p1",
        interaction: fakeInteraction([], []),
        git: {
          worktreeStatus: () => ({ kind: "clean" }),
          changedPaths: () => ({
            kind: "ok",
            paths: ["common_contract_definition.md", "stray.txt"]
          }),
          commitOwnedPaths: () => ({ kind: "committed" })
        },
        runReconciliationSession: async () => {
          writeFileSync(contractPath, "# tampered\n");
          writeFileSync(strayPath, "stray\n");
          return {
            ok: false,
            diagnostics: [{ severity: "error", source: "agent", reason: "boom" }]
          };
        },
        emit: () => {},
        emitError: (line) => reported.push(line)
      });

      assert.equal(outcome.kind, "failed");
      // Stray path named this run (not just left for the next run's dirty check).
      assert.ok(reported.some((line) => line.includes("stray.txt")));
      if (outcome.kind === "failed") {
        assert.ok(outcome.diagnostics.some((d) => d.reason.includes("stray.txt")));
        assert.ok(outcome.diagnostics.some((d) => d.reason.includes("boom")));
      }
      // Owned contract rolled back; stray file left untouched for inspection.
      assert.equal(readFileSync(contractPath, "utf8"), baselineContract);
      assert.equal(readFileSync(strayPath, "utf8"), "stray\n");
      const meta = readProjectDefinitionMetadata(ctx.definitionPath);
      assert.notEqual(meta.classRepoPaths.backend!.contractReconciled, true);
    }
  );
});
