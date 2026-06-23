import { mkdirSync, mkdtempSync, realpathSync, rmSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { buildImplementationSlicesContext } from "../src/context/implementation-slices.js";

function fixture(root: string, classes = "[backend, frontend]"): { project: string; feature: string } {
  const project = path.join(root, "projects", "p1");
  const feature = path.join(project, "feature-a");
  mkdirSync(feature, { recursive: true });
  writeFileSync(path.join(project, "init_progress_definition.yaml"), `meta_info:\n  project_classes: ${classes}\nsteps: []\n`);
  for (const file of ["requirements_ears.md", "technical_requirements.md", "feature_contract_delta.md"]) {
    writeFileSync(path.join(feature, file), `${file}\n`);
  }
  for (const klass of ["backend", "frontend"]) {
    writeFileSync(path.join(feature, `project_surface_struct_resp_map_${klass}.md`), "surface\n");
  }
  return { project, feature };
}

test("implementation-slices context: emits full two-class context and read-only manifest", () => {
  const root = mkdtempSync(path.join(tmpdir(), "slices-context-"));
  try {
    fixture(root);
    const result = buildImplementationSlicesContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    const text = result.text ?? "";
    for (const expected of [
      `- workspace_root: ${realpathSync(root)}`,
      "- project_root: projects/p1",
      "- feature_root: projects/p1/feature-a",
      "- target_artifact: projects/p1/feature-a/implementation_slices.md",
      "node .overmind/overmind.js gate implementation-slices projects/p1/feature-a",
      "assets/implementation_slices_TEMPLATE.md",
      "assets/implementation_slices_GOLDEN_EXAMPLE.md",
      "- backend: projects/p1/feature-a/project_surface_struct_resp_map_backend.md",
      "- frontend: projects/p1/feature-a/project_surface_struct_resp_map_frontend.md"
    ]) assert.ok(text.includes(expected), expected);
    assert.equal((text.match(/^- read_only_input:/gm) ?? []).length, 6);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("implementation-slices context: prerequisite gaps is conditional read-only input", () => {
  const root = mkdtempSync(path.join(tmpdir(), "slices-context-prereq-"));
  try {
    const { feature } = fixture(root);
    let result = buildImplementationSlicesContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 0);
    assert.doesNotMatch(result.text ?? "", /read_only_input: .*prerequisite_gaps\.md/);
    writeFileSync(path.join(feature, "prerequisite_gaps.md"), "gaps\n");
    result = buildImplementationSlicesContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 0);
    assert.match(result.text ?? "", /read_only_input: projects\/p1\/feature-a\/prerequisite_gaps\.md/);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("implementation-slices context: infrastructure is skipped and unsupported classes fail", () => {
  for (const [classes, exitCode, pattern] of [
    ["[backend, infrastructure]", 0, /infrastructure/],
    ["[backend, bakend]", 2, /Unsupported project class 'bakend'/]
  ] as const) {
    const root = mkdtempSync(path.join(tmpdir(), "slices-context-class-"));
    try {
      fixture(root, classes);
      const result = buildImplementationSlicesContext("projects/p1/feature-a", root);
      assert.equal(result.exitCode, exitCode);
      if (exitCode === 0) assert.doesNotMatch(result.text ?? "", pattern);
      else assert.match(result.errorMessage ?? "", pattern);
    } finally { rmSync(root, { recursive: true, force: true }); }
  }
});

test("implementation-slices context: missing required inputs exit 2", () => {
  for (const missing of ["requirements_ears.md", "technical_requirements.md", "feature_contract_delta.md", "project_surface_struct_resp_map_frontend.md"]) {
    const root = mkdtempSync(path.join(tmpdir(), "slices-context-missing-"));
    try {
      const { feature } = fixture(root);
      unlinkSync(path.join(feature, missing));
      const result = buildImplementationSlicesContext("projects/p1/feature-a", root);
      assert.equal(result.exitCode, 2, missing);
      assert.ok((result.errorMessage ?? "").includes(missing));
    } finally { rmSync(root, { recursive: true, force: true }); }
  }
});

test("implementation-slices context: feature path must be nested under projects", () => {
  const root = mkdtempSync(path.join(tmpdir(), "slices-context-path-"));
  try {
    mkdirSync(path.join(root, "feature-a"));
    const result = buildImplementationSlicesContext("feature-a", root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /projects\/<project-id>\/<feature-folder>/);
  } finally { rmSync(root, { recursive: true, force: true }); }
});
