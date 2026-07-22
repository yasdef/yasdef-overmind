import { existsSync, mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import { buildContractDeltaContext } from "../src/context/contract-delta.js";

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

function fixture(
  root: string,
  withRepo = false
): { project: string; feature: string; repo?: string } {
  const project = path.join(root, "projects", "p1");
  const feature = path.join(project, "feature-a");
  mkdirSync(feature, { recursive: true });
  writeFileSync(path.join(feature, "feature_br_summary.md"), "BR\n");
  writeFileSync(path.join(feature, "requirements_ears.md"), "EARS\n");
  writeFileSync(path.join(project, "common_contract_definition.md"), "baseline\n");
  const repo = withRepo ? createRepo(root) : undefined;
  writeFileSync(
    path.join(project, "init_progress_definition.yaml"),
    `meta_info:\n  project_classes: [backend, frontend]\n  project_type_code: A\n  class_repo_paths:${repo ? `\n    backend:\n      state: ready\n      path: "${repo}"` : " {}"}\nsteps: []\n`
  );
  return { project, feature, repo };
}

test("contract-delta context includes sources, repos, siblings, trigger, assets, and one write", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-contract-context-"));
  try {
    const { project, feature } = fixture(root, true);
    const sibling = path.join(project, "feature-b");
    mkdirSync(sibling);
    writeFileSync(path.join(sibling, "implementation_plan.md"), "plan\n");
    writeFileSync(path.join(sibling, "feature_contract_delta.md"), "pending\n");
    const result = buildContractDeltaContext(path.relative(root, feature), root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    const text = result.text ?? "";
    for (const expected of [
      "- read_only_input: projects/p1/feature-a/feature_br_summary.md",
      "- read_only_input: projects/p1/feature-a/requirements_ears.md",
      "- read_only_input: projects/p1/common_contract_definition.md",
      "- read_only_input: projects/p1/feature-b/feature_contract_delta.md",
      "- backend:",
      "Pending contract delta source: feature-b/feature_contract_delta.md",
      "cross_class_peer_trigger: active",
      "gate contract-delta projects/p1/feature-a",
      "assets/feature_contract_delta_TEMPLATE.md",
      "assets/feature_contract_delta_GOLDEN_EXAMPLE.md"
    ])
      assert.ok(text.includes(expected), expected);
    assert.doesNotMatch(text, /\.codex\/skills|\.claude\/skills/);
    assert.equal((text.match(/^- read_only_input: /gm) ?? []).length, 4);
    assert.equal((text.match(/## Allowed Write Surface/g) ?? []).length, 1);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("contract-delta context rejects invalid layout and each missing required input", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-contract-context-errors-"));
  try {
    const { project, feature } = fixture(root);
    const required = [
      path.join(feature, "feature_br_summary.md"),
      path.join(feature, "requirements_ears.md"),
      path.join(project, "common_contract_definition.md"),
      path.join(project, "init_progress_definition.yaml")
    ];
    for (const requiredPath of required) {
      const content = "saved\n";
      rmSync(requiredPath);
      const result = buildContractDeltaContext(path.relative(root, feature), root);
      assert.equal(result.exitCode, 2);
      assert.ok(result.errorMessage?.includes(path.basename(requiredPath)));
      writeFileSync(requiredPath, content);
    }
    const outside = path.join(root, "feature-outside");
    mkdirSync(outside);
    assert.equal(buildContractDeltaContext(outside, root).exitCode, 2);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("contract-delta context rejects a feature path symlinked outside the workspace", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-contract-escape-"));
  const outside = mkdtempSync(path.join(tmpdir(), "overmind-contract-outside-"));
  try {
    writeFileSync(path.join(outside, "requirements_ears.md"), "EARS\n");
    mkdirSync(path.join(root, "projects", "p1"), { recursive: true });
    symlinkSync(outside, path.join(root, "projects", "p1", "feature-a"));
    const result = buildContractDeltaContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /must resolve inside ASDLC workspace/);
  } finally {
    rmSync(root, { recursive: true, force: true });
    rmSync(outside, { recursive: true, force: true });
  }
});

test("contract-delta context returns repo block message verbatim", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-contract-context-blocked-"));
  try {
    const { feature, repo } = fixture(root, true);
    assert.ok(repo && existsSync(repo));
    writeFileSync(path.join(repo, "dirty.txt"), "dirty\n");
    const result = buildContractDeltaContext(path.relative(root, feature), root);
    assert.equal(result.exitCode, 2);
    assert.equal(result.verbatim, true);
    assert.match(result.errorMessage ?? "", /^BLOCKED:/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
