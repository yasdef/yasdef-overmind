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
- none

## 3. Unresolved Items Ledger (Rised)
- rised_item_1: source=### Negative and rejection cases -> rejection_cases; rised=false; unresolved_item=What exact error response must a rejected Telegram registration return?

## 6. Latest User Answers
- answers: [UNFILLED]

## 7. Loop Decision
- unresolved_after_stop: Waiting for the required rejection response content.
`;

// Discovering that the rejection response is still open is the model's work in
// step 4.1: the gate no longer decides business completeness from the wording
// that survived into the BR.
test("measured regression: the gate does not judge business completeness by BR wording", () => {
  withFeature(regressionSummary, emptyLedger, (featureDir, root) => {
    assert.equal(validateTaskToBr(featureDir, root).exitCode, 0);
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

// Step 4.1 owns semantic gap discovery. These assertions prove the skill states
// the active-discovery rule and its business scope — not that a run produces any
// particular wording or question count.
test("skill contract: task-to-BR states an active business-gap discovery rule", () => {
  const taskToBrSkill = readFileSync(packagedSkillFile("overmind-task-to-br", "SKILL.md"), "utf8");

  assert.match(taskToBrSkill, /### Business Gap Discovery/);
  // Every relevant unresolved or low-confidence detail leaves as a question.
  assert.match(
    taskToBrSkill,
    /Externalize every relevant business detail that stays unresolved, or that you cannot state confidently[^\n]*instead of inferring an answer/
  );
  assert.match(
    taskToBrSkill,
    /A gap exists whenever a relevant business detail stays unresolved, or you cannot state it confidently/
  );
  // Imprecise wording is mandatory to clarify, over an open trigger set, and
  // paraphrasing it away is not a resolution.
  assert.match(
    taskToBrSkill,
    /MUST become a question unless the surrounding source content already makes the intended result concrete/
  );
  assert.match(taskToBrSkill, /These words are examples, not a closed list/);
  assert.match(
    taskToBrSkill,
    /Rewriting that wording into another imprecise phrase, or dropping it from the BR, does not resolve the gap/
  );
  // Discovery runs on the source, so a passing gate proves nothing about it.
  assert.match(taskToBrSkill, /A passing gate is not evidence that discovery was performed/);
  // Consolidation: one gap, one ledger item, every affected field in the locator.
  assert.match(
    taskToBrSkill,
    /One independent gap produces one ledger item[^\n]*\n?[^\n]*`source=` locator list/
  );
  // Business scope only; implementation choices stay out.
  assert.match(
    taskToBrSkill,
    /business intent, actors, access, scope, rules, inputs, outputs, states, failures, and user-visible outcomes/
  );
  assert.match(
    taskToBrSkill,
    /Do not ask technical implementation, architecture, framework, deployment, or code-structure questions/
  );
  // No closed lexical policy survives in the skill.
  assert.equal(/deterministic backstop over generated BR fields/.test(taskToBrSkill), false);
  assert.equal(/Source-Obligation Review/.test(taskToBrSkill), false);
});

test("skill contract: consolidating semantic prose keeps the surrounding task-to-BR contracts", () => {
  const taskToBrSkill = readFileSync(packagedSkillFile("overmind-task-to-br", "SKILL.md"), "utf8");

  // Capture and runtime paths.
  assert.match(taskToBrSkill, /node \.overmind\/overmind\.js capture task-to-br <feature-path>/);
  assert.match(taskToBrSkill, /### Runtime Path Bindings/);
  assert.match(
    taskToBrSkill,
    /Do not replace runtime bindings with fixed `overmind\/product\/\.\.\.` assumptions/
  );
  // Ledger syntax and terminal state.
  assert.match(taskToBrSkill, /### Deterministic Ledger Markers/);
  assert.match(
    taskToBrSkill,
    /- `- rised_item_N: source=<section> -> <field>; rised=false; unresolved_item=<text>`/
  );
  assert.match(taskToBrSkill, /### Ledger Terminal State/);
  // A gate repair round must not thin the ledger step 4.2 consumes, and must
  // still be able to fix the marker state the gate itself reports as invalid.
  assert.match(
    taskToBrSkill,
    /On refresh, preserve every existing `rised_item_N`, including the items written by `### Business Gap Discovery`/
  );
  assert.match(
    taskToBrSkill,
    /restore a missing or malformed `rised` marker, and renumber to keep numbering deterministic and gap-free/
  );
  // Discovery owns which questions exist and where they point; gate output
  // can never retire one.
  assert.match(
    taskToBrSkill,
    /unless that discovery requires correcting, merging, or removing an item; gate output alone never removes one\. Keep every `rised=true` item unchanged\./
  );
  // The locator is a destination for step 4.2's answer, not an origin record.
  assert.match(
    taskToBrSkill,
    /The `source=` locator names the affected BR field that step 4\.2 will populate\. Keep that field `\[UNFILLED\]` until the answer is recorded\./
  );
  // Source references and linked artifacts.
  assert.match(taskToBrSkill, /### Captured Source Binding/);
  assert.match(taskToBrSkill, /required_source_refs/);
  assert.match(taskToBrSkill, /### Linked Artifact Extraction For Jira Sources/);
  // Readiness handoff and the final gate loop.
  assert.match(taskToBrSkill, /node \.overmind\/overmind\.js gate task-to-br <feature-path>/);
  assert.match(taskToBrSkill, /`2`: runtime or validation failure/);
  assert.match(
    taskToBrSkill,
    /Task-to-BR phase is finished\. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase/
  );
  // Step 4.2 stays the consumer of the ledger this step produces.
  assert.match(
    taskToBrSkill,
    /answer-handling lifecycle is governed by the downstream `overmind-br-clarification` skill/
  );
});

