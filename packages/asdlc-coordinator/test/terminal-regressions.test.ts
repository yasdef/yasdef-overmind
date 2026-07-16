import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { runFeatureFlow } from "../src/orchestrator/index.js";
import { CHECKPOINT_LABELS } from "../src/git/index.js";
import { writeFeatureState } from "../src/state/index.js";
import {
  GATE_REGISTRY,
  TERMINAL_FEATURE_GATES,
  type GateValidator
} from "../src/validate/gate-registry.js";
import { runTerminalGateChain } from "../src/validate/terminal-gate-chain.js";

import { materializeValidFeature } from "./valid-feature-fixture.js";

import {
  RecordingCheckpoint,
  StubInteraction,
  stubExecutorDeps,
  withWorkspace,
  type Workspace
} from "./orchestrator-fixtures.js";

/**
 * Terminal regressions measured on the live UMSS feature (CRP-166). Each fixture
 * keeps one real deterministic validator and stubs the rest to pass, which is
 * exactly the scenario precondition: every other applicable artifact passes its
 * gate, so the aggregate result and repair ownership are attributable to the one
 * defect under test.
 */
const pass: GateValidator = () => ({ exitCode: 0, passMessage: "ok", problems: [] });

function registryWithReal(...realGates: string[]): Record<string, GateValidator> {
  const registry: Record<string, GateValidator> = {};
  for (const definition of TERMINAL_FEATURE_GATES) {
    registry[definition.gate] = realGates.includes(definition.gate)
      ? GATE_REGISTRY[definition.gate]!
      : pass;
  }
  return registry;
}

/** A feature whose plan-gate sibling inputs are real enough to reach content checks. */
function seedPlanReadyFeature(workspace: Workspace, name: string): string {
  const featureDir = path.join(workspace.projectDir, name);
  mkdirSync(featureDir, { recursive: true });
  writeFileSync(path.join(featureDir, "requirements_ears.md"), "### Requirement 1\n### NFR 1\n");
  writeFileSync(
    path.join(featureDir, "technical_requirements.md"),
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
`
  );
  writeFileSync(
    path.join(featureDir, "prerequisite_gaps.md"),
    `#### Prerequisite: A
- status: scheduled_in_slices
- slice_ref: slice-1
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Admin login page
`
  );
  return featureDir;
}

function planSteps(): string {
  return `### Step 1.1 Deliver operator login page [REQ-1]
#### Repo: backend
#### Depends on: none
#### Evidence: gap/TECH_REQ-1, comp/backend-order-service, slice/slice-1
#### Preserved Surface: Operator sign-in screen
- [ ] Plan and discuss the step
- [ ] Implement the login endpoint
- [ ] Review step implementation

### Step 2.1 Render operator login page [NFR-1]
#### Repo: backend
#### Depends on: 1.1
#### Evidence: gap/TECH_REQ-NFR-1
#### Preserved Surface: none
- [ ] Plan and discuss the step
- [ ] Render the login screen
- [ ] Review step implementation
`;
}

// --- Measured defect 1: implementation_plan.md lost its template header ------

test("the measured header-loss plan fails the terminal chain with repair owner 8.3", async () => {
  await withWorkspace({ definition: { classes: ["backend"] } }, async (workspace) => {
    const featureDir = seedPlanReadyFeature(workspace, "umss");
    // The migrated plan begins directly with a step; everything else is valid.
    writeFileSync(path.join(featureDir, "implementation_plan.md"), planSteps());

    const failing = runTerminalGateChain(featureDir, workspace.root, {
      registry: registryWithReal("implementation-plan")
    });
    assert.equal(failing.exitCode, 1);
    assert.equal(failing.repairStep, "8.3");
    const entry = failing.entries.find((item) => item.gate === "implementation-plan")!;
    assert.deepEqual(entry.result!.problems, [
      "implementation_plan.md must start with exact header: # Implementation Plan"
    ]);

    // Restoring the exact template header clears the terminal failure.
    writeFileSync(
      path.join(featureDir, "implementation_plan.md"),
      `# Implementation Plan\n${planSteps()}`
    );
    const repaired = runTerminalGateChain(featureDir, workspace.root, {
      registry: registryWithReal("implementation-plan")
    });
    assert.equal(repaired.exitCode, 0);
    assert.equal(repaired.repairStep, undefined);
  });
});

