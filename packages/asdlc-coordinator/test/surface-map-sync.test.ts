import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import { syncSurfaceMapStep } from "../src/sync/surface-map.js";

function git(args: string[], cwd: string): void {
  const result = spawnSync("git", args, { cwd, encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
}

function createRepo(root: string): string {
  const repo = path.join(root, "repo");
  const remote = path.join(root, "remote.git");
  mkdirSync(repo, { recursive: true });
  git(["init", "--bare", "-q", remote], root);
  git(["init", "-q"], repo);
  git(["checkout", "-q", "-b", "main"], repo);
  git(["config", "user.name", "Test"], repo);
  git(["config", "user.email", "test@example.com"], repo);
  git(["remote", "add", "origin", remote], repo);
  writeFileSync(path.join(repo, "README.md"), "repo\n");
  git(["add", "README.md"], repo);
  git(["commit", "-qm", "seed"], repo);
  git(["push", "-q", "-u", "origin", "main"], repo);
  git(["symbolic-ref", "HEAD", "refs/heads/main"], remote);
  return repo;
}

function seed(root: string, repo?: string): void {
  const project = path.join(root, "projects", "p1");
  mkdirSync(path.join(project, "feature-a"), { recursive: true });
  writeFileSync(
    path.join(project, "init_progress_definition.yaml"),
    `meta_info:\n  project_classes: [backend]\n  project_type_code: A\n  class_repo_paths:${repo ? `\n    backend:\n      state: ready\n      path: "${repo}"` : " {}"}\nsteps: []\n`
  );
}

test("sync surface-map: ready class repo synced", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-surface-sync-"));
  try {
    const repo = createRepo(root);
    seed(root, repo);
    const result = syncSurfaceMapStep("projects/p1/feature-a", "backend", root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    assert.equal(result.syncedCount, 1);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("sync surface-map: unsyncable (dirty) ready repo blocks", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-surface-sync-blocked-"));
  try {
    const repo = createRepo(root);
    seed(root, repo);
    writeFileSync(path.join(repo, "dirty.txt"), "dirty\n");
    const result = syncSurfaceMapStep("projects/p1/feature-a", "backend", root);
    assert.equal(result.exitCode, 2);
    assert.match(result.blockedMessages?.[0] ?? "", /^BLOCKED:/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("sync surface-map: feature path symlinked outside the workspace is rejected", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-surface-sync-escape-"));
  const outside = mkdtempSync(path.join(tmpdir(), "overmind-surface-sync-outside-"));
  try {
    mkdirSync(path.join(root, "projects", "p1"), { recursive: true });
    symlinkSync(outside, path.join(root, "projects", "p1", "feature-a"));
    const result = syncSurfaceMapStep("projects/p1/feature-a", "backend", root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /must resolve inside ASDLC workspace/);
  } finally {
    rmSync(root, { recursive: true, force: true });
    rmSync(outside, { recursive: true, force: true });
  }
});

test("sync surface-map: blueprint-fallback class is a no-op", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-surface-sync-noop-"));
  try {
    seed(root);
    const result = syncSurfaceMapStep("projects/p1/feature-a", "frontend", root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    assert.equal(result.syncedCount, 0);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
