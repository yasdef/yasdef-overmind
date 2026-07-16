import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import assert from "node:assert/strict";

import { validateTaskToBr } from "asdlc-coordinator";

// Fixtures for the measured UMSS regression shapes: each constant is the artifact
// content that lost business meaning, paired with the corrected content the
// updated rules require.
//
// The two `measured regression:` tests execute the task-to-BR gate against a
// fixture and assert its behavior. The `skill contract:` tests assert authored
// fixtures plus the text of the shipped skills and examples: they prove the rule
// is stated and demonstrated, not that a conversion run produces it. Behavioral
// evidence for the model-owned EARS stage comes from the end-to-end rerun.

function packagedSkillFile(skillName: string, ...parts: string[]): string {
  const moduleDir = path.dirname(fileURLToPath(import.meta.url));
  return path.resolve(moduleDir, "..", "..", "_data", "skills", skillName, ...parts);
}

function withFeature(
  summary: string,
  missingData: string,
  fn: (featureDir: string, root: string) => void
): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-semantic-"));
  try {
    const featureDir = path.join(root, "projects", "umss", "telegram-onboarding");
    mkdirSync(featureDir, { recursive: true });
    writeFileSync(path.join(featureDir, "feature_br_summary.md"), summary);
    writeFileSync(
      path.join(featureDir, "user_br_input.md"),
      `# User Business Input

## 2. Epic/Story Input
- epic_story_source_file: feature-story.md
- epic_or_story: |
  Telegram users must be registered in UMSS before they can use the bot.
`
    );
    writeFileSync(path.join(featureDir, "missing_br_data.md"), missingData);
    fn(featureDir, root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function umssSummary(overrides: {
  rejectionCases: string;
  statedConstraints: string;
  outOfScopeItems: string;
  configExpectations: string;
}): string {
  return `# Feature Business Requirements Summary

## 1. Document Meta
- source_type: User input
- source_refs: projects/umss/telegram-onboarding/user_br_input.md; feature-story.md
- last_updated: 2026-07-21

## 2. Source Request Snapshot
### 2.1 Original request summary
- short summary: Register Telegram users in UMSS before granting bot access.

### 2.3 Explicitly stated in source
- stated_constraints: ${overrides.statedConstraints}

## 3. Feature Intent
### 3.1 Business goal
- primary_business_goal: Give every Telegram user a verified UMSS account record.

## 5. Scope Definition
### 5.2 Out of scope
- out_of_scope_items: ${overrides.outOfScopeItems}

### 5.3 Open scope boundaries
- unclear_scope_points: [UNFILLED]

## 6. Functional Requirements
- FR-1: System registers a Telegram user together with a unique Telegram user id.

## 7. Business Rules and Decision Logic
- BR-1: System rejects registration when Telegram user data is invalid.

## 10. Failure Cases and Edge Cases
### Negative and rejection cases
- rejection_cases: ${overrides.rejectionCases}

## 12. Non-Functional Requirements
### 12.4 Operational and rollout
- config_expectations: ${overrides.configExpectations}

### 12.5 Testing and quality
- required_test_levels: Backend automated tests for registration and rejection behavior.

## 14. Assumptions
### Needs validation
- assumptions_needing_validation: [UNFILLED]

## 15. Open Questions
### Critical questions
- critical_questions: [UNFILLED]
`;
}

const MEASURED_PROHIBITION =
  "introduces no market, ledger, forecasting, blockchain, or complex analytics behavior";

const regressionSummary = umssSummary({
  rejectionCases: "Missing unique Telegram user id returns a simple non-sensitive error message.",
  statedConstraints: "Reuse the existing Telegram bot integration.",
  outOfScopeItems: "Admin console redesign.",
  configExpectations: `Bot token configured per environment; ${MEASURED_PROHIBITION}.`
});

const correctedSummary = umssSummary({
  rejectionCases: "[UNFILLED]",
  statedConstraints: `Reuse the existing Telegram bot integration; ${MEASURED_PROHIBITION}.`,
  outOfScopeItems: `Admin console redesign; market, ledger, forecasting, blockchain, and complex analytics behavior.`,
  configExpectations: `Bot token configured per environment; ${MEASURED_PROHIBITION}.`
});

const emptyLedger = `# Missing Business Data

## 2. Missing Business Fields
- none

## 3. Unresolved Items Ledger (Rised)

## 6. Latest User Answers
- answers: [UNFILLED]

## 7. Loop Decision
- unresolved_after_stop: none
`;

const pendingErrorResponseLedger = `# Missing Business Data

## 2. Missing Business Fields
- ambiguity trigger \`simple\` remains in ### Negative and rejection cases -> rejection_cases; move the unresolved wording to missing_br_data.md as rised_item_N with rised=false

## 3. Unresolved Items Ledger (Rised)
- rised_item_1: source=### Negative and rejection cases -> rejection_cases; rised=false; unresolved_item=What exact error response must a rejected Telegram registration return?

## 6. Latest User Answers
- answers: [UNFILLED]

## 7. Loop Decision
- unresolved_after_stop: Waiting for the required rejection response content.
`;

test("measured regression: ambiguous rejection response outside the legacy move list is rejected", () => {
  withFeature(regressionSummary, emptyLedger, (featureDir, root) => {
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      "ambiguity trigger `simple` remains in ### Negative and rejection cases -> rejection_cases; move the unresolved wording to missing_br_data.md as rised_item_N with rised=false and set that field to [UNFILLED], or record an answered rised=true item naming that field to confirm the wording"
    ]);
  });
});

