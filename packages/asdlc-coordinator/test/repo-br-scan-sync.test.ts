import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import { syncRepoBrScanStep } from "../src/sync/repo-br-scan.js";

function withWorkspace(fn: (root: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-repo-br-scan-sync-"));
  try {
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function git(args: string[], cwd: string): void {
  const result = spawnSync("git", args, { cwd, encoding: "utf8" });
  if ((result.status ?? 1) !== 0) {
    throw new Error(`git ${args.join(" ")} failed: ${result.stderr}`);
  }
}

function createSyncedGitRepo(
  tmpDir: string,
  name: string
): { localPath: string; remotePath: string } {
  const localPath = path.join(tmpDir, "repos", name);
  const remotePath = path.join(tmpDir, "remotes", `${name}.git`);
  mkdirSync(localPath, { recursive: true });
  mkdirSync(path.dirname(remotePath), { recursive: true });
  spawnSync("git", ["init", "--bare", "-q", remotePath], { encoding: "utf8" });
  git(["init", "-q"], localPath);
  git(["checkout", "-q", "-b", "main"], localPath);
  git(["config", "user.name", "Test User"], localPath);
  git(["config", "user.email", "test@example.com"], localPath);
  git(["remote", "add", "origin", remotePath], localPath);
  writeFileSync(path.join(localPath, "README.md"), `${name}\n`);
  git(["add", "README.md"], localPath);
  git(["commit", "-qm", `seed ${name}`], localPath);
  git(["push", "-q", "-u", "origin", "main"], localPath);
  spawnSync("git", ["--git-dir", remotePath, "symbolic-ref", "HEAD", "refs/heads/main"], {
    encoding: "utf8"
  });
  return { localPath, remotePath };
}

function pushUpstreamChange(tmpDir: string, name: string, content: string): void {
  const remotePath = path.join(tmpDir, "remotes", `${name}.git`);
  const workRepo = path.join(tmpDir, `upstream-work-${name}`);
  spawnSync("git", ["clone", "-q", remotePath, workRepo], { encoding: "utf8" });
  git(["config", "user.name", "Test User"], workRepo);
  git(["config", "user.email", "test@example.com"], workRepo);
  writeFileSync(path.join(workRepo, "README.md"), `${content}\n`);
  git(["add", "README.md"], workRepo);
  git(["commit", "-qm", "upstream update"], workRepo);
  git(["push", "-q", "origin", "main"], workRepo);
}

function writeDefinition(
  root: string,
  featureDir: string,
  repos: Array<{ name: string; state: string; path: string }>
): void {
  const lines = ["meta_info:", "  class_repo_paths:"];
  for (const r of repos) {
    lines.push(`    ${r.name}:`);
    lines.push(`      state: "${r.state}"`);
    lines.push(`      path: "${r.path}"`);
  }
  lines.push("steps: []");
  writeFileSync(path.join(featureDir, "init_progress_definition.yaml"), lines.join("\n") + "\n");
}

function makeFeatureDir(root: string): string {
  const dir = path.join(root, "projects", "p1", "feature-a");
  mkdirSync(dir, { recursive: true });
  writeFileSync(
    path.join(dir, "feature_br_summary.md"),
    "# Feature Business Requirements Summary\n"
  );
  return dir;
}

function assertNoRebaseState(repoPath: string): void {
  const r = spawnSync("git", ["rev-parse", "--git-dir"], { cwd: repoPath, encoding: "utf8" });
  if ((r.status ?? 1) !== 0) {
    return;
  }
  let gitDir = r.stdout.trim();
  if (!path.isAbsolute(gitDir)) {
    gitDir = path.join(repoPath, gitDir);
  }
  assert.ok(
    !existsSync(path.join(gitDir, "rebase-merge")) && !existsSync(path.join(gitDir, "rebase-apply")),
    "Expected no rebase state after abort"
  );
}

// ── Sync step tests ─────────────────────────────────────────────────────────

test("repo-br-scan sync succeeds and pulls upstream change", () => {
  withWorkspace((root) => {
    const { localPath } = createSyncedGitRepo(root, "backend");
    pushUpstreamChange(root, "backend", "upstream synchronized content");
    const featureDir = makeFeatureDir(root);
    writeDefinition(root, featureDir, [{ name: "backend", state: "ready", path: localPath }]);
    const result = syncRepoBrScanStep(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 0);
    assert.equal(result.syncedCount, 1);
  });
});

test("repo-br-scan sync no-ops when no ready repos", () => {
  withWorkspace((root) => {
    const featureDir = makeFeatureDir(root);
    writeDefinition(root, featureDir, [{ name: "backend", state: "deferred", path: "" }]);
    const result = syncRepoBrScanStep(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 0);
    assert.equal(result.syncedCount, 0);
  });
});

test("repo-br-scan sync blocks and aborts rebase on pull --rebase failure (D7)", () => {
  withWorkspace((root) => {
    const { localPath } = createSyncedGitRepo(root, "backend");
    writeFileSync(path.join(localPath, "README.md"), "local divergent\n");
    git(["add", "README.md"], localPath);
    git(["commit", "-qm", "local divergent update"], localPath);
    pushUpstreamChange(root, "backend", "upstream divergent content");
    const featureDir = makeFeatureDir(root);
    writeDefinition(root, featureDir, [{ name: "backend", state: "ready", path: localPath }]);
    const result = syncRepoBrScanStep(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 2);
    assert.ok(result.blockedMessages && result.blockedMessages.length > 0);
    assert.match(result.blockedMessages![0], /BLOCKED:.*could not sync.*D7/);
    assertNoRebaseState(localPath);
  });
});

test("repo-br-scan sync blocks and aborts rebase for linked worktree (D7)", () => {
  withWorkspace((root) => {
    const { localPath } = createSyncedGitRepo(root, "backend");
    git(["checkout", "-q", "-b", "holder"], localPath);
    const linkedPath = path.join(root, "backend-linked-worktree");
    spawnSync("git", ["worktree", "add", "-q", linkedPath, "main"], {
      cwd: localPath,
      encoding: "utf8"
    });
    writeFileSync(path.join(linkedPath, "README.md"), "local linked worktree divergent\n");
    git(["add", "README.md"], linkedPath);
    git(["commit", "-qm", "local linked worktree divergent"], linkedPath);
    pushUpstreamChange(root, "backend", "upstream linked worktree divergent");
    const featureDir = makeFeatureDir(root);
    writeDefinition(root, featureDir, [{ name: "backend", state: "ready", path: linkedPath }]);
    const result = syncRepoBrScanStep(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 2);
    assert.ok(result.blockedMessages && result.blockedMessages.length > 0);
    assert.match(result.blockedMessages![0], /BLOCKED:.*could not sync.*D7/);
    assertNoRebaseState(linkedPath);
  });
});
