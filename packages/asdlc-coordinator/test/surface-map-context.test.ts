import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import { buildSurfaceMapContext } from "../src/context/surface-map.js";

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
  opts: { repo?: boolean; blueprint?: boolean; classes?: string } = {}
): {
  project: string;
  feature: string;
} {
  const project = path.join(root, "projects", "p1");
  const feature = path.join(project, "feature-a");
  mkdirSync(feature, { recursive: true });
  writeFileSync(path.join(feature, "requirements_ears.md"), "EARS\n");
  writeFileSync(path.join(feature, "feature_contract_delta.md"), "delta\n");
  const repo = opts.repo ? createRepo(root) : undefined;
  const classes = opts.classes ?? "[backend, frontend]";
  writeFileSync(
    path.join(project, "init_progress_definition.yaml"),
    `meta_info:\n  project_classes: ${classes}\n  project_type_code: A\n  class_repo_paths:${repo ? `\n    backend:\n      state: ready\n      path: "${repo}"` : " {}"}\nsteps: []\n`
  );
  if (opts.blueprint) {
    writeFileSync(path.join(project, "project_stack_blueprint_backend.md"), "# blueprint\n");
  }
  return { project, feature };
}

test("surface-map context: backend with ready repo emits binding, scan scope, manifest, gate", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-surface-context-"));
  try {
    const { project, feature } = fixture(root, { repo: true });
    const sibling = path.join(project, "feature-b");
    mkdirSync(sibling);
    writeFileSync(path.join(sibling, "implementation_plan.md"), "plan\n");
    const result = buildSurfaceMapContext(path.relative(root, feature), "backend", root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    const text = result.text ?? "";
    for (const expected of [
      "- target_class: backend",
      "- track_label: backend",
      "assets/project_surface_struct_resp_map_be_TEMPLATE.md",
      "assets/project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md",
      "- target_artifact: projects/p1/feature-a/project_surface_struct_resp_map_backend.md",
      "gate surface-map projects/p1/feature-a --class backend",
      "- read_only_input: projects/p1/feature-a/requirements_ears.md",
      "- read_only_input: projects/p1/feature-a/feature_contract_delta.md",
      "- read_only_input: projects/p1/init_progress_definition.yaml",
      "- read_only_input: projects/p1/feature-b/implementation_plan.md",
      "- In-flight plan source: feature-b/implementation_plan.md"
    ])
      assert.ok(text.includes(expected), expected);
    assert.doesNotMatch(text, /\.codex\/skills|\.claude\/skills/);
    assert.equal((text.match(/^- read_only_input: /gm) ?? []).length, 4);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("surface-map context: frontend uses fe assets", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-surface-context-fe-"));
  try {
    const { project } = fixture(root, { classes: "[frontend]" });
    writeFileSync(path.join(project, "project_stack_blueprint_frontend.md"), "# fe blueprint\n");
    const result = buildSurfaceMapContext("projects/p1/feature-a", "frontend", root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    assert.ok(
      (result.text ?? "").includes("assets/project_surface_struct_resp_map_fe_TEMPLATE.md")
    );
    assert.ok((result.text ?? "").includes("--class frontend"));
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("surface-map context: mobile uses fe assets with a mobile target and gate", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-surface-context-mobile-"));
  try {
    const { project } = fixture(root, { classes: "[mobile]" });
    writeFileSync(path.join(project, "project_stack_blueprint_mobile.md"), "# mobile blueprint\n");
    const result = buildSurfaceMapContext("projects/p1/feature-a", "mobile", root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    const text = result.text ?? "";
    assert.ok(text.includes("assets/project_surface_struct_resp_map_fe_TEMPLATE.md"));
    assert.ok(text.includes("project_surface_struct_resp_map_mobile.md"));
    assert.ok(text.includes("gate surface-map projects/p1/feature-a --class mobile"));
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("surface-map context: ready repo AND blueprint expose both evidence sources", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-surface-context-both-"));
  try {
    const { feature } = fixture(root, { repo: true, blueprint: true });
    const result = buildSurfaceMapContext(path.relative(root, feature), "backend", root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    const text = result.text ?? "";
    // Ready repo is the scan scope...
    assert.match(text, /## Scan Scope\n- backend: \//);
    // ...and the blueprint is still surfaced AND read-only-protected (in the manifest).
    assert.ok(
      text.includes("- Stack blueprint source: projects/p1/project_stack_blueprint_backend.md")
    );
    assert.ok(text.includes("- read_only_input: projects/p1/project_stack_blueprint_backend.md"));
    // three always-on inputs + the blueprint = 4 read-only inputs
    assert.equal((text.match(/^- read_only_input: /gm) ?? []).length, 4);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("surface-map context: blueprint fallback when no ready repo", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-surface-context-bp-"));
  try {
    fixture(root, { blueprint: true });
    const result = buildSurfaceMapContext("projects/p1/feature-a", "backend", root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    const text = result.text ?? "";
    assert.ok(
      text.includes(
        "no ready repository; blueprint evidence is primary planned structural evidence"
      )
    );
    assert.ok(text.includes("- read_only_input: projects/p1/project_stack_blueprint_backend.md"));
    assert.ok(
      text.includes("Stack blueprint source: projects/p1/project_stack_blueprint_backend.md")
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("surface-map context: class not active or neither repo/blueprint exits 2", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-surface-context-err-"));
  try {
    fixture(root, { classes: "[backend]" });
    const notActive = buildSurfaceMapContext("projects/p1/feature-a", "frontend", root);
    assert.equal(notActive.exitCode, 2);
    assert.match(notActive.errorMessage ?? "", /not an active/);

    const noEvidence = buildSurfaceMapContext("projects/p1/feature-a", "backend", root);
    assert.equal(noEvidence.exitCode, 2);
    assert.match(noEvidence.errorMessage ?? "", /neither a ready repository nor a stack blueprint/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("surface-map context: feature path symlinked outside the workspace is rejected", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-surface-escape-"));
  const outside = mkdtempSync(path.join(tmpdir(), "overmind-surface-outside-"));
  try {
    mkdirSync(outside, { recursive: true });
    writeFileSync(path.join(outside, "requirements_ears.md"), "EARS\n");
    mkdirSync(path.join(root, "projects", "p1"), { recursive: true });
    symlinkSync(outside, path.join(root, "projects", "p1", "feature-a"));
    const result = buildSurfaceMapContext("projects/p1/feature-a", "backend", root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /must resolve inside ASDLC workspace/);
  } finally {
    rmSync(root, { recursive: true, force: true });
    rmSync(outside, { recursive: true, force: true });
  }
});

test("surface-map context: in-workspace symlinked feature path canonicalizes to the real feature", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-surface-symlink-"));
  try {
    const { project } = fixture(root, { blueprint: true });
    symlinkSync(path.join(project, "feature-a"), path.join(project, "feature-alias"));
    const result = buildSurfaceMapContext("projects/p1/feature-alias", "backend", root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    const text = result.text ?? "";
    assert.ok(text.includes("projects/p1/feature-a/project_surface_struct_resp_map_backend.md"));
    assert.ok(!text.includes("feature-alias"));
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("surface-map context: dirty ready repo blocks verbatim", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-surface-context-dirty-"));
  try {
    const { feature } = fixture(root, { repo: true });
    const repo = path.join(root, "repo");
    writeFileSync(path.join(repo, "dirty.txt"), "dirty\n");
    const result = buildSurfaceMapContext(path.relative(root, feature), "backend", root);
    assert.equal(result.exitCode, 2);
    assert.equal(result.verbatim, true);
    assert.match(result.errorMessage ?? "", /^BLOCKED:/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("surface-map context: ready repo on the wrong branch blocks verbatim", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-surface-context-branch-"));
  try {
    const { feature } = fixture(root, { repo: true });
    git(["checkout", "-q", "-b", "feature-branch"], path.join(root, "repo"));
    const result = buildSurfaceMapContext(path.relative(root, feature), "backend", root);
    assert.equal(result.exitCode, 2);
    assert.equal(result.verbatim, true);
    assert.match(result.errorMessage ?? "", /^BLOCKED:/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("surface-map context: missing required input exits 2", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-surface-context-missing-"));
  try {
    const { feature } = fixture(root, { blueprint: true });
    rmSync(path.join(feature, "feature_contract_delta.md"));
    const result = buildSurfaceMapContext("projects/p1/feature-a", "backend", root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /Required file not found/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