test("measured regression recovers once the error response reaches the clarification ledger", () => {
  withFeature(correctedSummary, pendingErrorResponseLedger, (featureDir, root) => {
    assert.equal(validateTaskToBr(featureDir, root).exitCode, 0);
  });
});

function prohibitionReachesScopeFields(summary: string, prohibition: RegExp): boolean {
  return summary
    .split(/\r?\n/)
    .filter(
      (line) =>
        line.trim().startsWith("- stated_constraints:") ||
        line.trim().startsWith("- out_of_scope_items:")
    )
    .some((line) => prohibition.test(line));
}

test("skill contract: a prohibition filed only as configuration does not reach the scope fields", () => {
  const measured = /market, ledger, forecasting, blockchain/;
  assert.match(regressionSummary, /- config_expectations:[^\n]*market, ledger, forecasting/);
  assert.equal(prohibitionReachesScopeFields(regressionSummary, measured), false);
  assert.equal(prohibitionReachesScopeFields(correctedSummary, measured), true);

  const taskToBrSkill = readFileSync(packagedSkillFile("overmind-task-to-br", "SKILL.md"), "utf8");
  assert.match(
    taskToBrSkill,
    /Every explicit source prohibition[^\n]*`### 2\.3 Explicitly stated in source -> stated_constraints` or `### 5\.2 Out of scope -> out_of_scope_items`/
  );
  assert.match(taskToBrSkill, /that additional placement alone does not satisfy this constraint/);

  // The shipped example demonstrates the same routing for its own prohibition.
  const brGolden = readFileSync(
    packagedSkillFile("overmind-task-to-br", "assets", "feature_br_summary_GOLDEN_EXAMPLE.md"),
    "utf8"
  );
  assert.equal(prohibitionReachesScopeFields(brGolden, /SMS delivery channel/), true);
  assert.match(
    brGolden,
    /- config_expectations:[^\n]*no new identity-provider or SMS configuration/
  );
});

const narrowedEars = `## Requirements

### Requirement 1 — Reject registration without a Telegram user id
**Acceptance Criteria (EARS):**
- IF a registration request has no unique Telegram user id, THEN THE UMSS Backend SHALL reject the request.

**Verification:** Manual check of the bot registration flow.
`;

const preservedEars = `## Requirements

### Requirement 1 — Reject invalid Telegram user data
**Acceptance Criteria (EARS):**
- IF a registration request contains invalid Telegram user data, THEN THE UMSS Backend SHALL reject the request.
- IF a registration request has no unique Telegram user id, THEN THE UMSS Backend SHALL reject the request and report the missing id.

**Verification:** Backend automated tests covering invalid Telegram user data and the missing-id case.
`;

function coversBroadAndSpecificRejection(ears: string): boolean {
  return (
    /invalid Telegram user data, THEN THE UMSS Backend SHALL reject/.test(ears) &&
    /no unique Telegram user id, THEN THE UMSS Backend SHALL reject/.test(ears)
  );
}

function preservesBackendTestObligation(ears: string): boolean {
  return /\*\*Verification:\*\*[^\n]*[Bb]ackend automated tests/.test(ears);
}

test("skill contract: a specific rejection case must not replace the broad invalid-data obligation", () => {
  assert.equal(coversBroadAndSpecificRejection(narrowedEars), false);
  assert.equal(coversBroadAndSpecificRejection(preservedEars), true);

  const earsSkill = readFileSync(
    packagedSkillFile("overmind-requirements-ears", "SKILL.md"),
    "utf8"
  );
  assert.match(earsSkill, /### Broad and Specific Requirement Precedence/);
  assert.match(
    earsSkill,
    /A specific case replaces the broader requirement only when the BR summary explicitly states that the specific case is exhaustive/
  );

  const earsGolden = readFileSync(
    packagedSkillFile("overmind-requirements-ears", "assets", "reqirements_ears_GOLDEN_EXAMPLE.md"),
    "utf8"
  );
  assert.match(
    earsGolden,
    /contains invalid task data, THEN THE Example Task Tracking Service SHALL reject/
  );
  assert.match(earsGolden, /missing a title, THEN THE Example Task Tracking Service SHALL reject/);
});

test("skill contract: required backend test levels reach verification", () => {
  assert.equal(preservesBackendTestObligation(narrowedEars), false);
  assert.equal(preservesBackendTestObligation(preservedEars), true);

  const earsSkill = readFileSync(
    packagedSkillFile("overmind-requirements-ears", "SKILL.md"),
    "utf8"
  );
  assert.match(earsSkill, /### Final Coverage Sweep/);
  assert.match(
    earsSkill,
    /`### 12\.5 Testing and quality -> required_test_levels`[^\n]*`\*\*Verification:\*\*` fields\./
  );
  // A release or CI gate is process, so it must not become an EARS bullet.
  assert.match(earsSkill, /a release or CI gate is process/);
  assert.match(
    earsSkill,
    /An exclusion that means the capability is not built in this feature stays in `Out of scope`/
  );

  const earsGolden = readFileSync(
    packagedSkillFile("overmind-requirements-ears", "assets", "reqirements_ears_GOLDEN_EXAMPLE.md"),
    "utf8"
  );
  assert.match(
    earsGolden,
    /\*\*Verification:\*\* Backend automated API tests[^\n]*invalid task data generally and the missing-title case/
  );
  assert.match(earsGolden, /Out of scope:[^\n]*time-tracking analytics reports/);
});