interface LedgerItem {
  id: string;
  rised: string;
  locators: { section: string; field: string }[];
}

function parseLedgerItems(ledger: string): LedgerItem[] {
  return ledger
    .split(/\r?\n/)
    .map((line) =>
      /^- (rised_item_\d+): source=(.+?); rised=(\w+); unresolved_item=/.exec(line.trim())
    )
    .filter((match): match is RegExpExecArray => match !== null)
    .map((match) => ({
      id: match[1] ?? "",
      rised: match[3] ?? "",
      locators: (match[2] ?? "").split(",").map((locator) => {
        const [section, field] = locator.split("->").map((part) => part.trim());
        return { section: section ?? "", field: field ?? "" };
      })
    }));
}

test("skill contract: ledger locators match the field state the BR example shows", () => {
  const brGolden = readFileSync(
    packagedSkillFile("overmind-task-to-br", "assets", "feature_br_summary_GOLDEN_EXAMPLE.md"),
    "utf8"
  );
  const items = parseLedgerItems(
    readFileSync(
      packagedSkillFile("overmind-task-to-br", "assets", "missing_br_data_GOLDEN_EXAMPLE.md"),
      "utf8"
    )
  );

  // The example is a mid-loop snapshot, so it must demonstrate both ledger states.
  assert.ok(items.some((item) => item.rised === "false"));
  assert.ok(items.some((item) => item.rised === "true"));

  // Step 4.2 writes each answer into the fields the locator names, so the pending
  // question points at the requirement that decision belongs in.
  assert.deepEqual(
    items.filter((item) => item.rised === "false").map((item) => item.locators),
    [
      [{ section: "## 6. Functional Requirements", field: "FR-5" }],
      [
        {
          section: "### Recovery and retry expectations",
          field: "retry_or_recovery_expectations"
        }
      ],
      [{ section: "### 5.3 Open scope boundaries", field: "unclear_scope_points" }]
    ]
  );

  const brLines = brGolden.split(/\r?\n/).map((line) => line.trim());
  for (const item of items) {
    for (const { section, field } of item.locators) {
      assert.equal(brLines.includes(section), true, `${item.id}: missing heading ${section}`);
      const unfilled = brLines.includes(`- ${field}: [UNFILLED]`);
      const populated = brLines.some(
        (line) => line.startsWith(`- ${field}: `) && !line.endsWith("[UNFILLED]")
      );
      if (item.rised === "false") {
        // Pending: the field waits for the answer step 4.2 will collect.
        assert.equal(unfilled, true, `${item.id}: ${field} is not [UNFILLED]`);
      } else {
        // Answered: the agreed content is back in every field the item names.
        assert.equal(populated, true, `${item.id}: answered ${field} is not populated`);
      }
    }
  }
});

test("skill contract: task-to-BR examples show one consolidated question and no redundant one", () => {
  const brGolden = readFileSync(
    packagedSkillFile("overmind-task-to-br", "assets", "feature_br_summary_GOLDEN_EXAMPLE.md"),
    "utf8"
  );
  const ledgerGolden = readFileSync(
    packagedSkillFile("overmind-task-to-br", "assets", "missing_br_data_GOLDEN_EXAMPLE.md"),
    "utf8"
  );

  // One acceptance-affecting decision restated in two BR fields is one ledger item.
  const consolidated = parseLedgerItems(ledgerGolden).filter((item) =>
    item.locators.some((locator) => locator.field === "rejection_cases")
  );
  assert.equal(consolidated.length, 1);
  assert.deepEqual(consolidated[0]?.locators, [
    { section: "### Negative and rejection cases", field: "rejection_cases" },
    { section: "## 7. Business Rules and Decision Logic", field: "BR-4" }
  ]);

  // A detail the source states clearly enough to record produces no redundant
  // question: the states that bound FR-4 are recorded in the source snapshot.
  assert.match(brGolden, /- FR-4:[^\n]*reset-status screen showing exactly one of/);
  assert.match(
    brGolden,
    /- stated_acceptance_criteria:[^\n]*link sent, link expired, link already used, or password updated/
  );
  assert.equal(/rised_item_\d+:[^\n]*FR-4/.test(ledgerGolden), false);

  // Several active business gaps are illustrated, not one token-driven question.
  assert.ok(parseLedgerItems(ledgerGolden).filter((item) => item.rised === "false").length >= 2);
});

test("skill contract: the task-to-BR example asks nothing the source already settled", () => {
  const brGolden = readFileSync(
    packagedSkillFile("overmind-task-to-br", "assets", "feature_br_summary_GOLDEN_EXAMPLE.md"),
    "utf8"
  );
  const ledgerGolden = readFileSync(
    packagedSkillFile("overmind-task-to-br", "assets", "missing_br_data_GOLDEN_EXAMPLE.md"),
    "utf8"
  );

  // The source excludes the SMS delivery channel in its constraints and scope.
  assert.match(brGolden, /- stated_constraints:[^\n]*no SMS delivery channel/);
  assert.match(brGolden, /- out_of_scope_items:[^\n]*SMS delivery channel/);
  // A settled exclusion is recorded as an assumption, never reopened as a question.
  assert.match(brGolden, /- confirmed_assumptions:[^\n]*SMS fallback is excluded by the source/);
  const questions = ledgerGolden
    .split(/\r?\n/)
    .filter((line) => line.trim().startsWith("- rised_item_"));
  assert.ok(questions.length > 0);
  for (const question of questions) {
    assert.equal(/SMS/i.test(question), false, `ledger reopens settled scope: ${question}`);
  }
});
