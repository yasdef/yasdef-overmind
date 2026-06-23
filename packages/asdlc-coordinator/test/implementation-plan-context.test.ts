import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { buildImplementationPlanContext } from "../src/context/implementation-plan.js";

function fixture(root: string, classes = "backend, frontend, infrastructure"): { project: string; feature: string } {
  const project = path.join(root, "projects", "p1");
  const feature = path.join(project, "feature-a");
  mkdirSync(feature, { recursive: true });
  writeFileSync(path.join(project, "init_progress_definition.yaml"), `meta_info:\n  project_classes: [${classes}]\nsteps: []\n`);
  for (const file of ["requirements_ears.md", "technical_requirements.md", "feature_contract_delta.md", "implementation_slices.md", "prerequisite_gaps.md"]) writeFileSync(path.join(feature, file), `${file}\n`);
  return { project, feature };
}

test("implementation-plan context emits runtime bindings, six read-only inputs, assets, and active classes", () => {
  const root = mkdtempSync(path.join(tmpdir(), "plan-context-"));
  try {
    fixture(root);
    const result = buildImplementationPlanContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 0);
    const text = result.text ?? "";
    for (const value of [root, "projects/p1", "projects/p1/feature-a", "implementation_plan.md", "backend", "frontend", "assets/implementation_plan_TEMPLATE.md", "assets/implementation_plan_GOLDEN_EXAMPLE.md", "node .overmind/overmind.js gate implementation-plan projects/p1/feature-a"]) assert.match(text, new RegExp(value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
    for (const file of ["init_progress_definition.yaml", "requirements_ears.md", "technical_requirements.md", "feature_contract_delta.md", "implementation_slices.md", "prerequisite_gaps.md"]) assert.match(text, new RegExp(`read_only_input: .*${file}`));
    assert.doesNotMatch(text, /Active Repo Classes[\s\S]*infrastructure/);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("implementation-plan context rejects unsupported classes and missing inputs", () => {
  let root = mkdtempSync(path.join(tmpdir(), "plan-context-class-"));
  try {
    fixture(root, "backend, desktop");
    const result = buildImplementationPlanContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /desktop/);
  } finally { rmSync(root, { recursive: true, force: true }); }
  for (const missing of ["requirements_ears.md", "technical_requirements.md", "feature_contract_delta.md", "implementation_slices.md", "prerequisite_gaps.md"]) {
    root = mkdtempSync(path.join(tmpdir(), "plan-context-missing-"));
    try {
      const { feature } = fixture(root);
      unlinkSync(path.join(feature, missing));
      assert.equal(buildImplementationPlanContext("projects/p1/feature-a", root).exitCode, 2, missing);
    } finally { rmSync(root, { recursive: true, force: true }); }
  }
  root = mkdtempSync(path.join(tmpdir(), "plan-context-path-"));
  try { assert.equal(buildImplementationPlanContext("projects/p1/missing", root).exitCode, 2); }
  finally { rmSync(root, { recursive: true, force: true }); }
});
