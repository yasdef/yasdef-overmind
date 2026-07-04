import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { RepoGitProjectAdapter } from "../src/git/index.js";
import type { GitRunner, ProjectGitPort } from "../src/git/index.js";
import { runProjectReconciliationFlow } from "../src/orchestrator/run-project-reconciliation-flow.js";
import type { ProjectReconciliationDeps } from "../src/orchestrator/run-project-reconciliation-flow.js";
import { readProjectDefinitionMetadata } from "../src/parse/project-definition.js";
import { InteractionClosedError, type InteractionPort } from "../src/interaction/index.js";

function git(root: string, args: string[]): void {
  execFileSync("git", ["-C", root, ...args], { stdio: "ignore" });
}

function makeGitProject(): { root: string; projectDir: string; definitionPath: string } {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-reconcile-tx-"));
  const projectDir = path.join(root, "projects", "p1");
  mkdirSync(projectDir, { recursive: true });
  const repo = path.join(root, "repos", "api");
  mkdirSync(repo, { recursive: true });
  git(repo, ["init", "-q"]);
  const definitionPath = path.join(projectDir, "init_progress_definition.yaml");
  writeFileSync(
    definitionPath,
    `meta_info:
  project_type_code: A
  project_classes: [backend]
  class_repo_paths:
    backend:
      state: "ready"
      path: "${repo}"
      policy: "C"
steps:
  - id: "1"
`
  );
  writeFileSync(path.join(projectDir, "common_contract_definition.md"), "# Common contract\n");
  return { root, projectDir, definitionPath };
}

function silentInteraction(confirm: boolean | "closed" = true): InteractionPort {
  return {
    async input() {
      throw new InteractionClosedError();
    },
    async confirm() {
      if (confirm === "closed") throw new InteractionClosedError();
      return confirm;
    },
    async select() {
      throw new Error("no");
    }
  };
}

function deps(
  projectDir: string,
  gitPort: ProjectGitPort,
  overrides: Partial<ProjectReconciliationDeps>
): ProjectReconciliationDeps {
  return {
    projectRoot: projectDir,
    projectPathRel: "projects/p1",
    interaction: overrides.interaction ?? silentInteraction(true),
    git: gitPort,
    runReconciliationSession:
      overrides.runReconciliationSession ?? (async () => ({ ok: true, diagnostics: [] })),
    emit: () => {},
    emitError: overrides.emitError ?? (() => {})
  };
}

