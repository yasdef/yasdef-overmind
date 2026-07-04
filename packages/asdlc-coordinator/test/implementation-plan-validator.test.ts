import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import {
  canonicalImplementationPlanSurface,
  extractImplementationPlanRequirementRefs,
  extractImplementationPlanRequiredSurfaces,
  extractScheduledSliceRefs,
  extractTechnicalEvidenceCatalog,
  implementationPlanSurfaceMatches,
  validateImplementationPlan,
  validateImplementationPlanContent,
  type ImplementationPlanCatalogs
} from "../src/validate/implementation-plan.js";

const catalogs: ImplementationPlanCatalogs = {
  activeClasses: new Set(["backend", "frontend"]),
  requirementRefs: ["REQ-1", "NFR-1"],
  evidence: {
    reqAll: ["gap/TECH_REQ-1", "gap/TECH_REQ-NFR-1"],
    reqUnresolved: ["gap/TECH_REQ-1"],
    compAll: ["comp/backend-order-service", "comp/frontend-order-page"],
    compUnresolved: ["comp/backend-order-service", "comp/frontend-order-page"],
    repoUnresolved: ["backend", "frontend"]
  },
  scheduledSliceRefs: ["slice-1"],
  requiredSurfaces: ["Admin login page"]
};

function validPlan(): string {
  return `# Repository Implementation Plan
### Step 1.1 Deliver operator login page [REQ-1]
#### Repo: backend
#### Depends on: none
#### Evidence: gap/TECH_REQ-1, comp/backend-order-service, slice/slice-1
#### Preserved Surface: Operator sign-in screen
- [ ] Plan and discuss the step
- [ ] Implement the login endpoint
- [ ] Review step implementation

### Step 2.1 Render operator login page [NFR-1]
#### Repo: frontend
#### Depends on: 1.1
#### Evidence: gap/TECH_REQ-NFR-1, comp/frontend-order-page
#### Preserved Surface: none
- [ ] Plan and discuss the step
- [ ] Render the login screen
- [ ] Review step implementation
`;
}

test("implementation-plan gate: valid multi-repo plan and canonical surface matches pass", () => {
  assert.deepEqual(validateImplementationPlanContent(validPlan(), catalogs), []);
  assert.equal(canonicalImplementationPlanSurface("Admin sign-in screen"), "admin login page");
  assert.equal(implementationPlanSurfaceMatches("login page", "operator sign-in screen"), true);
  assert.equal(
    implementationPlanSurfaceMatches("order query CLI command", "order query admin tool command"),
    true
  );
  assert.equal(implementationPlanSurfaceMatches("admin refunds page", "admin orders page"), false);
});

test("implementation-plan gate: structural failures are reported", () => {
  const cases: Array<[string, string]> = [
    [validPlan().replace("### Step 2.1", "### Step 1.1"), "strictly increasing"],
    [validPlan().replace(" [REQ-1]", ""), "must reference at least one"],
    [validPlan().replace("[REQ-1]", "[REQ-99]"), "unknown requirement"],
    [validPlan().replace("#### Repo: backend\n", ""), "missing #### Repo"],
    [validPlan().replace("#### Repo: backend", "#### Repo: mobile"), "outside active"],
    [validPlan().replace("#### Depends on: none\n", ""), "missing #### Depends on"],
    [
      validPlan().replace(
        "#### Evidence: gap/TECH_REQ-1, comp/backend-order-service, slice/slice-1",
        "#### Evidence: gap/TECH_REQ-1\n#### Evidence: comp/backend-order-service, slice/slice-1"
      ),
      "more than once"
    ],
    [
      validPlan().replace("#### Preserved Surface: Operator sign-in screen\n", ""),
      "missing #### Preserved Surface"
    ],
    [validPlan().replace("- [ ] Implement the login endpoint\n", ""), "at least 3"],
    [validPlan().replace("Plan and discuss the step", "Discuss implementation"), "first bullet"],
    [validPlan().replace(/- \[ \] Review step implementation\n/g, ""), "Review step implementation"]
  ];
  for (const [content, expected] of cases)
    assert.ok(
      validateImplementationPlanContent(content, catalogs).some((p) => p.includes(expected)),
      expected
    );
});

