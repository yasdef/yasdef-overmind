import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import { buildRepoBrScanContext } from "../src/context/repo-br-scan.js";

const bundlePath = fileURLToPath(new URL("../overmind.js", import.meta.url));

function withWorkspace(fn: (root: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-repo-br-scan-context-"));
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
  git(["commit", "-qm", `upstream update`], workRepo);
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
    "# Feature Business Requirements Summary\n\n## 1. Document Meta\n- source_type: Repository scan\n- last_updated: 2026-04-06\n"
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
  const hasRebaseMerge = existsSync(path.join(gitDir, "rebase-merge"));
  const hasRebaseApply = existsSync(path.join(gitDir, "rebase-apply"));
  assert.equal(hasRebaseMerge || hasRebaseApply, false, "Expected rebase state to be aborted");
}

// ── Non-git basic tests ─────────────────────────────────────────────────────

test("repo-br-scan context exits 2 when feature path is not a directory", () => {
  withWorkspace((root) => {
    const result = buildRepoBrScanContext(path.join(root, "nonexistent"), root);
    assert.equal(result.exitCode, 2);
    assert.ok(result.errorMessage?.includes("Feature path directory not found:"));
  });
});

test("repo-br-scan context exits 2 when feature_br_summary.md is absent", () => {
  withWorkspace((root) => {
    const featureDir = path.join(root, "projects", "p1", "feature-a");
    mkdirSync(featureDir, { recursive: true });
    const result = buildRepoBrScanContext(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 2);
    assert.ok(result.errorMessage?.includes("Required file not found:"));
  });
});

test("repo-br-scan context exits 2 when init_progress_definition.yaml not found in ancestors", () => {
  withWorkspace((root) => {
    const featureDir = makeFeatureDir(root);
    const result = buildRepoBrScanContext(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 2);
    assert.ok(result.errorMessage?.includes("init_progress_definition.yaml"));
  });
});

test("repo-br-scan context emits no-op block when no repos are ready", () => {
  withWorkspace((root) => {
    const featureDir = makeFeatureDir(root);
    writeDefinition(root, featureDir, [
      { name: "backend", state: "deferred", path: "" },
      { name: "frontend", state: "deferred", path: "" }
    ]);
    const result = buildRepoBrScanContext(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 0);
    assert.match(result.text ?? "", /No ready class repositories found/);
    assert.match(result.text ?? "", /Repo scan is a no-op/);
  });
});

test("repo-br-scan context emits no-op block for empty class_repo_paths {}", () => {
  withWorkspace((root) => {
    const featureDir = makeFeatureDir(root);
    writeFileSync(
      path.join(featureDir, "init_progress_definition.yaml"),
      "meta_info:\n  class_repo_paths: {}\nsteps: []\n"
    );
    const result = buildRepoBrScanContext(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 0);
    assert.match(result.text ?? "", /no-op/);
  });
});

// ── Git fixture tests ───────────────────────────────────────────────────────

test("repo-br-scan context assembles block with ready repos when repos are on default branch", () => {
  withWorkspace((root) => {
    const { localPath } = createSyncedGitRepo(root, "backend");
    const featureDir = makeFeatureDir(root);
    writeDefinition(root, featureDir, [{ name: "backend", state: "ready", path: localPath }]);
    const featurePath = path.relative(root, featureDir);
    const result = buildRepoBrScanContext(featurePath, root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    assert.match(result.text ?? "", /# repo-br-scan context/);
    assert.match(result.text ?? "", /## Repositories to Scan/);
    assert.match(result.text ?? "", /- backend:/);
    assert.match(result.text ?? "", /gate_command: node .overmind\/overmind.js gate repo-br-scan/);
    assert.doesNotMatch(result.text ?? "", /\.claude\/skills/);
    assert.match(result.text ?? "", /feature_br_template_asset: assets\/feature_br_summary_TEMPLATE\.md/);
  });
});

test("repo-br-scan context collects only ready repos from mixed-state definition", () => {
  withWorkspace((root) => {
    const { localPath: backendPath } = createSyncedGitRepo(root, "backend");
    const featureDir = makeFeatureDir(root);
    writeDefinition(root, featureDir, [
      { name: "backend", state: "ready", path: backendPath },
      { name: "frontend", state: "deferred", path: "" }
    ]);
    const result = buildRepoBrScanContext(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    assert.match(result.text ?? "", /- backend:/);
    assert.doesNotMatch(result.text ?? "", /- frontend:/);
  });
});

test("repo-br-scan context deduplicates repos with same real path", () => {
  withWorkspace((root) => {
    const { localPath } = createSyncedGitRepo(root, "backend");
    const featureDir = makeFeatureDir(root);
    writeDefinition(root, featureDir, [
      { name: "backend", state: "ready", path: localPath },
      { name: "backend2", state: "ready", path: localPath }
    ]);
    const result = buildRepoBrScanContext(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    const repoLines = (result.text ?? "").split("\n").filter((l) => l.startsWith("- backend"));
    assert.equal(repoLines.length, 1);
  });
});

test("repo-br-scan context assembles block when repo is behind remote but on default branch", () => {
  withWorkspace((root) => {
    const { localPath } = createSyncedGitRepo(root, "backend");
    pushUpstreamChange(root, "backend", "upstream synchronized content");
    const featureDir = makeFeatureDir(root);
    writeDefinition(root, featureDir, [{ name: "backend", state: "ready", path: localPath }]);
    const result = buildRepoBrScanContext(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    assert.match(result.text ?? "", /- backend:/);
  });
});

test("repo-br-scan context blocks when ready repo is on non-default branch (D7)", () => {
  withWorkspace((root) => {
    const { localPath } = createSyncedGitRepo(root, "backend");
    git(["checkout", "-q", "-b", "worker"], localPath);
    const featureDir = makeFeatureDir(root);
    writeDefinition(root, featureDir, [{ name: "backend", state: "ready", path: localPath }]);
    const result = buildRepoBrScanContext(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 2);
    assert.match(
      result.errorMessage ?? "",
      /BLOCKED:.*is not on its default branch.*D7/
    );
  });
});

test("repo-br-scan context blocks on master when remote default is main (D7)", () => {
  withWorkspace((root) => {
    const { localPath } = createSyncedGitRepo(root, "backend");
    git(["symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main"], localPath);
    git(["checkout", "-q", "-b", "master"], localPath);
    const featureDir = makeFeatureDir(root);
    writeDefinition(root, featureDir, [{ name: "backend", state: "ready", path: localPath }]);
    const result = buildRepoBrScanContext(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /BLOCKED:.*is not on its default branch.*D7/);
  });
});

test("repo-br-scan context blocks when both main and master exist with no remote default (D7)", () => {
  withWorkspace((root) => {
    const { localPath } = createSyncedGitRepo(root, "backend");
    git(["checkout", "-q", "-b", "master"], localPath);
    git(["checkout", "-q", "main"], localPath);
    const headRefResult = spawnSync(
      "git",
      ["symbolic-ref", "-q", "refs/remotes/origin/HEAD"],
      { cwd: localPath, encoding: "utf8" }
    );
    if ((headRefResult.status ?? 1) === 0) {
      spawnSync("git", ["symbolic-ref", "-d", "refs/remotes/origin/HEAD"], {
        cwd: localPath,
        encoding: "utf8"
      });
    }
    const featureDir = makeFeatureDir(root);
    writeDefinition(root, featureDir, [{ name: "backend", state: "ready", path: localPath }]);
    const result = buildRepoBrScanContext(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /BLOCKED:.*ambiguous.*D7/);
  });
});

test("repo-br-scan context blocks when ready repo has uncommitted changes (D7)", () => {
  withWorkspace((root) => {
    const { localPath } = createSyncedGitRepo(root, "backend");
    writeFileSync(path.join(localPath, "README.md"), "dirty\n", { flag: "a" });
    const featureDir = makeFeatureDir(root);
    writeDefinition(root, featureDir, [{ name: "backend", state: "ready", path: localPath }]);
    const result = buildRepoBrScanContext(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /BLOCKED:.*uncommitted changes.*D7/);
  });
});

test("repo-br-scan context blocks when ready repo has no upstream (D7)", () => {
  withWorkspace((root) => {
    const { localPath } = createSyncedGitRepo(root, "backend");
    spawnSync("git", ["branch", "--unset-upstream", "main"], { cwd: localPath, encoding: "utf8" });
    const featureDir = makeFeatureDir(root);
    writeDefinition(root, featureDir, [{ name: "backend", state: "ready", path: localPath }]);
    const result = buildRepoBrScanContext(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /BLOCKED:.*no upstream.*D7/);
  });
});

// ── CLI-level context tests ─────────────────────────────────────────────────

test("overmind context repo-br-scan exits 0 and emits no-op block when no repos ready", () => {
  withWorkspace((root) => {
    const featureDir = makeFeatureDir(root);
    writeDefinition(root, featureDir, [{ name: "backend", state: "deferred", path: "" }]);
    const featurePath = path.relative(root, featureDir);
    const result = spawnSync(
      process.execPath,
      [bundlePath, "context", "repo-br-scan", featurePath],
      { cwd: root, encoding: "utf8" }
    );
    assert.equal(result.status, 0);
    assert.match(result.stdout, /No ready class repositories found/);
  });
});

test("overmind context repo-br-scan exits 2 when feature_br_summary.md absent", () => {
  withWorkspace((root) => {
    const featureDir = path.join(root, "projects", "p1", "feature-b");
    mkdirSync(featureDir, { recursive: true });
    const featurePath = path.relative(root, featureDir);
    const result = spawnSync(
      process.execPath,
      [bundlePath, "context", "repo-br-scan", featurePath],
      { cwd: root, encoding: "utf8" }
    );
    assert.equal(result.status, 2);
    assert.match(result.stderr, /ERROR:/);
  });
});

test("overmind context repo-br-scan exits 0 with assembled context when repos synced", () => {
  withWorkspace((root) => {
    const { localPath } = createSyncedGitRepo(root, "backend");
    const featureDir = makeFeatureDir(root);
    writeDefinition(root, featureDir, [{ name: "backend", state: "ready", path: localPath }]);
    const featurePath = path.relative(root, featureDir);
    const result = spawnSync(
      process.execPath,
      [bundlePath, "context", "repo-br-scan", featurePath],
      { cwd: root, encoding: "utf8" }
    );
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /# repo-br-scan context/);
    assert.match(result.stdout, /## Repositories to Scan/);
    assert.doesNotMatch(result.stdout, /\.claude\/skills/);
  });
});
