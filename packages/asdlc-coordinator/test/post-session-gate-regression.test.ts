import { writeFileSync } from "node:fs";
import path from "node:path";
import assert from "node:assert/strict";
import test from "node:test";

import { StubAgentRunner } from "../src/runner/agent-runner.js";
import {
  defaultStepExecutorDeps,
  executeStep,
  type StepExecutorDeps
} from "../src/runner/index.js";
import { STEP_CATALOG } from "../src/sequencing/index.js";
import { NON_CLASS_GATE_REGISTRY, type GateValidator } from "../src/validate/gate-registry.js";

import { withRunnerWorkspace } from "./runner-fixtures.js";

function step(stepId: string) {
  const found = STEP_CATALOG.find((candidate) => candidate.id === stepId);
  assert.ok(found, `Missing step ${stepId}`);
  return found;
}

/** Wrap the real non-class registry so tests can prove each gate actually ran. */
function recordingRegistry(calls: string[]): Record<string, GateValidator> {
  const wrapped: Record<string, GateValidator> = {};
  for (const [name, validator] of Object.entries(NON_CLASS_GATE_REGISTRY)) {
    wrapped[name] = (invocation) => {
      calls.push(name);
      return validator(invocation);
    };
  }
  return wrapped;
}

/** A valid, complete EARS-review ledger that passes the real `ears-review` gate. */
function validEarsReviewLedger(): string {
  return `# Requirements EARS Extra Review

## 1. Document Meta
- feature_id: FEAT-REVIEW-001
- feature_title: Payments access review
- source_feature_br_summary: projects/project-a/feature-alpha/feature_br_summary.md
- source_user_br_input: projects/project-a/feature-alpha/user_br_input.md
- source_requirements_ears: projects/project-a/feature-alpha/requirements_ears.md
- review_status: complete
- last_updated: 2026-07-16

## 2. Review Guidance
- completion_rule: Set review_status complete only when every finding is terminal.

## 3. Findings Ledger
- no_findings: true
`;
}

/**
 * requirements_ears.md whose only acceptance bullet uses the invalid
 * `WHEN ..., THEN THE ... SHALL ...` shape the measured UMSS run shipped; the real
 * `requirements-ears` gate reports it as an invalid EARS pattern.
 */
function invalidEarsRequirements(): string {
  return `# Requirements (EARS)

## Requirements

### Requirement 1 - Duplicate accounts
**User Story:** As a user, I want no duplicate accounts, so that billing stays correct.

**Acceptance Criteria (EARS):**
- WHEN a duplicate account is submitted, THEN THE System SHALL reject the request.

**Verification:** API test for duplicate rejection.
`;
}

/** A valid, complete plan-semantic-review ledger that passes the real gate. */
function validPlanSemanticReviewLedger(): string {
  return `# Implementation Plan Semantic Review

## 1. Document Meta
- feature_id: F-1
- feature_title: Feature
- source_implementation_plan: projects/project-a/feature-alpha/implementation_plan.md
- source_project_definition: projects/project-a/init_progress_definition.yaml
- source_requirements_ears: projects/project-a/feature-alpha/requirements_ears.md
- source_technical_requirements: projects/project-a/feature-alpha/technical_requirements.md
- review_status: complete
- last_updated: 2026-07-16

## 2. Review Guidance
- completion_rule: complete

## 3. Findings Ledger
- no_findings: true
`;
}

test("step 5.1 rejects an invalid EARS artifact even when the review ledger passes", async () => {
  await withRunnerWorkspace(async ({ root, featurePath, featureDir }) => {
    // A completed, valid review ledger next to an EARS artifact that fails its gate.
    writeFileSync(path.join(featureDir, "requirements_ears.md"), invalidEarsRequirements());
    writeFileSync(path.join(featureDir, "requirements_ears_review.md"), validEarsReviewLedger());

    const calls: string[] = [];
    const deps: StepExecutorDeps = {
      ...defaultStepExecutorDeps,
      agentRunner: new StubAgentRunner(0),
      gateRegistry: recordingRegistry(calls)
    };

    const result = await executeStep(
      step("5.1"),
      {
        step: step("5.1"),
        runtimeRoot: root,
        featurePath,
        overmindCliPath: ".overmind/overmind.js"
      },
      deps
    );

    // ears-review still runs, requirements-ears fails, and the step is rejected.
    assert.deepEqual(calls, ["requirements-ears", "ears-review"]);
    assert.equal(result.ok, false);
    assert.equal(result.exitCode, 1);
    const reasons = result.diagnostics.map((item) => item.reason).join("\n");
    assert.match(reasons, /Post-session gate 'requirements-ears' failed for requirements_ears\.md/);
    assert.match(reasons, /invalid EARS bullet pattern/);
  });
});

test("step 8.4 rejects an invalid implementation plan even when the semantic-review ledger passes", async () => {
  await withRunnerWorkspace(async ({ root, featurePath, featureDir }) => {
    // The fixture's implementation_plan.md ("# Plan\n") fails the implementation-plan
    // gate; pair it with a valid semantic-review ledger that passes its gate.
    writeFileSync(
      path.join(featureDir, "implementation_plan_semantic_review.md"),
      validPlanSemanticReviewLedger()
    );

    const calls: string[] = [];
    const deps: StepExecutorDeps = {
      ...defaultStepExecutorDeps,
      agentRunner: new StubAgentRunner(0),
      gateRegistry: recordingRegistry(calls)
    };

    const result = await executeStep(
      step("8.4"),
      {
        step: step("8.4"),
        runtimeRoot: root,
        featurePath,
        overmindCliPath: ".overmind/overmind.js"
      },
      deps
    );

    // Both gates run; the plan gate fails, so step 8.4 is rejected.
    assert.deepEqual(calls, ["implementation-plan", "plan-semantic-review"]);
    assert.equal(result.ok, false);
    const reasons = result.diagnostics.map((item) => item.reason).join("\n");
    assert.match(
      reasons,
      /Post-session gate 'implementation-plan' failed for implementation_plan\.md/
    );
    // The ledger gate did not contribute a failure diagnostic.
    assert.doesNotMatch(reasons, /plan-semantic-review' failed/);
  });
});
