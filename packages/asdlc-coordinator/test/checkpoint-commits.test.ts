import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import {
  CHECKPOINT_LABELS,
  RepoGitAdapter,
  renderCheckpointNotice,
  type GitRunner
} from "../src/git/index.js";

function withGitRepo(run: (root: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "checkpoint-"));
  try {
    execFileSync("git", ["-C", root, "init", "-q"]);
    execFileSync("git", ["-C", root, "config", "user.email", "t@example.com"]);
    execFileSync("git", ["-C", root, "config", "user.name", "Test"]);
    writeFileSync(path.join(root, "seed.txt"), "seed\n");
    execFileSync("git", ["-C", root, "add", "-A"]);
    execFileSync("git", ["-C", root, "commit", "-q", "-m", "seed"]);
    run(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test("a dirty explicit-root worktree is committed with the boundary label", () => {
  withGitRepo((root) => {
    writeFileSync(path.join(root, "change.txt"), "change\n");
    const result = new RepoGitAdapter().checkpoint(root, CHECKPOINT_LABELS.before51);
    assert.equal(result.kind, "committed");
    if (result.kind === "committed") {
      assert.equal(result.message, `Checkpoint: ${CHECKPOINT_LABELS.before51}`);
    }
    // Worktree is clean after committing.
    assert.equal(
      execFileSync("git", ["-C", root, "status", "--porcelain"], { encoding: "utf8" }).trim(),
      ""
    );
  });
});

test("a clean worktree yields a clean result and a skip notice", () => {
  withGitRepo((root) => {
    const result = new RepoGitAdapter().checkpoint(root, CHECKPOINT_LABELS.before71);
    assert.equal(result.kind, "clean");
    assert.match(renderCheckpointNotice(result, CHECKPOINT_LABELS.before71), /nothing to commit/);
  });
});

test("a non-worktree root is a typed skip, never a throw", () => {
  const root = mkdtempSync(path.join(tmpdir(), "checkpoint-nonrepo-"));
  try {
    const result = new RepoGitAdapter().checkpoint(root, "before step 8.4 (semantic review)");
    assert.equal(result.kind, "notWorktree");
    const notice = renderCheckpointNotice(result, "before step 8.4 (semantic review)");
    assert.match(notice, /repository root is not a git worktree/);
    assert.doesNotMatch(notice, /runtime root/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("missing git degrades to unavailable via the runner seam", () => {
  const runner: GitRunner = (_root, args) =>
    args[0] === "--version"
      ? { status: 127, stdout: "", stderr: "not found" }
      : { status: 0, stdout: "", stderr: "" };
  const result = new RepoGitAdapter(runner).checkpoint("/anywhere", "label");
  assert.equal(result.kind, "unavailable");
  assert.match(renderCheckpointNotice(result, "label"), /git not found/);
});

test("add and commit failures render notices without altering the outcome", () => {
  const addFail: GitRunner = (_root, args) => {
    if (args[0] === "--version") return { status: 0, stdout: "", stderr: "" };
    if (args[0] === "rev-parse") return { status: 0, stdout: "", stderr: "" };
    if (args[0] === "status") return { status: 0, stdout: " M x\n", stderr: "" };
    if (args[0] === "add") return { status: 1, stdout: "", stderr: "denied" };
    return { status: 0, stdout: "", stderr: "" };
  };
  const addResult = new RepoGitAdapter(addFail).checkpoint("/r", "label");
  assert.equal(addResult.kind, "addFailed");
  assert.match(renderCheckpointNotice(addResult, "label"), /git add exited 1/);

  const commitFail: GitRunner = (_root, args) => {
    if (args[0] === "--version") return { status: 0, stdout: "", stderr: "" };
    if (args[0] === "rev-parse") return { status: 0, stdout: "", stderr: "" };
    if (args[0] === "status") return { status: 0, stdout: " M x\n", stderr: "" };
    if (args[0] === "add") return { status: 0, stdout: "", stderr: "" };
    if (args[0] === "commit") return { status: 1, stdout: "", stderr: "hook" };
    return { status: 0, stdout: "", stderr: "" };
  };
  const commitResult = new RepoGitAdapter(commitFail).checkpoint("/r", "label");
  assert.equal(commitResult.kind, "commitFailed");
  assert.match(renderCheckpointNotice(commitResult, "label"), /git commit exited 1/);
});
