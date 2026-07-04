import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
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
import type { ProjectGitPort, WorktreeStatus } from "../src/git/index.js";
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
    emit: () => {},
    emitError: () => {},
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

test("ordered prompts, blank defer, and all attaches precede one reconciliation session", async () => {
  await withProject(
    `    backend:
      state: "deferred"
    frontend:
      state: "deferred"
    mobile:
      state: "deferred"`,
    async (ctx) => {
      const backend = ctx.repo("api");
      const frontend = ctx.repo("web");
      // backend attaches, frontend blank-defers, mobile attaches.
      let sessionClasses: string[] = [];
      const outcome = await runProjectReconciliationFlow(
        baseDeps(ctx, {
          interaction: fakeInteraction([backend, "", ctx.repo("app")], [false]),
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
            assert.equal(meta.classRepoPaths.mobile!.state, "ready");
            assert.equal(meta.classRepoPaths.frontend!.state, "deferred");
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
          return "/not/a/repo"; // always invalid
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
      // Two attempts (initial + one retry), no third prompt.
      assert.equal(inputCount, 2);
      // backend stayed deferred, frontend already reconciled => no pending session.
      assert.equal(outcome.kind, "noPendingWork");
      const meta = readProjectDefinitionMetadata(ctx.definitionPath);
      assert.equal(meta.classRepoPaths.backend!.state, "deferred");
    }
  );
});

test("existing ready-unreconciled class joins the batch and successful session sets all flags", async () => {
  await withProject(
    `    backend:
      state: "deferred"
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
          interaction: fakeInteraction([backendRepo], [true]),
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
