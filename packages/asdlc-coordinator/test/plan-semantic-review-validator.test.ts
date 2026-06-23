import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { validatePlanSemanticReview, validatePlanSemanticReviewContent } from "../src/validate/plan-semantic-review.js";

function meta(status = "complete"): string { return `## 1. Document Meta
- feature_id: F-1
- feature_title: Feature
- source_implementation_plan: projects/p1/feature-a/implementation_plan.md
- source_project_definition: projects/p1/init_progress_definition.yaml
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_technical_requirements: projects/p1/feature-a/technical_requirements.md
- review_status: ${status}
- last_updated: 2026-07-03

## 2. Review Guidance
- completion_rule: complete

## 3. Findings Ledger`;
}
function finding(overrides: Record<string, string> = {}): string {
  const fields = { severity: "Medium", finding_type: "step_scope_overlap", state: "applied", target_steps: "Step 1.1", related_requirements: "REQ-1", related_evidence: "gap/TECH_REQ-1", summary: "Summary", rationale: "Rationale", recommendation: "Recommendation", user_selection: "selected", plan_patch_summary: "Patched", resolution_notes: "Resolved", ...overrides };
  return `### Finding 1 - Finding\n${Object.entries(fields).map(([key, value]) => `- ${key}: ${value}`).join("\n")}\n`;
}
function validNoFindings(): string { return `${meta()}\n- no_findings: true\n`; }
function messages(content: string): string { return validatePlanSemanticReviewContent(content).join("\n"); }

test("plan-semantic-review gate accepts valid no-findings and findings-present ledgers", () => {
  assert.deepEqual(validatePlanSemanticReviewContent(validNoFindings()), []);
  assert.deepEqual(validatePlanSemanticReviewContent(`${meta()}\n${finding()}`), []);
});

test("plan-semantic-review gate requires all sections", () => {
  for (const heading of ["## 1. Document Meta", "## 2. Review Guidance", "## 3. Findings Ledger"]) {
    assert.match(messages(validNoFindings().replace(heading, `## Missing ${heading}`)), /missing section:/);
  }
});

test("plan-semantic-review gate enforces meta and ledger consistency", () => {
  assert.match(messages(validNoFindings().replace("- feature_id: F-1", "- feature_id: [UNFILLED]")), /missing or unfilled meta key: feature_id/);
  assert.match(messages(validNoFindings().replace("review_status: complete", "review_status: done")), /review_status must be/);
  assert.match(messages(`${meta()}\n`), /no_findings: true/);
  assert.match(messages(`${meta("in_progress")}\n- no_findings: true\n`), /review_status must be complete/);
  assert.match(messages(`${meta()}\n- no_findings: true\n${finding()}`), /no_findings must not be true/);
});

test("plan-semantic-review gate enforces every finding field and enum", () => {
  assert.match(messages(`${meta()}\n${finding({ summary: "" })}`), /missing or unfilled key: summary/);
  assert.match(messages(`${meta()}\n${finding({ severity: "Critical" })}`), /invalid severity/);
  assert.match(messages(`${meta()}\n${finding({ finding_type: "style" })}`), /invalid finding_type/);
  assert.match(messages(`${meta()}\n${finding({ state: "done" })}`), /invalid state/);
  for (const findingType of ["delivered_surface_consumption_unclear", "repo_scaffold_readiness_unclear"]) {
    assert.match(messages(`${meta()}\n${finding({ finding_type: findingType, resolution_notes: "<decision and final outcome>" })}`), /terminal state with empty resolution_notes/);
  }
  assert.match(messages(`${meta()}\n${finding({ finding_type: "delivered_surface_consumption_unclear", related_requirements: "FR-1" })}`), /must reference at least one REQ-/);
});

test("plan-semantic-review gate rejects complete non-terminal findings and placeholders", () => {
  assert.match(messages(`${meta()}\n${finding({ state: "added" })}`), /non-terminal findings remain/);
  assert.match(messages(validNoFindings().replace("Feature", "[UNFILLED]")), /artifact still contains \[UNFILLED\]/);
});

test("plan-semantic-review gate preserves runtime and empty-content exit codes", () => {
  const root = mkdtempSync(path.join(tmpdir(), "semantic-review-gate-"));
  try {
    const feature = path.join(root, "projects", "p1", "feature-a");
    mkdirSync(feature, { recursive: true });
    assert.equal(validatePlanSemanticReview("", root).exitCode, 2);
    assert.equal(validatePlanSemanticReview("projects/p1/feature-a", root).exitCode, 2);
    const target = path.join(feature, "implementation_plan_semantic_review.md");
    writeFileSync(target, ""); assert.equal(validatePlanSemanticReview("projects/p1/feature-a", root).exitCode, 1);
    writeFileSync(target, " \n\t"); assert.equal(validatePlanSemanticReview("projects/p1/feature-a", root).exitCode, 1);
    writeFileSync(target, validNoFindings()); assert.equal(validatePlanSemanticReview("projects/p1/feature-a", root).exitCode, 0);
  } finally { rmSync(root, { recursive: true, force: true }); }
});
