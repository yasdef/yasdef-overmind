import { mkdirSync, mkdtempSync, realpathSync, rmSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { buildPrerequisiteGapsContext } from "../src/context/prerequisite-gaps.js";

function fixture(root: string, classes = "[backend, frontend]"): string {
  const project = path.join(root, "projects", "p1");
  const feature = path.join(project, "feature-a");
  mkdirSync(feature, { recursive: true });
  writeFileSync(path.join(project, "init_progress_definition.yaml"), `meta_info:\n  project_classes: ${classes}\nsteps: []\n`);
  for (const file of ["requirements_ears.md", "technical_requirements.md", "implementation_slices.md"]) writeFileSync(path.join(feature, file), file);
  return feature;
}

test("prerequisite-gaps context emits paths, classes, assets, gate, and sibling manifest", () => {
  const root = mkdtempSync(path.join(tmpdir(), "prereq-context-"));
  try {
    fixture(root);
    const sibling = path.join(root, "projects", "p1", "sibling");
    mkdirSync(sibling); writeFileSync(path.join(sibling, "implementation_plan.md"), "plan");
    const result = buildPrerequisiteGapsContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    const text = result.text ?? "";
    for (const value of [realpathSync(root), "projects/p1/feature-a/prerequisite_gaps.md", "node .overmind/overmind.js gate prerequisite-gaps projects/p1/feature-a", "assets/prerequisite_gaps_TEMPLATE.md", "assets/prerequisite_gaps_GOLDEN_EXAMPLE.md", "projects/p1/sibling/implementation_plan.md", "- backend", "- frontend"]) assert.ok(text.includes(value), value);
    assert.equal((text.match(/^- read_only_input:/gm) ?? []).length, 5);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("prerequisite-gaps context omits absent siblings, skips infrastructure, and rejects unsupported classes", () => {
  const root = mkdtempSync(path.join(tmpdir(), "prereq-context-class-"));
  try {
    fixture(root, "[backend, infrastructure]");
    const ok = buildPrerequisiteGapsContext("projects/p1/feature-a", root);
    assert.equal(ok.exitCode, 0); assert.doesNotMatch(ok.text ?? "", /- infrastructure/);
    writeFileSync(path.join(root, "projects", "p1", "init_progress_definition.yaml"), "meta_info:\n  project_classes: [backend, bakend]\nsteps: []\n");
    assert.match(buildPrerequisiteGapsContext("projects/p1/feature-a", root).errorMessage ?? "", /bakend/);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("prerequisite-gaps context rejects missing inputs and invalid feature layout", () => {
  for (const missing of ["requirements_ears.md", "technical_requirements.md", "implementation_slices.md"]) {
    const root = mkdtempSync(path.join(tmpdir(), "prereq-context-missing-"));
    try { const feature = fixture(root); unlinkSync(path.join(feature, missing)); const result = buildPrerequisiteGapsContext("projects/p1/feature-a", root); assert.equal(result.exitCode, 2); assert.match(result.errorMessage ?? "", new RegExp(missing)); }
    finally { rmSync(root, { recursive: true, force: true }); }
  }
  const root = mkdtempSync(path.join(tmpdir(), "prereq-context-path-"));
  try { mkdirSync(path.join(root, "feature")); assert.match(buildPrerequisiteGapsContext("feature", root).errorMessage ?? "", /projects\/<project-id>/); }
  finally { rmSync(root, { recursive: true, force: true }); }
});
