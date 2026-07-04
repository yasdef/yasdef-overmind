import { mkdirSync, mkdtempSync, realpathSync, rmSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { buildTechnicalRequirementsContext } from "../src/context/technical-requirements.js";

function fixture(
  root: string,
  classes = "[backend, frontend]"
): { project: string; feature: string } {
  const project = path.join(root, "projects", "p1");
  const feature = path.join(project, "feature-a");
  mkdirSync(feature, { recursive: true });
  writeFileSync(
    path.join(project, "init_progress_definition.yaml"),
    `meta_info:\n  project_classes: ${classes}\nsteps: []\n`
  );
  writeFileSync(path.join(project, "common_contract_definition.md"), "contract\n");
  writeFileSync(path.join(feature, "requirements_ears.md"), "requirements\n");
  for (const klass of ["backend", "frontend"])
    writeFileSync(path.join(feature, `project_surface_struct_resp_map_${klass}.md`), "surface\n");
  return { project, feature };
}

test("technical-requirements context: emits full two-class context and five read-only entries", () => {
  const root = mkdtempSync(path.join(tmpdir(), "technical-context-"));
  try {
    fixture(root);
    const result = buildTechnicalRequirementsContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    const text = result.text ?? "";
    for (const expected of [
      `- workspace_root: ${realpathSync(root)}`,
      "- project_root: projects/p1",
      "- feature_root: projects/p1/feature-a",
      "- target_artifact: projects/p1/feature-a/technical_requirements.md",
      "node .overmind/overmind.js gate technical-requirements projects/p1/feature-a",
      "assets/technical_requirements_TEMPLATE.md",
      "assets/technical_requirements_GOLDEN_EXAMPLE.md",
      "- backend: projects/p1/feature-a/project_surface_struct_resp_map_backend.md",
      "- frontend: projects/p1/feature-a/project_surface_struct_resp_map_frontend.md"
    ])
      assert.ok(text.includes(expected), expected);
    assert.equal((text.match(/^- read_only_input:/gm) ?? []).length, 5);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("technical-requirements context: infrastructure is silently skipped", () => {
  const root = mkdtempSync(path.join(tmpdir(), "technical-context-infra-"));
  try {
    fixture(root, "[backend, infrastructure]");
    const result = buildTechnicalRequirementsContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    assert.doesNotMatch(result.text ?? "", /infrastructure/);
    assert.equal((result.text?.match(/^- read_only_input:/gm) ?? []).length, 4);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("technical-requirements context: unsupported project class exits 2", () => {
  const root = mkdtempSync(path.join(tmpdir(), "technical-context-class-"));
  try {
    fixture(root, "[backend, bakend]");
    const result = buildTechnicalRequirementsContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /Unsupported project class 'bakend'/);
    assert.match(result.errorMessage ?? "", /init_progress_definition\.yaml/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("technical-requirements context: missing required inputs exit 2", () => {
  for (const missing of [
    "requirements_ears.md",
    "common_contract_definition.md",
    "project_surface_struct_resp_map_frontend.md"
  ]) {
    const root = mkdtempSync(path.join(tmpdir(), "technical-context-missing-"));
    try {
      const { project, feature } = fixture(root);
      const file =
        missing === "common_contract_definition.md"
          ? path.join(project, missing)
          : path.join(feature, missing);
      unlinkSync(file);
      const result = buildTechnicalRequirementsContext("projects/p1/feature-a", root);
      assert.equal(result.exitCode, 2, missing);
      assert.ok((result.errorMessage ?? "").includes(missing));
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  }
});

test("technical-requirements context: feature path must resolve under projects/<id>/<feature>", () => {
  const root = mkdtempSync(path.join(tmpdir(), "technical-context-path-"));
  try {
    mkdirSync(path.join(root, "feature-a"));
    const result = buildTechnicalRequirementsContext("feature-a", root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /projects\/<project-id>\/<feature-folder>/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