test("implementation-plan gate: empty Repo and Evidence diagnostics preserve legacy message parity", () => {
  const emptyEvidence = validateImplementationPlanContent(
    validPlan().replace(
      "#### Evidence: gap/TECH_REQ-1, comp/backend-order-service, slice/slice-1",
      "#### Evidence:"
    ),
    catalogs
  );
  assert.deepEqual(
    emptyEvidence.filter((problem) => problem.includes("#### Evidence")),
    ["step 1.1 is missing #### Evidence"]
  );

  const emptyRepo = validateImplementationPlanContent(
    validPlan().replace("#### Repo: backend", "#### Repo:"),
    catalogs
  );
  assert.deepEqual(
    emptyRepo.filter((problem) => problem.includes("step 1.1") && /repo/i.test(problem)),
    [
      "step 1.1 uses repo outside active project classes: ",
      "step 1.1 has invalid repo value: ",
      "step 1.1 is missing #### Repo"
    ]
  );
});

test("implementation-plan gate: dependency and evidence token failures are reported", () => {
  const cases: Array<[string, string]> = [
    [validPlan().replace("#### Depends on: 1.1", "#### Depends on: 9.9"), "unknown or later"],
    [validPlan().replace("#### Depends on: 1.1", "#### Depends on: 2.1"), "unknown or later"],
    [
      validPlan().replace("#### Depends on: 1.1", "#### Depends on: ../1.1"),
      "invalid cross-feature"
    ],
    [
      validPlan().replace("#### Depends on: 1.1", "#### Depends on: 1.1, 1.1"),
      "repeats dependency"
    ],
    [validPlan().replace("gap/TECH_REQ-1", "gap/TECH_REQ-99"), "unknown evidence"],
    [validPlan().replace("comp/backend-order-service", "comp/missing"), "unknown evidence"],
    [
      validPlan().replace("gap/TECH_REQ-1, comp/backend-order-service, slice/slice-1", "bad-token"),
      "invalid evidence token"
    ],
    [
      validPlan().replace(
        "gap/TECH_REQ-1, comp/backend-order-service, slice/slice-1",
        "gap/TECH_REQ-1,"
      ),
      "empty evidence token"
    ],
    [
      validPlan().replace(
        "gap/TECH_REQ-1, comp/backend-order-service, slice/slice-1",
        "gap/TECH_REQ-1, gap/TECH_REQ-1"
      ),
      "repeats evidence token"
    ]
  ];
  for (const [content, expected] of cases)
    assert.ok(
      validateImplementationPlanContent(content, catalogs).some((p) => p.includes(expected)),
      expected
    );
  assert.deepEqual(
    validateImplementationPlanContent(
      validPlan().replace("#### Depends on: 1.1", "#### Depends on: sibling-feature/1.1"),
      catalogs
    ),
    []
  );
});

test("implementation-plan gate: whole-plan coverage and preserved surfaces are enforced", () => {
  const cases: Array<[string, ImplementationPlanCatalogs, string]> = [
    [validPlan().replace("# Repository", "# [UNFILLED] Repository"), catalogs, "[UNFILLED]"],
    ["# empty plan\n", catalogs, "at least one step"],
    [validPlan().replace("#### Repo: frontend", "#### Repo: backend"), catalogs, "repo frontend"],
    [validPlan().replace("[NFR-1]", "[REQ-1]"), catalogs, "NFR-1"],
    [validPlan().replace("gap/TECH_REQ-1, ", ""), catalogs, "unresolved requirement"],
    [
      validPlan().replace("comp/frontend-order-page", "gap/TECH_REQ-NFR-1"),
      catalogs,
      "unresolved component"
    ],
    [validPlan().replace(", slice/slice-1", ""), catalogs, "scheduled prerequisite"],
    [validPlan().replace("Operator sign-in screen", "none"), catalogs, "not preserved"]
  ];
  for (const [content, input, expected] of cases)
    assert.ok(
      validateImplementationPlanContent(content, input).some((p) => p.includes(expected)),
      expected
    );
  const coordination = validPlan().replace(
    "#### Preserved Surface: Operator sign-in screen",
    "#### Preserved Surface: Operator sign-in screen\n#### Coordination: true"
  );
  assert.ok(
    validateImplementationPlanContent(coordination, catalogs).some((p) =>
      p.includes("no non-coordination")
    )
  );
  const beside = coordination.replace(
    "#### Preserved Surface: none",
    "#### Preserved Surface: Admin login page"
  );
  assert.deepEqual(validateImplementationPlanContent(beside, catalogs), []);
});

