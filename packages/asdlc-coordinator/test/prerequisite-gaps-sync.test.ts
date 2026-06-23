import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import { collectReadyRepoPaths } from "../src/repo/collect-ready-paths.js";
import { syncPrerequisiteGapsStep } from "../src/sync/prerequisite-gaps.js";

function git(args: string[], cwd: string): void {
  const result = spawnSync("git", args, { cwd, encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
}

function repo(root: string, name: string): string {
  const local = path.join(root, name); const remote = path.join(root, `${name}.git`);
  mkdirSync(local); git(["init", "--bare", "-q", remote], root); git(["init", "-q"], local); git(["checkout", "-q", "-b", "main"], local);
  git(["config", "user.name", "Test"], local); git(["config", "user.email", "test@example.com"], local); git(["remote", "add", "origin", remote], local);
  writeFileSync(path.join(local, "README.md"), "seed\n"); git(["add", "."], local); git(["commit", "-qm", "seed"], local); git(["push", "-q", "-u", "origin", "main"], local); git(["symbolic-ref", "HEAD", "refs/heads/main"], remote);
  return local;
}

function definition(root: string, entries: Array<[string, string]>): string {
  const project = path.join(root, "projects", "p1"); mkdirSync(path.join(project, "f1"), { recursive: true });
  const file = path.join(project, "init_progress_definition.yaml");
  writeFileSync(file, `meta_info:\n  class_repo_paths:\n${entries.map(([klass, value]) => `    ${klass}:\n      state: ready\n      path: "${value}"`).join("\n")}\nsteps: []\n`);
  return file;
}

test("prerequisite-gaps sync syncs supported repos and filters infrastructure before path validation", () => {
  const root = mkdtempSync(path.join(tmpdir(), "prereq-sync-"));
  try {
    const backend = repo(root, "backend"); const frontend = repo(root, "frontend");
    const def = definition(root, [["backend", backend], ["frontend", frontend], ["infrastructure", path.join(root, "missing")]]);
    assert.deepEqual(collectReadyRepoPaths(def, ["BACKEND", "frontend"]).map((item) => item.class), ["backend", "frontend"]);
    assert.throws(() => collectReadyRepoPaths(def), /infrastructure/);
    const result = syncPrerequisiteGapsStep("projects/p1/f1", root);
    assert.equal(result.exitCode, 0, result.errorMessage); assert.equal(result.syncedCount, 2);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("prerequisite-gaps sync reports blocked supported repos and missing definition", () => {
  const root = mkdtempSync(path.join(tmpdir(), "prereq-sync-block-"));
  try {
    const backend = repo(root, "backend"); definition(root, [["backend", backend]]); writeFileSync(path.join(backend, "dirty"), "x");
    const blocked = syncPrerequisiteGapsStep("projects/p1/f1", root); assert.equal(blocked.exitCode, 2); assert.match(blocked.blockedMessages?.[0] ?? "", /BLOCKED:/);
    rmSync(path.join(root, "projects", "p1", "init_progress_definition.yaml"));
    assert.match(syncPrerequisiteGapsStep("projects/p1/f1", root).errorMessage ?? "", /init_progress_definition.yaml/);
  } finally { rmSync(root, { recursive: true, force: true }); }
});