test("the header-loss defect blocks flow completion and the completion commit boundary", async () => {
  await withWorkspace({ definition: { classes: ["backend"] } }, async (workspace) => {
    const featureDir = seedPlanReadyFeature(workspace, "umss");
    writeFileSync(path.join(featureDir, "implementation_plan.md"), planSteps());
    writeFeatureState(workspace.projectDir, path.relative(workspace.root, featureDir));

    const checkpoint = new RecordingCheckpoint();
    const lines: string[] = [];
    const outcome = await runFeatureFlow({
      workspaceRoot: workspace.root,
      projectRoot: workspace.projectDir,
      projectPathRel: workspace.projectPathRel,
      resumeInput: "8.4",
      interaction: new StubInteraction([
        "continue",
        path.relative(workspace.root, featureDir),
        false // decline the optional review
      ]),
      executorDeps: stubExecutorDeps(),
      checkpoint,
      clock: { now: () => 1 },
      overmindCliPath: path.join(workspace.root, ".overmind", "overmind.js"),
      modelsPath: path.join(workspace.root, ".setup", "models.md"),
      terminalGateChain: (featurePath, cwd) =>
        runTerminalGateChain(featurePath, cwd, {
          registry: registryWithReal("implementation-plan")
        }),
      emit: (line) => lines.push(line),
      emitError: (line) => lines.push(line)
    });

    assert.equal(outcome.kind, "failed");
    if (outcome.kind === "failed") {
      assert.equal(outcome.exitCode, 1);
      assert.equal(outcome.resumeStep, "8.3");
      assert.match(outcome.diagnostics[0]!.reason, /must start with exact header/);
    }
    assert.equal(checkpoint.labels.includes(CHECKPOINT_LABELS.featureCompletion), false);
    assert.ok(lines.every((line) => !/reached end of configured phase map/.test(line)));
  });
});

// --- Measured defect 2: invalid EARS bullets in requirements_ears.md ---------

test("the measured invalid EARS pattern fails the terminal chain with repair owner 5", async () => {
  await withWorkspace({ definition: { classes: ["backend"] } }, async (workspace) => {
    const featureDir = path.join(workspace.projectDir, "umss");
    mkdirSync(featureDir, { recursive: true });
    writeFileSync(
      path.join(featureDir, "requirements_ears.md"),
      `# Requirements (EARS)

## Requirements

### Requirement 12 - Duplicate accounts
**User Story:** As a user, I want no duplicate accounts, so that billing stays correct.

**Acceptance Criteria (EARS):**
- WHEN a duplicate account is submitted, THEN THE System SHALL reject the request.

**Verification:** API test.
`
    );
    // Downstream artifacts exist and pass their own gates.
    for (const artifact of [
      "feature_contract_delta.md",
      "technical_requirements.md",
      "implementation_slices.md",
      "prerequisite_gaps.md",
      "implementation_plan.md"
    ]) {
      writeFileSync(path.join(featureDir, artifact), `# ${artifact}\n`);
    }

    const result = runTerminalGateChain(featureDir, workspace.root, {
      registry: registryWithReal("requirements-ears")
    });

    assert.equal(result.exitCode, 1);
    assert.equal(result.repairStep, "5");
    const entry = result.entries.find((item) => item.gate === "requirements-ears")!;
    assert.equal(entry.status, "failed");
    assert.ok(entry.result!.problems.length > 0);
    // Later gates still ran, so the report is complete rather than fail-fast.
    assert.ok(
      result.entries.some((item) => item.gate === "implementation-plan" && item.status === "passed")
    );
  });
});

// --- Measured defect 3: pre-dual-source EARS review ledger -------------------

