import { mkdirSync, mkdtempSync, rmSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { validateTechnicalRequirements, validateTechnicalRequirementsContent } from "../src/validate/technical-requirements.js";

const ACTIVE = new Set(["backend", "frontend"]);
const REFS = new Set(["REQ-1", "NFR-1"]);
const REQUIRED_REPOS = new Set(["backend", "frontend"]);

function validArtifact(): string {
  return `# Technical Requirements

## 1. Document Meta
- feature_id: F-1
- feature_title: Feature
- project_type_code: B
- source_requirements_ears: requirements_ears.md
- source_common_contract_definition: common_contract_definition.md
- source_surface_map_artifacts: backend.md, frontend.md
- analyzed_repo_classes: backend, frontend
- last_updated: 2026-06-30
- confidence_level: high

## 2. Feature Scope and Inputs
- feature_summary: Summary
- included_behavior: Included
- excluded_behavior: Excluded

## 3. Repository Evidence
### Repository: Backend
- class: backend
- evidence_scope: API
- primary_paths: src/api
- key_findings: Exists
- constraints: Stable
- open_gaps: none

### Repository: Frontend
- class: frontend
- evidence_scope: UI
- primary_paths: src/ui
- key_findings: Exists
- constraints: Stable
- open_gaps: none

## 4. Requirement Coverage and Gaps
### Requirement: REQ-1
- requirement_summary: Do thing
- transport_layer: Service.call
- user_reachable_surface: POST /things
- gap_status: fully_implemented
- repo_impact: backend
- evidence: src/api
- gap_to_close: none

### Requirement: NFR-1
- requirement_summary: Fast
- transport_layer: client.call
- user_reachable_surface: Page
- gap_status: partially_implemented
- repo_impact: multiple
- evidence: src/ui
- gap_to_close: add test

## 5. Impacted Components
### Component: Thing Service
- repo: backend
- component_kind: service
- relevant_paths: src/service
- requirement_refs: REQ-1
- current_state: exists
- required_behavior: stable
- gap_to_close: none
- dependency_notes: none
- evidence: src/service

### Component: Thing Page
- repo: frontend
- component_kind: ui
- relevant_paths: src/ui
- requirement_refs: NFR-1
- current_state: partial
- required_behavior: fast
- gap_to_close: test
- dependency_notes: backend
- evidence: src/ui

## 6. Cross-Repo Constraints and Planning Signals
- planning_signals: none

## 7. Known Risks / Uncertainties
- risk_1: Timing uncertainty
`;
}

function problems(content: string, active = ACTIVE, refs = REFS, repos = REQUIRED_REPOS): string[] {
  return validateTechnicalRequirementsContent(content, active, refs, repos);
}

function removeLine(content: string, key: string): string {
  return content.replace(new RegExp(`^- ${key}:.*\\n`, "m"), "");
}

test("technical-requirements gate: complete seven-section artifact passes", () => {
  assert.deepEqual(problems(validArtifact()), []);
});

test("technical-requirements gate: section headings retain bash whitespace tolerance", () => {
  const variants = new Map([
    ["## 1. Document Meta", "##  1.\tDocument  Meta"],
    ["## 2. Feature Scope and Inputs", "##\t2.  Feature\tScope  and\tInputs"],
    ["## 3. Repository Evidence", "## 3.\tRepository  Evidence"],
    ["## 4. Requirement Coverage and Gaps", "##\t4. Requirement\tCoverage  and Gaps"],
    ["## 5. Impacted Components", "##  5.\tImpacted  Components"],
    ["## 6. Cross-Repo Constraints and Planning Signals", "##\t6. Cross-Repo\tConstraints  and Planning\tSignals"],
    ["## 7. Known Risks / Uncertainties", "## 7.  Known\tRisks/Uncertainties"]
  ]);
  let artifact = validArtifact();
  for (const [canonical, variant] of variants) artifact = artifact.replace(canonical, variant);
  assert.deepEqual(problems(artifact), []);
});

test("technical-requirements gate: all seven sections are required", () => {
  for (const heading of [
    "## 1. Document Meta", "## 2. Feature Scope and Inputs", "## 3. Repository Evidence",
    "## 4. Requirement Coverage and Gaps", "## 5. Impacted Components",
    "## 6. Cross-Repo Constraints and Planning Signals", "## 7. Known Risks / Uncertainties"
  ]) {
    assert.ok(problems(validArtifact().replace(heading, `${heading} renamed`)).some((p) => p.includes(`missing section ${heading.slice(3)}`)), heading);
  }
});

test("technical-requirements gate: all section 1 and 2 scalar keys are required", () => {
  for (const key of ["feature_id", "feature_title", "project_type_code", "source_requirements_ears", "source_common_contract_definition", "source_surface_map_artifacts", "analyzed_repo_classes", "last_updated", "confidence_level"]) {
    assert.ok(problems(removeLine(validArtifact(), key)).some((p) => p.includes(`section 1 key ${key}`)), key);
  }
  for (const key of ["feature_summary", "included_behavior", "excluded_behavior"]) {
    assert.ok(problems(removeLine(validArtifact(), key)).some((p) => p.includes(`section 2 key ${key}`)), key);
  }
});

test("technical-requirements gate: repository coverage and every block field are required", () => {
  const withoutFrontend = validArtifact().replace(/\n### Repository: Frontend[\s\S]*?(?=\n## 4\.)/, "");
  assert.ok(problems(withoutFrontend).some((p) => p.includes("active repo class frontend")));
  for (const key of ["class", "evidence_scope", "primary_paths", "key_findings", "constraints", "open_gaps"]) {
    const broken = validArtifact().replace(new RegExp(`(### Repository: Backend[\\s\\S]*?)- ${key}:.*\\n`), `$1`);
    assert.ok(problems(broken).some((p) => p.includes(`repository Backend has unfilled key ${key}`)), key);
  }
});

test("technical-requirements gate: requirement coverage, split, and enums are enforced", () => {
  const missingNfr = validArtifact().replace(/\n### Requirement: NFR-1[\s\S]*?(?=\n## 5\.)/, "");
  assert.ok(problems(missingNfr).some((p) => p.includes("missing requirement block for NFR-1")));
  assert.ok(problems(validArtifact().replace("- transport_layer: Service.call", "- current_state: Service and route exist")).some((p) => p.includes("conflated current_state")));
  for (const key of ["transport_layer", "user_reachable_surface"]) {
    const broken = validArtifact().replace(new RegExp(`(### Requirement: REQ-1[\\s\\S]*?)- ${key}:.*\\n`), `$1`);
    assert.ok(problems(broken).some((p) => p.includes(`missing ${key} subfield`)), key);
  }
  assert.ok(problems(validArtifact().replace("gap_status: fully_implemented", "gap_status: unknown")).some((p) => p.includes("invalid gap_status")));
  assert.ok(problems(validArtifact().replace("repo_impact: backend", "repo_impact: infrastructure")).some((p) => p.includes("invalid repo_impact")));
});

test("technical-requirements gate: component allocation, kinds, and references are enforced", () => {
  const withoutFrontendComponent = validArtifact().replace(/\n### Component: Thing Page[\s\S]*?(?=\n## 6\.)/, "");
  assert.ok(problems(withoutFrontendComponent).some((p) => p.includes("repo frontend has applicable touched surfaces")));
  assert.ok(problems(validArtifact().replace("component_kind: service", "component_kind: handler")).some((p) => p.includes("invalid component_kind")));
  assert.ok(problems(validArtifact().replace("requirement_refs: REQ-1", "requirement_refs: REQ-99")).some((p) => p.includes("unknown requirement id REQ-99")));
});

test("technical-requirements gate: section 6 accepts one shape and validates signals", () => {
  const signal = `### Planning Signal: PS-1
- signal_id: PS-1
- signal_type: cross_repo_contract_lock
- owner_repo: backend
- consumer_repos: frontend
- required_artifact: contract.md
- must_precede: plan.md
- output_requirements: lock schema
- source_evidence: REQ-1, comp/thing-service`;
  assert.deepEqual(problems(validArtifact().replace("- planning_signals: none", signal)), []);
  assert.ok(problems(validArtifact().replace("- planning_signals: none", "- constraint_1: legacy")).some((p) => p.includes("retired loose-entry")));
  assert.ok(problems(validArtifact().replace("- planning_signals: none", "")).some((p) => p.includes("section 6 must contain")));
  assert.ok(problems(validArtifact().replace("- planning_signals: none", `- planning_signals: none\n${signal}`)).some((p) => p.includes("cannot mix")));
  assert.ok(problems(validArtifact().replace("- planning_signals: none", signal.replace("cross_repo_contract_lock", "optional"))).some((p) => p.includes("unsupported signal_type")));
  assert.ok(problems(validArtifact().replace("- planning_signals: none", signal.replace("owner_repo: backend", "owner_repo: infrastructure"))).some((p) => p.includes("owner_repo")));
  assert.ok(problems(validArtifact().replace("- planning_signals: none", signal.replace("consumer_repos: frontend", "consumer_repos: infrastructure"))).some((p) => p.includes("consumer_repos")));
  assert.ok(problems(validArtifact().replace("- planning_signals: none", `${signal}\n\n${signal}`)).some((p) => p.includes("duplicate planning signal id")));
  assert.ok(problems(validArtifact().replace("- planning_signals: none", signal.replace("comp/thing-service", "comp/missing"))).some((p) => p.includes("unknown source_evidence token comp/missing")));
});

test("technical-requirements gate: risks and placeholders are enforced", () => {
  assert.ok(problems(removeLine(validArtifact(), "risk_1")).some((p) => p.includes("at least one explicit risk")));
  assert.ok(problems(validArtifact().replace("- feature_id: F-1", "- feature_id: [UNFILLED]")).some((p) => p.includes("[UNFILLED]")));
});

function fixture(root: string): { project: string; feature: string } {
  const project = path.join(root, "projects", "p1");
  const feature = path.join(project, "feature-a");
  mkdirSync(feature, { recursive: true });
  writeFileSync(path.join(project, "init_progress_definition.yaml"), "meta_info:\n  project_classes: [backend, infrastructure]\nsteps: []\n");
  writeFileSync(path.join(feature, "requirements_ears.md"), "### Requirement 1\n### NFR 1\n");
  writeFileSync(path.join(feature, "technical_requirements.md"), validArtifact().replace(/\n### Repository: Frontend[\s\S]*?(?=\n## 4\.)/, "").replace(/\n### Component: Thing Page[\s\S]*?(?=\n## 6\.)/, ""));
  writeFileSync(path.join(feature, "project_surface_struct_resp_map_backend.md"), "- applicability: applicable\n");
  return { project, feature };
}

test("technical-requirements gate: runtime success, empty target, and missing argument exit codes", () => {
  const root = mkdtempSync(path.join(tmpdir(), "technical-gate-"));
  try {
    const { feature } = fixture(root);
    assert.equal(validateTechnicalRequirements("projects/p1/feature-a", root).exitCode, 0);
    writeFileSync(path.join(feature, "technical_requirements.md"), "");
    assert.equal(validateTechnicalRequirements("projects/p1/feature-a", root).exitCode, 1);
    assert.equal(validateTechnicalRequirements("", root).exitCode, 2);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("technical-requirements gate: missing runtime siblings and surface map exit 2", () => {
  for (const missing of ["definition", "requirements", "surface"] as const) {
    const root = mkdtempSync(path.join(tmpdir(), `technical-gate-${missing}-`));
    try {
      const { project, feature } = fixture(root);
      if (missing === "definition") unlinkSync(path.join(project, "init_progress_definition.yaml"));
      if (missing === "requirements") unlinkSync(path.join(feature, "requirements_ears.md"));
      if (missing === "surface") unlinkSync(path.join(feature, "project_surface_struct_resp_map_backend.md"));
      const result = validateTechnicalRequirements("projects/p1/feature-a", root);
      assert.equal(result.exitCode, 2, missing);
      assert.match(result.errorMessage ?? "", missing === "definition" ? /init_progress_definition/ : missing === "requirements" ? /requirements_ears/ : /surface-map/);
    } finally { rmSync(root, { recursive: true, force: true }); }
  }
});