test("implementation-plan gate: catalog extractors preserve section and heading scope", () => {
  assert.deepEqual(
    extractImplementationPlanRequirementRefs(
      "### Requirement 1 text\nbody REQ-9\n### NFR 2 [REQ-3]\n"
    ),
    ["REQ-1", "NFR-2", "REQ-3"]
  );
  const technical = `## 4. Requirement Coverage and Gaps
### Requirement: REQ-1
- gap_status: pending
- gap_to_close: implement
### Requirement: NFR-1
- gap_status: fully_implemented
- gap_to_close: none
## 5. Impacted Components
### Component: Backend Order Service
- repo: backend
- gap_to_close: implement
### Component: Existing Page
- repo: frontend
- gap_to_close: no remaining gap
`;
  assert.deepEqual(extractTechnicalEvidenceCatalog(technical), {
    reqAll: ["gap/TECH_REQ-1", "gap/TECH_REQ-NFR-1"],
    reqUnresolved: ["gap/TECH_REQ-1"],
    compAll: ["comp/backend-order-service", "comp/existing-page"],
    compUnresolved: ["comp/backend-order-service"],
    repoUnresolved: ["backend"]
  });
  const prereq = `## 2. Prerequisite Catalog
#### Prerequisite: Shared login surface
- status: scheduled_in_slices
- slice_ref: slice-1
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Admin login page
#### Prerequisite: Existing page
- status: present_in_repo
- slice_ref: none
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Existing page
## 3. Requirement Coverage
### Requirement: REQ-1
- requirement_summary: First behavior uses login.
- prerequisites: Shared login surface
### Requirement: REQ-2
- requirement_summary: Second behavior shares login and uses the existing page.
- prerequisites: Shared login surface; Existing page
`;
  assert.deepEqual(extractScheduledSliceRefs(prereq), ["slice-1"]);
  assert.deepEqual(extractImplementationPlanRequiredSurfaces(prereq), ["Admin login page"]);
});

test("implementation-plan gate: scheduled slice_ref extraction is independent of field order", () => {
  const prereq = `#### Prerequisite: Reordered fields
- slice_ref: slice-9
- surface_kind: transport_or_internal_execution_gap
- status: scheduled_in_slices
- surface_identity: none
`;
  assert.deepEqual(extractScheduledSliceRefs(prereq), ["slice-9"]);
});

function fixture(root: string): { project: string; feature: string } {
  const project = path.join(root, "projects", "p1");
  const feature = path.join(project, "feature-a");
  mkdirSync(feature, { recursive: true });
  writeFileSync(
    path.join(project, "init_progress_definition.yaml"),
    "meta_info:\n  project_classes: [backend, frontend, infrastructure]\nsteps: []\n"
  );
  writeFileSync(path.join(feature, "requirements_ears.md"), "### Requirement 1\n### NFR 1\n");
  writeFileSync(
    path.join(feature, "technical_requirements.md"),
    `## 4. Requirement Coverage and Gaps
### Requirement: REQ-1
- gap_status: pending
- gap_to_close: implement
### Requirement: NFR-1
- gap_status: fully_implemented
- gap_to_close: none
## 5. Impacted Components
### Component: Backend Order Service
- repo: backend
- gap_to_close: implement
### Component: Frontend Order Page
- repo: frontend
- gap_to_close: implement
`
  );
  writeFileSync(
    path.join(feature, "prerequisite_gaps.md"),
    `#### Prerequisite: A
- status: scheduled_in_slices
- slice_ref: slice-1
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Admin login page
`
  );
  writeFileSync(path.join(feature, "implementation_plan.md"), validPlan());
  return { project, feature };
}

test("implementation-plan gate: runtime exit codes and required inputs", () => {
  let root = mkdtempSync(path.join(tmpdir(), "plan-gate-"));
  try {
    const { feature } = fixture(root);
    assert.equal(validateImplementationPlan("projects/p1/feature-a", root).exitCode, 0);
    writeFileSync(path.join(feature, "implementation_plan.md"), " \n");
    assert.equal(validateImplementationPlan("projects/p1/feature-a", root).exitCode, 1);
    unlinkSync(path.join(feature, "implementation_plan.md"));
    assert.equal(validateImplementationPlan("projects/p1/feature-a", root).exitCode, 2);
    assert.equal(validateImplementationPlan("", root).exitCode, 2);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
  for (const missing of [
    "requirements_ears.md",
    "technical_requirements.md",
    "prerequisite_gaps.md",
    "definition"
  ]) {
    root = mkdtempSync(path.join(tmpdir(), "plan-gate-missing-"));
    try {
      const { project, feature } = fixture(root);
      unlinkSync(
        missing === "definition"
          ? path.join(project, "init_progress_definition.yaml")
          : path.join(feature, missing)
      );
      assert.equal(validateImplementationPlan("projects/p1/feature-a", root).exitCode, 2, missing);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  }
});
