import { mkdirSync, mkdtempSync, rmSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import type { RequiredSurface } from "../src/validate/implementation-slices.js";
import {
  extractRequiredMissingSurfaces,
  validateImplementationSlices,
  validateImplementationSlicesContent
} from "../src/validate/implementation-slices.js";

const ACTIVE = new Set(["backend", "frontend"]);

function validArtifact(): string {
  return `# Implementation Slices

## 1. Document Meta
- feature_id: ORD-42
- feature_title: order-projection-refresh
- project_type_code: B
- source_requirements_ears: requirements_ears.md
- source_technical_requirements: technical_requirements.md
- source_feature_contract_delta: feature_contract_delta.md
- source_surface_map_artifacts: backend.md, frontend.md
- analyzed_repo_classes: backend, frontend
- ordering_scope: local_prerequisites_only
- traceability_scope: slice_level_only
- last_updated: 2026-07-01
- confidence_level: medium

## 2. Slice Planning Guardrails
- objective: Discover executable slices.

## 3. Slice Candidates
### Slice 1: Backend query endpoint
- repo: backend
- status: planned
- objective: Deliver the order query endpoint.
- first_increment: Operator can call the order query endpoint.
- prerequisites: none
- evidence: gap/TECH_REQ-6, comp/backend-order-service
- [ ] Implement the endpoint
- [ ] Add endpoint tests

### Slice 2: Frontend order page
- repo: frontend
- status: existing
- objective: Keep the order page available.
- first_increment: Operator sees order state on the page.
- prerequisites: none
- evidence: gap/TECH_REQ-NFR-1, comp/frontend-order-page
- [ ] Verify page rendering
- [x] Verify page navigation

## 4. Handoff To Ordered Plan
- ordering_intent: Backend before frontend integration.
- unresolved_ordering_questions: none
- unresolved_traceability_questions: none
`;
}

function problems(content: string, required: RequiredSurface[] = []): string[] {
  return validateImplementationSlicesContent(content, ACTIVE, required);
}

function removeLine(content: string, key: string): string {
  return content.replace(new RegExp(`^- ${key}:.*\\n`, "m"), "");
}

test("implementation-slices gate: valid artifact passes", () => {
  assert.deepEqual(problems(validArtifact()), []);
});

test("implementation-slices gate: all sections and meta keys are required", () => {
  for (const heading of [
    "## 1. Document Meta",
    "## 2. Slice Planning Guardrails",
    "## 3. Slice Candidates",
    "## 4. Handoff To Ordered Plan"
  ]) {
    assert.ok(
      problems(validArtifact().replace(heading, `${heading} renamed`)).some((p) =>
        p.includes("missing section")
      ),
      heading
    );
  }
  for (const key of [
    "feature_id",
    "feature_title",
    "project_type_code",
    "source_requirements_ears",
    "source_technical_requirements",
    "source_feature_contract_delta",
    "source_surface_map_artifacts",
    "analyzed_repo_classes",
    "ordering_scope",
    "traceability_scope",
    "last_updated",
    "confidence_level"
  ])
    assert.ok(
      problems(removeLine(validArtifact(), key)).some((p) => p.includes(key)),
      key
    );
  assert.ok(
    problems(
      validArtifact().replace("ordering_scope: local_prerequisites_only", "ordering_scope: global")
    ).some((p) => p.includes("ordering_scope"))
  );
  assert.ok(
    problems(
      validArtifact().replace("traceability_scope: slice_level_only", "traceability_scope: full")
    ).some((p) => p.includes("traceability_scope"))
  );
});

test("implementation-slices gate: slice existence, planned status, and fields are enforced", () => {
  const noSlices = validArtifact().replace(/### Slice 1:[\s\S]*?(?=\n## 4\.)/, "");
  assert.ok(problems(noSlices).some((p) => p.includes("at least one Slice block")));
  assert.ok(
    problems(validArtifact().replace(/status: planned/g, "status: existing")).some((p) =>
      p.includes("at least one planned slice")
    )
  );
  for (const key of [
    "repo",
    "status",
    "objective",
    "first_increment",
    "prerequisites",
    "evidence"
  ]) {
    const broken = validArtifact().replace(
      new RegExp(`(### Slice 1:[\\s\\S]*?)- ${key}:.*\\n`),
      "$1"
    );
    assert.ok(
      problems(broken).some((p) => p.includes(`slice 1 missing or unfilled key: ${key}`)),
      key
    );
  }
  assert.ok(
    problems(validArtifact().replace("repo: backend", "repo: mobile")).some((p) =>
      p.includes("outside active project classes")
    )
  );
  assert.ok(
    problems(validArtifact().replace("status: planned", "status: pending")).some((p) =>
      p.includes("invalid status")
    )
  );
});

test("implementation-slices gate: evidence, checklist, boilerplate, and coordination rules are enforced", () => {
  assert.ok(
    problems(
      validArtifact().replace("gap/TECH_REQ-6, comp/backend-order-service", "TECH_REQ-6")
    ).some((p) => p.includes("invalid evidence token"))
  );
  assert.ok(
    problems(
      validArtifact().replace("gap/TECH_REQ-6, comp/backend-order-service", "gap/TECH_REQ-6,")
    ).some((p) => p.includes("empty evidence token"))
  );
  assert.ok(
    problems(validArtifact().replace("- [ ] Add endpoint tests\n", "")).some((p) =>
      p.includes("at least 2")
    )
  );
  for (const literal of ["Plan and discuss the slice", "Review slice readiness"]) {
    assert.ok(
      problems(validArtifact().replace("Implement the endpoint", literal)).some((p) =>
        p.includes(literal)
      )
    );
  }
  const coordination = validArtifact().replace(
    "- objective: Deliver the order query endpoint.",
    "- kind: coordination\n- signal_ref: signal-1\n- objective: Deliver the order query endpoint."
  );
  assert.deepEqual(problems(coordination), []);
  assert.ok(
    problems(coordination.replace("- signal_ref: signal-1\n", "")).some((p) =>
      p.includes("signal_ref")
    )
  );
  assert.deepEqual(problems(validArtifact()), []);
});

test("implementation-slices gate: a required surface is covered by its resolved slice link", () => {
  assert.deepEqual(
    problems(validArtifact(), [{ surface: "Order query endpoint", sliceRef: "slice-1" }]),
    []
  );
  assert.deepEqual(
    problems(validArtifact(), [{ surface: "Admin refunds page", sliceRef: "slice-2" }]),
    []
  );
});

test("implementation-slices gate: an unresolved or unusable slice link fails", () => {
  const unresolved = problems(validArtifact(), [
    { surface: "Admin refunds page", sliceRef: "slice-9" }
  ]);
  assert.ok(
    unresolved.some((p) => p.includes("Admin refunds page") && p.includes("slice-9")),
    unresolved.join("\n")
  );
  for (const sliceRef of ["", "none", "Slice 2", "frontend-shell"]) {
    const unusable = problems(validArtifact(), [{ surface: "Admin refunds page", sliceRef }]);
    assert.ok(
      unusable.some((p) => p.includes("unusable slice_ref") && p.includes("Admin refunds page")),
      sliceRef
    );
  }
});

test("implementation-slices gate: a slice worded as supporting work still covers a surface whose link resolves", () => {
  const supporting = validArtifact()
    .replace("### Slice 1: Backend query endpoint", "### Slice 1: Auth middleware")
    .replace("Deliver the order query endpoint.", "Add auth token middleware.")
    .replace("Operator can call the order query endpoint.", "Token state and middleware are ready.")
    .replace("Implement the endpoint", "Implement auth middleware")
    .replace("Add endpoint tests", "Add token adapter tests");
  assert.deepEqual(
    problems(supporting, [{ surface: "Admin refunds page", sliceRef: "slice-1" }]),
    []
  );
  assert.deepEqual(problems(supporting), []);
});

test("implementation-slices gate: a slice naming an HTTP method and path as its first increment covers its resolved surface", () => {
  const measured = validArtifact().replace(
    "- first_increment: Operator sees order state on the page.",
    "- first_increment: `POST /api/v1/telegram-identities` accepts valid new users, persists USER identities, and reuses existing identities without profile overwrite"
  );
  assert.deepEqual(
    problems(measured, [{ surface: "POST /api/v1/telegram-identities", sliceRef: "slice-2" }]),
    []
  );
});

test("implementation-slices gate: a link resolves by declared heading number, not position", () => {
  const shuffled = validArtifact().replace(
    "### Slice 1: Backend query endpoint",
    "### Slice 5: Backend query endpoint"
  );
  assert.deepEqual(
    problems(shuffled, [{ surface: "Order query endpoint", sliceRef: "slice-5" }]),
    []
  );
  assert.ok(
    problems(shuffled, [{ surface: "Order query endpoint", sliceRef: "slice-1" }]).some((p) =>
      p.includes("not declared")
    )
  );
});

test("implementation-slices gate: duplicate declared slice numbers fail and resolve nothing", () => {
  const duplicated = validArtifact().replace(
    "### Slice 1: Backend query endpoint",
    "### Slice 2: Backend query endpoint"
  );
  assert.deepEqual(problems(duplicated), ["slice candidates declare duplicate slice number: 2"]);
  assert.deepEqual(
    problems(duplicated, [{ surface: "Order query endpoint", sliceRef: "slice-2" }]),
    ["slice candidates declare duplicate slice number: 2"]
  );
});

test("implementation-slices gate: no required surfaces means no coverage failure", () => {
  assert.deepEqual(problems(validArtifact(), []), []);
  assert.deepEqual(
    extractRequiredMissingSurfaces(`## 2. Prerequisite Catalog
#### Prerequisite: Existing page
- status: present_in_repo
- surface_kind: present_user_reachable_surface
- surface_identity: none
- slice_ref: none
#### Prerequisite: Sibling surface
- status: scheduled_in_feature feature-b/8.1
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Sibling admin page
- slice_ref: none
`),
    []
  );
});

test("implementation-slices gate: measured four-surface regression passes on resolved links", () => {
  const slice = (number: number, title: string, surface: string): string =>
    `### Slice ${number}: ${title}
- repo: frontend
- status: planned
- objective: Deliver the ${surface} so operators can reach it.
- first_increment: Operator opens the ${surface} and sees live state.
- prerequisites: none
- evidence: gap/TECH_REQ-4, comp/frontend-order-page
- [ ] Deliver the ${surface} route and initial render path
- [ ] Add focused coverage for the ${surface}
`;
  const artifact = validArtifact().replace(
    /### Slice 2: Frontend order page[\s\S]*?(?=\n## 4\.)/,
    [
      slice(3, "Operator workspace shell", "protected operator workspace shell"),
      slice(4, "Admin refunds page", "admin refunds page"),
      slice(5, "Operator account lookup page", "operator account lookup page"),
      slice(7, "Admin order detail page", "admin order detail page")
    ].join("\n")
  );
  assert.deepEqual(
    problems(artifact, [
      { surface: "Protected operator workspace shell", sliceRef: "slice-3" },
      { surface: "Admin refunds page", sliceRef: "slice-4" },
      { surface: "Operator account lookup page", sliceRef: "slice-5" },
      { surface: "Admin order detail page", sliceRef: "slice-7" }
    ]),
    []
  );
});

test("implementation-slices gate: handoff keys and structured UNFILLED placeholders are rejected", () => {
  for (const key of [
    "ordering_intent",
    "unresolved_ordering_questions",
    "unresolved_traceability_questions"
  ]) {
    assert.ok(
      problems(removeLine(validArtifact(), key)).some((p) => p.includes(key)),
      key
    );
  }
  assert.ok(
    problems(validArtifact().replace("feature_id: ORD-42", "feature_id: [UNFILLED]")).some((p) =>
      p.includes("[UNFILLED]")
    )
  );
  assert.ok(
    problems(
      validArtifact().replace(
        "### Slice 1: Backend query endpoint",
        "### Slice 1: [UNFILLED title]"
      )
    ).some((p) => p.includes("[UNFILLED]"))
  );
  assert.ok(
    problems(
      validArtifact().replace("Implement the endpoint", "[UNFILLED concrete implementation slice]")
    ).some((p) => p.includes("[UNFILLED]"))
  );
});

test("implementation-slices gate: UNFILLED marker references in prose are allowed", () => {
  const prose = validArtifact()
    .replace("Deliver the order query endpoint.", "Replace [UNFILLED] markers left by upstream.")
    .replace("Implement the endpoint", "Replace [UNFILLED] markers left by upstream");
  assert.deepEqual(problems(prose), []);
});

test("implementation-slices gate: prerequisite parser selects required missing surfaces from the catalog format", () => {
  const input = `## 2. Prerequisite Catalog
#### Prerequisite: Refunds surface
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Admin refunds page
- slice_ref: slice-2
#### Prerequisite: Existing page
- status: present_in_repo
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Existing page
#### Prerequisite: Operator surface
- status: unmet
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Operator command
## 3. Requirement Coverage
### Requirement: REQ-1
- requirement_summary: Uses both missing surfaces.
- prerequisites: Refunds surface; Operator surface
### Requirement: REQ-2
- requirement_summary: Shares the refunds surface.
- prerequisites: Refunds surface
`;
  assert.deepEqual(extractRequiredMissingSurfaces(input), [
    { surface: "Admin refunds page", sliceRef: "slice-2" }
  ]);
});

function fixture(root: string): { project: string; feature: string } {
  const project = path.join(root, "projects", "p1");
  const feature = path.join(project, "feature-a");
  mkdirSync(feature, { recursive: true });
  writeFileSync(
    path.join(project, "init_progress_definition.yaml"),
    "meta_info:\n  project_classes: [backend, frontend, infrastructure]\nsteps: []\n"
  );
  for (const file of [
    "requirements_ears.md",
    "technical_requirements.md",
    "feature_contract_delta.md"
  ])
    writeFileSync(path.join(feature, file), `${file}\n`);
  writeFileSync(path.join(feature, "implementation_slices.md"), validArtifact());
  return { project, feature };
}

test("implementation-slices gate: runtime exit codes preserve helper parity", () => {
  const root = mkdtempSync(path.join(tmpdir(), "slices-gate-"));
  try {
    const { feature } = fixture(root);
    assert.equal(validateImplementationSlices("projects/p1/feature-a", root).exitCode, 0);
    writeFileSync(path.join(feature, "implementation_slices.md"), " \n");
    assert.equal(validateImplementationSlices("projects/p1/feature-a", root).exitCode, 1);
    unlinkSync(path.join(feature, "implementation_slices.md"));
    assert.equal(validateImplementationSlices("projects/p1/feature-a", root).exitCode, 2);
    assert.equal(validateImplementationSlices("", root).exitCode, 2);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("implementation-slices gate: missing siblings, definition, and supported classes exit 2", () => {
  for (const missing of [
    "requirements_ears.md",
    "technical_requirements.md",
    "feature_contract_delta.md",
    "definition",
    "classes"
  ]) {
    const root = mkdtempSync(path.join(tmpdir(), "slices-gate-missing-"));
    try {
      const { project, feature } = fixture(root);
      if (missing === "definition") unlinkSync(path.join(project, "init_progress_definition.yaml"));
      else if (missing === "classes")
        writeFileSync(
          path.join(project, "init_progress_definition.yaml"),
          "meta_info:\n  project_classes: [infrastructure]\nsteps: []\n"
        );
      else unlinkSync(path.join(feature, missing));
      assert.equal(
        validateImplementationSlices("projects/p1/feature-a", root).exitCode,
        2,
        missing
      );
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  }
});

test("implementation-slices gate: optional prerequisite gaps activates cross-check", () => {
  const root = mkdtempSync(path.join(tmpdir(), "slices-gate-prereq-"));
  const gaps = (sliceRef: string): string =>
    `#### Prerequisite: Required\n- status: scheduled_in_slices\n- surface_kind: required_missing_user_reachable_surface\n- surface_identity: Admin refunds page\n- slice_ref: ${sliceRef}\n`;
  try {
    const { feature } = fixture(root);
    assert.equal(validateImplementationSlices("projects/p1/feature-a", root).exitCode, 0);
    writeFileSync(path.join(feature, "prerequisite_gaps.md"), gaps("slice-9"));
    assert.equal(validateImplementationSlices("projects/p1/feature-a", root).exitCode, 1);
    writeFileSync(path.join(feature, "prerequisite_gaps.md"), gaps("slice-2"));
    assert.equal(validateImplementationSlices("projects/p1/feature-a", root).exitCode, 0);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