test("a pre-dual-source EARS review ledger fails terminally with repair owner 5.1", async () => {
  await withWorkspace({ definition: { classes: ["backend"] } }, async (workspace) => {
    const featureDir = path.join(workspace.projectDir, "umss");
    mkdirSync(featureDir, { recursive: true });
    writeFileSync(path.join(featureDir, "requirements_ears.md"), "# ears\n");
    // Legacy ledger: single-source meta and finding references, predating CRP-163.
    writeFileSync(
      path.join(featureDir, "requirements_ears_review.md"),
      `# Requirements EARS Extra Review

## 1. Document Meta
- feature_id: FEAT-REVIEW-001
- feature_title: Payments access review
- source_feature_br_summary: projects/p/umss/feature_br_summary.md
- source_requirements_ears: projects/p/umss/requirements_ears.md
- review_status: complete
- last_updated: 2026-04-11

## 2. Review Guidance
- completion_rule: Set review_status complete only when every finding is terminal.

## 3. Findings Ledger
### Finding 1 - ACTIVE qualifier narrows duplicate-account rule
- severity: High
- state: added to ears
- source_br_summary_reference: feature_br_summary.md -> BR-4 duplicate-account handling
- related_requirement_targets: Requirement 12
- gap_summary: Requirement 12 only blocks duplicates when the existing account is ACTIVE.
- recommendation: Remove the ACTIVE qualifier.
- suggested_ears_change: Update Requirement 12 to drop the ACTIVE guard condition.
- user_prompt: Should I add recommended changes?
- user_response: yes
- resolution_notes: Removed the ACTIVE qualifier from Requirement 12.
`
    );

    const result = runTerminalGateChain(featureDir, workspace.root, {
      registry: registryWithReal("ears-review")
    });

    assert.equal(result.exitCode, 1);
    assert.equal(result.repairStep, "5.1");
    const entry = result.entries.find((item) => item.gate === "ears-review")!;
    assert.equal(entry.status, "failed");
    // CRP-163's dual-source field diagnostics propagate; the ledger is not
    // grandfathered just because it predates the dual-source contract.
    assert.ok(
      entry.result!.problems.some((problem) => /source_user_br_input/.test(problem)),
      `expected dual-source diagnostics, got: ${entry.result!.problems.join(" | ")}`
    );
  });
});

/**
 * The stubbed-sibling fixtures above isolate one validator at a time. This one
 * runs the **real** registry over a feature whose other artifacts genuinely pass
 * their gates, so repair ownership of step `8.3` is established by the actual
 * pipeline rather than by the stubs' ordering.
 */
test("a genuinely valid feature isolates the plan-header defect to repair owner 8.3", async () => {
  await withWorkspace({ definition: { classes: ["backend"] } }, async (workspace) => {
    const featureDir = materializeValidFeature(workspace.projectDir, "umss");

    const failing = runTerminalGateChain(featureDir, workspace.root);

    assert.equal(failing.exitCode, 1);
    assert.equal(failing.repairStep, "8.3");

    // Every gate ordered before the plan either passed or was inapplicable, so
    // 8.3 is the earliest failure rather than an artifact of what was stubbed.
    const earlier = failing.entries.filter((entry) => entry.order < 11);
    assert.deepEqual(
      earlier.filter((entry) => entry.status === "failed"),
      []
    );
    assert.deepEqual(
      earlier.filter((entry) => entry.status === "passed").map((entry) => entry.gate),
      ["requirements-ears", "surface-map", "technical-requirements", "prerequisite-gaps"]
    );
    assert.deepEqual(
      failing.entries.find((entry) => entry.gate === "implementation-plan")!.result!.problems,
      ["implementation_plan.md must start with exact header: # Implementation Plan"]
    );
  });
});

test("restoring the template header lets the whole real-registry chain pass", async () => {
  await withWorkspace({ definition: { classes: ["backend"] } }, async (workspace) => {
    const featureDir = materializeValidFeature(workspace.projectDir, "umss", {
      withPlanHeader: true
    });

    const repaired = runTerminalGateChain(featureDir, workspace.root);

    assert.equal(repaired.exitCode, 0);
    assert.equal(repaired.repairStep, undefined);
    assert.equal(repaired.failed, 0);
    assert.equal(repaired.passed, 5);
  });
});
