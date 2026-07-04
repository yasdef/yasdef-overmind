import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import { syncContractDeltaStep } from "../src/sync/contract-delta.js";

function git(args: string[], cwd: string): void {
  const result = spawnSync("git", args, { cwd, encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
}

function fixture(root: string, ready: boolean): { feature: string; repo: string; remote: string } {
  const repo = path.join(root, "repo");
  const remote = path.join(root, "remote.git");
  mkdirSync(repo, { recursive: true });
  git(["init", "--bare", "-q", remote], root);
  git(["init", "-q"], repo);
  git(["checkout", "-q", "-b", "main"], repo);
  git(["config", "user.name", "Test"], repo);
  git(["config", "user.email", "test@example.com"], repo);
  git(["remote", "add", "origin", remote], repo);
  writeFileSync(path.join(repo, "README.md"), "seed\n");
  git(["add", "README.md"], repo);
  git(["commit", "-qm", "seed"], repo);
  git(["push", "-q", "-u", "origin", "main"], repo);
  git(["symbolic-ref", "HEAD", "refs/heads/main"], remote);
  const project = path.join(root, "projects", "p1");
  const feature = path.join(project, "feature-a");
  mkdirSync(feature, { recursive: true });
  writeFileSync(
    path.join(project, "init_progress_definition.yaml"),
    `meta_info:\n  class_repo_paths:\n    backend:\n      state: ${ready ? "ready" : "deferred"}\n      path: "${ready ? repo : ""}"\nsteps: []\n`
  );
  return { feature, repo, remote };
}

test("contract-delta sync pulls ready repos and no-ops without ready repos", () => {
  for (const ready of [true, false]) {
    const root = mkdtempSync(path.join(tmpdir(), "overmind-contract-sync-"));
    try {
      const { feature, repo, remote } = fixture(root, ready);
      if (ready) {
        const upstream = path.join(root, "upstream");
        git(["clone", "-q", remote, upstream], root);
        git(["config", "user.name", "Test"], upstream);
        git(["config", "user.email", "test@example.com"], upstream);
        writeFileSync(path.join(upstream, "README.md"), "upstream\n");
        git(["add", "README.md"], upstream);
        git(["commit", "-qm", "update"], upstream);
        git(["push", "-q", "origin", "main"], upstream);
      }
      const result = syncContractDeltaStep(path.relative(root, feature), root);
      assert.equal(result.exitCode, 0);
      assert.equal(result.syncedCount, ready ? 1 : 0);
      if (ready) assert.equal(readFileSync(path.join(repo, "README.md"), "utf8"), "upstream\n");
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  }
});

test("contract-delta sync blocks dirty repos and reports missing definition", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-contract-sync-block-"));
  try {
    const { feature, repo } = fixture(root, true);
    writeFileSync(path.join(repo, "dirty.txt"), "dirty\n");
    const blocked = syncContractDeltaStep(path.relative(root, feature), root);
    assert.equal(blocked.exitCode, 2);
    assert.match(blocked.blockedMessages?.[0] ?? "", /^BLOCKED:/);
    rmSync(path.join(root, "projects", "p1", "init_progress_definition.yaml"));
    const missing = syncContractDeltaStep(path.relative(root, feature), root);
    assert.equal(missing.exitCode, 2);
    assert.match(missing.errorMessage ?? "", /init_progress_definition.yaml/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