test("RepoGitProjectAdapter reports clean/dirty/notWorktree and commits owned paths", () => {
  const { root, projectDir, definitionPath } = makeGitProject();
  try {
    const adapter = new RepoGitProjectAdapter();
    // The workspace root itself isn't a git repo yet.
    assert.equal(adapter.worktreeStatus(projectDir).kind, "notWorktree");

    // Make projects/p1 a git worktree.
    git(projectDir, ["init", "-q"]);
    git(projectDir, ["add", "-A"]);
    execFileSync("git", [
      "-C",
      projectDir,
      "-c",
      "user.email=a@b.c",
      "-c",
      "user.name=t",
      "commit",
      "-q",
      "-m",
      "init"
    ]);
    assert.equal(adapter.worktreeStatus(projectDir).kind, "clean");

    // Change owned files plus an unexpected one.
    writeFileSync(definitionPath, `${readFileSync(definitionPath, "utf8")}# edit\n`);
    writeFileSync(path.join(projectDir, "common_contract_definition.md"), "# reconciled\n");
    writeFileSync(path.join(projectDir, "stray.txt"), "unexpected\n");

    const dirty = adapter.worktreeStatus(projectDir);
    assert.equal(dirty.kind, "dirty");

    const changed = adapter.changedPaths(projectDir);
    assert.equal(changed.kind, "ok");
    if (changed.kind === "ok") {
      assert.ok(changed.paths.includes("stray.txt"));
    }

    // With only the two owned paths changed, committing them yields a clean worktree.
    rmSync(path.join(projectDir, "stray.txt"), { force: true });
    git(projectDir, ["config", "user.email", "a@b.c"]);
    git(projectDir, ["config", "user.name", "t"]);
    const committed = adapter.commitOwnedPaths(
      projectDir,
      ["init_progress_definition.yaml", "common_contract_definition.md"],
      "Reconcile contract and attach repos"
    );
    assert.equal(committed.kind, "committed");
    assert.equal(adapter.worktreeStatus(projectDir).kind, "clean");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("dirty project refuses before any mutation", async () => {
  const { root, projectDir, definitionPath } = makeGitProject();
  try {
    // Make backend deferred so there is pending work.
    writeFileSync(
      definitionPath,
      readFileSync(definitionPath, "utf8").replace(
        /state: "ready"[\s\S]*?policy: "C"/,
        'state: "deferred"'
      )
    );
    let sessionRan = false;
    const outcome = await runProjectReconciliationFlow(
      deps(
        projectDir,
        {
          worktreeStatus: () => ({ kind: "dirty", paths: ["common_contract_definition.md"] }),
          changedPaths: () => ({ kind: "ok", paths: [] }),
          commitOwnedPaths: () => ({ kind: "committed" })
        },
        {
          interaction: silentInteraction(true),
          runReconciliationSession: async () => {
            sessionRan = true;
            return { ok: true, diagnostics: [] };
          }
        }
      )
    );
    assert.equal(outcome.kind, "startupError");
    assert.equal(sessionRan, false);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("unexpected changed path triggers scoped rollback and no commit", async () => {
  const { root, projectDir, definitionPath } = makeGitProject();
  try {
    const contractPath = path.join(projectDir, "common_contract_definition.md");
    const baselineContract = readFileSync(contractPath, "utf8");
    let commitCalls = 0;
    const reported: string[] = [];
    const outcome = await runProjectReconciliationFlow(
      deps(
        projectDir,
        {
          worktreeStatus: () => ({ kind: "clean" }),
          changedPaths: () => ({
            kind: "ok",
            paths: ["init_progress_definition.yaml", "common_contract_definition.md", "stray.txt"]
          }),
          commitOwnedPaths: () => {
            commitCalls += 1;
            return { kind: "committed" };
          }
        },
        {
          emitError: (line) => reported.push(line),
          runReconciliationSession: async () => {
            writeFileSync(contractPath, "# model edit\n");
            return { ok: true, diagnostics: [] };
          }
        }
      )
    );
    assert.equal(outcome.kind, "failed");
    assert.equal(commitCalls, 0);
    assert.ok(reported.some((line) => line.includes("stray.txt")));
    // Contract edit and flags rolled back to baseline.
    assert.equal(readFileSync(contractPath, "utf8"), baselineContract);
    assert.notEqual(
      readProjectDefinitionMetadata(definitionPath).classRepoPaths.backend!.contractReconciled,
      true
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("declined commit leaves owned changes uncommitted and stops", async () => {
  const { root, projectDir } = makeGitProject();
  try {
    let commitCalls = 0;
    const outcome = await runProjectReconciliationFlow(
      deps(
        projectDir,
        {
          worktreeStatus: () => ({ kind: "clean" }),
          changedPaths: () => ({ kind: "ok", paths: ["init_progress_definition.yaml"] }),
          commitOwnedPaths: () => {
            commitCalls += 1;
            return { kind: "committed" };
          }
        },
        { interaction: silentInteraction(false) }
      )
    );
    assert.equal(outcome.kind, "stoppedByOperator");
    assert.equal(commitCalls, 0);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("commit failure surfaces exit code, git stderr, and project root", async () => {
  const { root, projectDir } = makeGitProject();
  try {
    const outcome = await runProjectReconciliationFlow(
      deps(
        projectDir,
        {
          worktreeStatus: () => ({ kind: "clean" }),
          changedPaths: () => ({ kind: "ok", paths: ["init_progress_definition.yaml"] }),
          commitOwnedPaths: () => ({
            kind: "commitFailed",
            exitCode: 128,
            stderr:
              "Author identity unknown\n*** Please tell me who you are.\nfatal: unable to auto-detect email address"
          })
        },
        { interaction: silentInteraction(true) }
      )
    );
    assert.equal(outcome.kind, "failed");
    if (outcome.kind === "failed") {
      const reason = outcome.diagnostics.map((d) => d.reason).join("\n");
      assert.match(reason, /git commit exited 128/);
      assert.match(reason, /Please tell me who you are/);
      assert.ok(reason.includes(projectDir), "diagnostic should name the project root");
    }
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("confirmed commit stages exactly the two owned paths", async () => {
  const { root, projectDir } = makeGitProject();
  try {
    let committedPaths: string[] = [];
    let committedMessage = "";
    const outcome = await runProjectReconciliationFlow(
      deps(
        projectDir,
        {
          worktreeStatus: () => ({ kind: "clean" }),
          changedPaths: () => ({ kind: "ok", paths: ["init_progress_definition.yaml"] }),
          commitOwnedPaths: (_root, paths, message) => {
            committedPaths = paths;
            committedMessage = message;
            return { kind: "committed" };
          }
        },
        { interaction: silentInteraction(true) }
      )
    );
    assert.equal(outcome.kind, "completed");
    if (outcome.kind === "completed") assert.equal(outcome.committed, true);
    assert.deepEqual(committedPaths, [
      "init_progress_definition.yaml",
      "common_contract_definition.md"
    ]);
    assert.equal(committedMessage, "Reconcile contract and attach repos");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("adapter classifies a confirmed non-repository probe as notWorktree (pass-through)", () => {
  const runner: GitRunner = (_root, args) => {
    if (args[0] === "--version") return { status: 0, stdout: "git version", stderr: "" };
    if (args[0] === "rev-parse") {
      return {
        status: 128,
        stdout: "",
        stderr: "fatal: not a git repository (or any of the parent directories): .git"
      };
    }
    return { status: 0, stdout: "", stderr: "" };
  };
  const adapter = new RepoGitProjectAdapter(runner);
  assert.equal(adapter.worktreeStatus("/plain").kind, "notWorktree");
  assert.equal(adapter.changedPaths("/plain").kind, "notWorktree");
  assert.equal(adapter.commitOwnedPaths("/plain", ["a"], "m").kind, "notWorktree");
});

test("adapter classifies a corrupt-repo probe as inspectionFailed, not notWorktree", () => {
  const runner: GitRunner = (_root, args) => {
    if (args[0] === "--version") return { status: 0, stdout: "git version", stderr: "" };
    if (args[0] === "rev-parse") {
      return { status: 128, stdout: "", stderr: "fatal: bad config line 1 in file .git/config" };
    }
    return { status: 0, stdout: "", stderr: "" };
  };
  const adapter = new RepoGitProjectAdapter(runner);
  const status = adapter.worktreeStatus("/corrupt");
  assert.equal(status.kind, "inspectionFailed");
  if (status.kind === "inspectionFailed") {
    assert.equal(status.exitCode, 128);
    assert.match(status.stderr, /bad config line/);
  }
  assert.equal(adapter.changedPaths("/corrupt").kind, "inspectionFailed");
  assert.equal(adapter.commitOwnedPaths("/corrupt", ["a"], "m").kind, "inspectionFailed");
});

test("adapter reports inspectionFailed when git status fails on an identified worktree", () => {
  const runner: GitRunner = (_root, args) => {
    if (args[0] === "--version") return { status: 0, stdout: "git version", stderr: "" };
    if (args[0] === "rev-parse") return { status: 0, stdout: "true", stderr: "" };
    if (args[0] === "status") return { status: 128, stdout: "", stderr: "fatal: bad index" };
    return { status: 0, stdout: "", stderr: "" };
  };
  const adapter = new RepoGitProjectAdapter(runner);
  const status = adapter.worktreeStatus("/anywhere");
  assert.equal(status.kind, "inspectionFailed");
  if (status.kind === "inspectionFailed") {
    assert.equal(status.exitCode, 128);
    assert.match(status.stderr, /bad index/);
  }
  assert.equal(adapter.changedPaths("/anywhere").kind, "inspectionFailed");
});

test("commitOwnedPaths carries git exit code and stderr on failure", () => {
  const runner: GitRunner = (_root, args) => {
    if (args[0] === "--version") return { status: 0, stdout: "git version", stderr: "" };
    if (args[0] === "rev-parse") return { status: 0, stdout: "true", stderr: "" };
    if (args[0] === "add") return { status: 0, stdout: "", stderr: "" };
    if (args[0] === "commit") {
      return { status: 128, stdout: "", stderr: "fatal: unable to auto-detect email address" };
    }
    return { status: 0, stdout: "", stderr: "" };
  };
  const result = new RepoGitProjectAdapter(runner).commitOwnedPaths("/r", ["a"], "m");
  assert.equal(result.kind, "commitFailed");
  if (result.kind === "commitFailed") {
    assert.equal(result.exitCode, 128);
    assert.match(result.stderr, /auto-detect email/);
  }
});

function inspectionFailedGit(where: "baseline" | "postSession"): ProjectGitPort {
  return {
    worktreeStatus: () =>
      where === "baseline"
        ? { kind: "inspectionFailed", exitCode: 128, stderr: "fatal: bad index" }
        : { kind: "clean" },
    changedPaths: () =>
      where === "postSession"
        ? { kind: "inspectionFailed", exitCode: 128, stderr: "fatal: bad index" }
        : { kind: "ok", paths: [] },
    commitOwnedPaths: () => ({ kind: "committed" })
  };
}

for (const failKind of ["unavailable", "notWorktree", "inspectionFailed"] as const) {
  test(`post-session ${failKind} rolls back flags and fails without commit`, async () => {
    const { root, projectDir, definitionPath } = makeGitProject();
    try {
      const contractPath = path.join(projectDir, "common_contract_definition.md");
      const baselineContract = readFileSync(contractPath, "utf8");
      let commitCalls = 0;
      const outcome = await runProjectReconciliationFlow(
        deps(
          projectDir,
          {
            worktreeStatus: () => ({ kind: "clean" }),
            changedPaths: () =>
              failKind === "inspectionFailed"
                ? { kind: "inspectionFailed", exitCode: 128, stderr: "fatal" }
                : { kind: failKind },
            commitOwnedPaths: () => {
              commitCalls += 1;
              return { kind: "committed" };
            }
          },
          {
            interaction: silentInteraction(true),
            runReconciliationSession: async () => {
              writeFileSync(contractPath, "# model edit\n");
              return { ok: true, diagnostics: [] };
            }
          }
        )
      );
      assert.equal(outcome.kind, "failed");
      // Flags rolled back: a failed command must not leave contract_reconciled: true on disk.
      assert.notEqual(
        readProjectDefinitionMetadata(definitionPath).classRepoPaths.backend!.contractReconciled,
        true
      );
      assert.equal(readFileSync(contractPath, "utf8"), baselineContract);
      assert.equal(commitCalls, 0);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });
}

test("baseline inspection failure fails before any mutation", async () => {
  const { root, projectDir, definitionPath } = makeGitProject();
  try {
    // Deferred class => pending work so the flow reaches the baseline check.
    writeFileSync(
      definitionPath,
      readFileSync(definitionPath, "utf8").replace(
        /state: "ready"[\s\S]*?policy: "C"/,
        'state: "deferred"'
      )
    );
    let sessionRan = false;
    const outcome = await runProjectReconciliationFlow(
      deps(projectDir, inspectionFailedGit("baseline"), {
        interaction: silentInteraction(true),
        runReconciliationSession: async () => {
          sessionRan = true;
          return { ok: true, diagnostics: [] };
        }
      })
    );
    assert.equal(outcome.kind, "startupError");
    assert.equal(sessionRan, false);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
