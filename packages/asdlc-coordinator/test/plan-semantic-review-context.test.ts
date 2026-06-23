import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { buildPlanSemanticReviewContext } from "../src/context/plan-semantic-review.js";

function fixture(root: string, classes = "backend, frontend, infrastructure"): { project: string; feature: string } {
  const project = path.join(root, "projects", "p1");
  const feature = path.join(project, "feature-a");
  mkdirSync(feature, { recursive: true });
  writeFileSync(path.join(project, "init_progress_definition.yaml"), `meta_info:\n  project_classes: [${classes}]\nsteps: []\n`);
  for (const file of ["requirements_ears.md", "technical_requirements.md", "prerequisite_gaps.md", "implementation_plan.md"]) writeFileSync(path.join(feature, file), `${file}\n`);
  for (const klass of classes.split(",").map((item) => item.trim()).filter((item) => ["backend", "frontend", "mobile"].includes(item))) writeFileSync(path.join(feature, `project_surface_struct_resp_map_${klass}.md`), `${klass}\n`);
  return { project, feature };
}

test("plan-semantic-review context emits mutable targets, gates, active classes, assets, and exact read-only manifest", () => {
  const root = mkdtempSync(path.join(tmpdir(), "semantic-review-context-"));
  try {
    fixture(root);
    const result = buildPlanSemanticReviewContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    const text = result.text ?? "";
    for (const value of [root, "projects/p1", "projects/p1/feature-a", "implementation_plan.md", "implementation_plan_semantic_review.md", "backend", "frontend", "assets/implementation_plan_semantic_review_TEMPLATE.md", "assets/implementation_plan_semantic_review_GOLDEN_EXAMPLE.md", "node .overmind/overmind.js gate plan-semantic-review projects/p1/feature-a", "node .overmind/overmind.js gate implementation-plan projects/p1/feature-a"]) assert.ok(text.includes(value), value);
    for (const file of ["init_progress_definition.yaml", "requirements_ears.md", "technical_requirements.md", "prerequisite_gaps.md", "project_surface_struct_resp_map_backend.md", "project_surface_struct_resp_map_frontend.md"]) assert.match(text, new RegExp(`^- read_only_input: .*${file}$`, "m"));
    assert.equal((text.match(/^- read_only_input:/gm) ?? []).length, 6);
    assert.doesNotMatch(text, /Active Repo Classes[\s\S]*- infrastructure/);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("plan-semantic-review context skips infrastructure and allows zero supported repo classes", () => {
  const root = mkdtempSync(path.join(tmpdir(), "semantic-review-infra-"));
  try {
    fixture(root, "infrastructure");
    const result = buildPlanSemanticReviewContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    assert.match(result.text ?? "", /## Active Repo Classes\n- none/);
    assert.doesNotMatch(result.text ?? "", /project_surface_struct_resp_map_/);
    assert.equal(((result.text ?? "").match(/^- read_only_input:/gm) ?? []).length, 4);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("plan-semantic-review context rejects unsupported classes and missing surface maps", () => {
  let root = mkdtempSync(path.join(tmpdir(), "semantic-review-class-"));
  try {
    fixture(root, "backend, desktop");
    const result = buildPlanSemanticReviewContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 2); assert.match(result.errorMessage ?? "", /desktop/);
  } finally { rmSync(root, { recursive: true, force: true }); }
  root = mkdtempSync(path.join(tmpdir(), "semantic-review-map-"));
  try {
    const { feature } = fixture(root, "backend");
    unlinkSync(path.join(feature, "project_surface_struct_resp_map_backend.md"));
    const result = buildPlanSemanticReviewContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 2); assert.match(result.errorMessage ?? "", /backend/);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("plan-semantic-review context rejects every missing required input and invalid feature paths", () => {
  for (const missing of ["requirements_ears.md", "technical_requirements.md", "prerequisite_gaps.md", "implementation_plan.md"]) {
    const root = mkdtempSync(path.join(tmpdir(), "semantic-review-missing-"));
    try {
      const { feature } = fixture(root, "backend");
      unlinkSync(path.join(feature, missing));
      const result = buildPlanSemanticReviewContext("projects/p1/feature-a", root);
      assert.equal(result.exitCode, 2, missing); assert.match(result.errorMessage ?? "", new RegExp(missing));
    } finally { rmSync(root, { recursive: true, force: true }); }
  }
  const root = mkdtempSync(path.join(tmpdir(), "semantic-review-definition-"));
  try {
    const { project } = fixture(root, "backend");
    unlinkSync(path.join(project, "init_progress_definition.yaml"));
    assert.equal(buildPlanSemanticReviewContext("projects/p1/feature-a", root).exitCode, 2);
    assert.equal(buildPlanSemanticReviewContext("projects/p1/missing", root).exitCode, 2);
  } finally { rmSync(root, { recursive: true, force: true }); }
});
