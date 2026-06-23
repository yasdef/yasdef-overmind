import { mkdirSync, mkdtempSync, rmSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import {
  extractImplementationPlanRequiredSurfaces,
  extractScheduledSliceRefs
} from "../src/validate/implementation-plan.js";
import { extractRequiredMissingSurfaces } from "../src/validate/implementation-slices.js";
import { validatePrerequisiteGaps, validatePrerequisiteGapsContent } from "../src/validate/prerequisite-gaps.js";

const presentBlock = `#### Prerequisite: Orders endpoint
- status: present_in_repo
- surface_kind: present_user_reachable_surface
- surface_identity: none
- evidence: POST /orders
- slice_ref: none
`;
const scheduledBlock = `#### Prerequisite: Login route
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Operator login page
- evidence: Slice adds /login
- slice_ref: slice-1
`;
const siblingBlock = `#### Prerequisite: Export command
- status: scheduled_in_feature sibling/8.3
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Account export CLI command
- evidence: sibling implementation plan adds export command
- slice_ref: none
`;

function artifact(catalog: string, prerequisites: string, extraCoverage = ""): string {
  return `# Prerequisite Gaps

## 1. Document Meta
- feature_id: feature-a

## 2. Prerequisite Catalog

${catalog}
## 3. Requirement Coverage

### Requirement: REQ-1
- requirement_summary: Exercise the covered behavior.
- prerequisites: ${prerequisites}
${extraCoverage}`;
}

const present = artifact(presentBlock, "Orders endpoint");
const scheduled = artifact(scheduledBlock, "Login route");
const sibling = artifact(siblingBlock, "Export command");

test("prerequisite-gaps gate: valid statuses and all literal coverage pass", () => {
  const all = artifact(presentBlock + scheduledBlock + siblingBlock, "Orders endpoint; Login route; Export command");
  assert.deepEqual(validatePrerequisiteGapsContent(all, "WHEN POST /orders and `/login`", ""), []);
  assert.deepEqual(validatePrerequisiteGapsContent(sibling.replace("scheduled_in_feature sibling/8.3", "scheduled_in_feature   sibling/8.3"), "", ""), []);
  assert.deepEqual(validatePrerequisiteGapsContent(scheduled.replace("Operator login page", "Operator sync CLI command"), "", ""), []);
});

test("prerequisite-gaps gate: surface kind, status, identity, evidence, and slice rules are enforced", () => {
  const mutations: Array<[string, RegExp, string, RegExp]> = [
    [present, /present_user_reachable_surface/, "[UNFILLED]", /missing surface_kind/],
    [present, /present_user_reachable_surface/, "bad", /invalid surface_kind/],
    [present, /present_user_reachable_surface/, "transport_or_internal_execution_gap", /transport\/internal gaps/],
    [present, /present_in_repo/, "[UNFILLED]", /missing status/],
    [present, /present_in_repo/, "done", /invalid status/],
    [present, /present_in_repo/, "unmet", /unmet prerequisite/],
    [present, /- evidence: POST \/orders/, "- evidence: [UNFILLED]", /missing evidence/],
    [scheduled, /scheduled_in_slices/, "present_in_repo", /status is not unmet/],
    [scheduled, /Operator login page/, "none", /missing surface_identity/],
    [scheduled, /Operator login page/, "internal adapter", /non-operator-facing/],
    [scheduled, /slice-1/, "bad ref", /does not match required format/]
  ];
  for (const [input, from, to, expected] of mutations) {
    assert.match(validatePrerequisiteGapsContent(input.replace(from, to), "", "").join("\n"), expected);
  }
  assert.match(validatePrerequisiteGapsContent(present.replace("surface_identity: none", "surface_identity: Orders page"), "", "").join("\n"), /must use surface_identity: none/);
  assert.match(validatePrerequisiteGapsContent(present.replace("status: present_in_repo", "status: scheduled_in_slices"), "", "").join("\n"), /status is not present_in_repo/);
  assert.match(validatePrerequisiteGapsContent(scheduled.replace(/- evidence:.*/, "- evidence: [UNFILLED]"), "", "").join("\n"), /scheduled_in_slices.*missing evidence/);
  assert.match(validatePrerequisiteGapsContent(scheduled.replace("slice_ref: slice-1", "slice_ref: none"), "", "").join("\n"), /missing slice_ref/);
  assert.match(validatePrerequisiteGapsContent(scheduled.replace("- slice_ref: slice-1", ""), "", "").join("\n"), /missing slice_ref/);
  assert.match(validatePrerequisiteGapsContent(sibling.replace(/- evidence:.*/, "- evidence: [UNFILLED]"), "", "").join("\n"), /scheduled_in_feature.*missing evidence/);
  assert.match(validatePrerequisiteGapsContent(sibling.replace("slice_ref: none", "slice_ref: slice-2"), "", "").join("\n"), /must use slice_ref: none/);
});

test("prerequisite-gaps gate: catalog and requirement references are mutually complete", () => {
  const sharedCoverage = `
### Requirement: REQ-2
- requirement_summary: Reuse the shared orders surface.
- prerequisites: Orders endpoint
`;
  assert.deepEqual(validatePrerequisiteGapsContent(artifact(presentBlock, "Orders endpoint", sharedCoverage), "WHEN POST /orders", ""), []);

  const duplicate = artifact(presentBlock + presentBlock, "Orders endpoint");
  assert.match(validatePrerequisiteGapsContent(duplicate, "", "").join("\n"), /declared more than once.*Orders endpoint/);

  const dangling = artifact(presentBlock, "Missing endpoint");
  assert.match(validatePrerequisiteGapsContent(dangling, "", "").join("\n"), /does not resolve.*Missing endpoint/);

  const orphan = artifact(presentBlock + scheduledBlock, "Orders endpoint");
  assert.match(validatePrerequisiteGapsContent(orphan, "", "").join("\n"), /referenced by no requirement.*Login route/);
});

test("prerequisite-gaps gate: requirement coverage blocks carry required fields and do not contain catalog blocks", () => {
  assert.match(validatePrerequisiteGapsContent(presentBlock, "", "").join("\n"), /missing section: ## 2\. Prerequisite Catalog/);
  assert.match(validatePrerequisiteGapsContent(presentBlock, "", "").join("\n"), /missing section: ## 3\. Requirement Coverage/);
  assert.match(validatePrerequisiteGapsContent(present.replace("- requirement_summary: Exercise the covered behavior.\n", ""), "", "").join("\n"), /missing requirement_summary/);
  assert.match(validatePrerequisiteGapsContent(present.replace("- prerequisites: Orders endpoint", "- prerequisites:"), "", "").join("\n"), /missing prerequisites/);
  assert.match(validatePrerequisiteGapsContent(present.replace("- prerequisites: Orders endpoint", "- prerequisites: Orders endpoint\n- status: present_in_repo"), "", "").join("\n"), /requirement coverage restates catalog field: status/);
  const coverageEntry = `${present}\n#### Prerequisite: Ghost admin page
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Admin ghost page
- evidence: Slice adds the ghost admin page
- slice_ref: slice-99
`;
  assert.match(validatePrerequisiteGapsContent(coverageEntry, "", "").join("\n"), /outside ## 2\. Prerequisite Catalog.*Ghost admin page|Ghost admin page.*outside ## 2\. Prerequisite Catalog/);
  assert.deepEqual(extractScheduledSliceRefs(coverageEntry), ["slice-99"]);
  assert.deepEqual(extractImplementationPlanRequiredSurfaces(coverageEntry), ["Admin ghost page"]);
  assert.deepEqual(extractRequiredMissingSurfaces(coverageEntry), ["Admin ghost page"]);
});

test("prerequisite-gaps gate: literal may be covered by catalog entry or technical surface", () => {
  assert.deepEqual(validatePrerequisiteGapsContent(present, "WHEN POST /orders", ""), []);
  assert.deepEqual(validatePrerequisiteGapsContent(present, "WHEN GET /lookup", "- user_reachable_surface: GET /lookup"), []);
  assert.match(validatePrerequisiteGapsContent(present, "WHEN GET /missing", "").join("\n"), /GET \/missing/);
});

test("prerequisite-gaps gate: literal haystack includes catalog evidence and slice_ref only", () => {
  const outOfCatalog = `${present}\n## 4. Notes\n- evidence: POST /admin/reindex\n`;
  assert.match(validatePrerequisiteGapsContent(outOfCatalog, "WHEN POST /admin/reindex", "").join("\n"), /POST \/admin\/reindex/);

  const repeatedEvidence = present.replace(
    "- evidence: POST /orders",
    "- evidence: POST /admin/reindex\n- evidence: later non-literal evidence"
  );
  assert.deepEqual(validatePrerequisiteGapsContent(repeatedEvidence, "WHEN POST /admin/reindex", ""), []);
});

test("prerequisite-gaps gate: slice format only applies to scheduled_in_slices", () => {
  assert.deepEqual(validatePrerequisiteGapsContent(scheduled, "", ""), []);
  assert.match(validatePrerequisiteGapsContent(scheduled.replace("slice-1", "bad ref"), "", "").join("\n"), /required format/);
  assert.deepEqual(validatePrerequisiteGapsContent(present.replace("slice_ref: none", "slice_ref: bad ref"), "", ""), []);
});

test("prerequisite-gaps gate: runtime exit codes distinguish content and missing inputs", () => {
  const root = mkdtempSync(path.join(tmpdir(), "prereq-gate-"));
  try {
    const feature = path.join(root, "projects", "p1", "f1");
    mkdirSync(feature, { recursive: true });
    writeFileSync(path.join(feature, "requirements_ears.md"), "");
    writeFileSync(path.join(feature, "technical_requirements.md"), "");
    assert.equal(validatePrerequisiteGaps("", root).exitCode, 2);
    assert.equal(validatePrerequisiteGaps("projects/p1/f1", root).exitCode, 2);
    writeFileSync(path.join(feature, "prerequisite_gaps.md"), " \n");
    assert.equal(validatePrerequisiteGaps("projects/p1/f1", root).exitCode, 1);
    writeFileSync(path.join(feature, "prerequisite_gaps.md"), "");
    assert.equal(validatePrerequisiteGaps("projects/p1/f1", root).exitCode, 1);
    writeFileSync(path.join(feature, "prerequisite_gaps.md"), present);
    assert.equal(validatePrerequisiteGaps("projects/p1/f1", root).exitCode, 0);
    unlinkSync(path.join(feature, "requirements_ears.md"));
    assert.equal(validatePrerequisiteGaps("projects/p1/f1", root).exitCode, 2);
    writeFileSync(path.join(feature, "requirements_ears.md"), "");
    unlinkSync(path.join(feature, "technical_requirements.md"));
    assert.equal(validatePrerequisiteGaps("projects/p1/f1", root).exitCode, 2);
  } finally { rmSync(root, { recursive: true, force: true }); }
});
