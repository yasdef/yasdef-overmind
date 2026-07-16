import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { validateTaskToBr } from "../src/validate/task-to-br.js";

import {
  completeSummary,
  createFeatureFixture,
  goldenBasedValidSummary,
  userInput,
  userInputWithoutStoryContent
} from "./fixtures.js";

function withWorkspace(fn: (root: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-task-to-br-"));
  try {
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test("validator passes when required fields, FR, BR, user input, and missing-data ledger exist", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 0);
    assert.equal(result.passMessage, "business-context gate passed");
  });
});

test("validator passes with a golden-example-based valid summary", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: goldenBasedValidSummary(),
      missingData: `# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=false; unresolved_item=Is forced MFA re-verification required after reset?

## 6. Latest User Answers
- answers: [UNFILLED]

## 7. Loop Decision
- unresolved_after_stop: Pending business clarification.
`
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 0);
  });
});

test("validator reports missing user input as a recoverable problem", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, { userInput: null });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, ["user_br_input.md is missing"]);
  });
});

test("validator reports missing story content in captured user input", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, { userInput: userInputWithoutStoryContent() });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      "user_br_input.md -> epic_or_story must contain actual source story/request content"
    ]);
  });
});

test("validator reports missing missing_br_data.md as recoverable", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, { missingData: null });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      "missing_br_data.md must exist; create it with an empty unresolved ledger when no business gaps remain"
    ]);
  });
});

test("validator reports required BR summary field failures distinctly", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: completeSummary()
        .replace("- source_type: User input", "- source_type: Story")
        .replace("- last_updated: 2026-03-20", "- last_updated: 03/20/2026")
        .replace(
          "- short summary: Product owners need invoice approval turnaround visibility.",
          "- short summary: [UNFILLED]"
        )
        .replace(
          "- primary_business_goal: Reduce billing approval cycle time.",
          "- primary_business_goal: [UNFILLED]"
        )
        .replace(
          "- FR-1: System captures required invoice approval fields from product owner.",
          "- FR-1: [UNFILLED]"
        )
        .replace(
          "- BR-1: Approval requests above threshold require compliance review before release.",
          "- BR-1: [UNFILLED]"
        )
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      "## 1. Document Meta -> source_type must include User input",
      "## 1. Document Meta -> last_updated must be YYYY-MM-DD",
      "### 2.1 Original request summary -> short summary is unfilled",
      "### 3.1 Business goal -> primary_business_goal is unfilled",
      "## 6. Functional Requirements -> at least one meaningful one-line FR item (`- FR-N: ...`) is required",
      "## 7. Business Rules and Decision Logic -> at least one meaningful one-line BR item (`- BR-N: ...`) is required"
    ]);
  });
});

test("validator reports a missing Document Meta section", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: completeSummary().replace(
        "\n## 1. Document Meta\n- source_type: User input\n- source_refs: projects/project-a/feature-alpha/user_br_input.md; feature-story.md\n- last_updated: 2026-03-20\n",
        "\n"
      )
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, ["section ## 1. Document Meta is missing"]);
  });
});

test("validator requires unresolved Open Questions to move to missing_br_data.md", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: completeSummary().replace(
        "- critical_questions: [UNFILLED]",
        "- critical_questions: Is legal approval required for cross-region invoice routing?"
      )
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      "## 15. Open Questions -> unresolved items must be moved to missing_br_data.md as rised_item_N with rised=false"
    ]);
  });
});

test("validator requires unresolved assumptions to move to missing_br_data.md", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: completeSummary().replace(
        "- assumptions_needing_validation: [UNFILLED]",
        "- assumptions_needing_validation: Whether regional tax routing needs legal signoff."
      )
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      "### Needs validation -> unresolved assumptions_needing_validation must be moved to missing_br_data.md as rised_item_N with rised=false"
    ]);
  });
});

test("validator requires unresolved scope boundaries to move to missing_br_data.md", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: completeSummary().replace(
        "- unclear_scope_points: [UNFILLED]",
        "- unclear_scope_points: Should pilot include partner-managed queues?"
      )
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      "### 5.3 Open scope boundaries -> unresolved unclear_scope_points must be moved to missing_br_data.md as rised_item_N with rised=false"
    ]);
  });
});

test("validator passes when rised markers are present in BR unresolved fields", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: completeSummary()
        .replace(
          "- assumptions_needing_validation: [UNFILLED]",
          "- assumptions_needing_validation: rised=true; unresolved_item=Whether regional tax routing needs legal signoff."
        )
        .replace(
          "- unclear_scope_points: [UNFILLED]",
          "- unclear_scope_points: rised=true; unresolved_item=Should pilot include partner-managed queues?"
        )
        .replace(
          "- critical_questions: [UNFILLED]",
          "- critical_questions: rised=true; unresolved_item=Is legal approval required for cross-region invoice routing?"
        )
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 0);
  });
});

test("validator checks missing-data rised flags and loop fields", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      missingData: `# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
- rised_item_1: source=## 15. Open Questions -> critical_questions; unresolved_item=Is legal approval required?
- rised_item_2: source=## 15. Open Questions -> non_critical_questions; rised=true; unresolved_item=Should email include metadata?

## 6. Latest User Answers
- answers: [UNFILLED]

## 7. Loop Decision
- unresolved_after_stop: [UNFILLED]
`
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      "missing_br_data.md -> every unresolved ledger item must include rised=false or rised=true",
      "missing_br_data.md -> unresolved rised items exist but ## 6. Latest User Answers -> answers is [UNFILLED]",
      "missing_br_data.md -> unresolved rised items exist but ## 7. Loop Decision -> unresolved_after_stop is [UNFILLED]"
    ]);
  });
});

test("validator passes for pending rised=false missing-data items with loop decision", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      missingData: `# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=false; unresolved_item=Is legal approval required?

## 6. Latest User Answers
- answers: [UNFILLED]

## 7. Loop Decision
- unresolved_after_stop: Pending legal policy clarification from business owner.
`
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 0);
  });
});

test("validator passes for rised=true missing-data items with answer pointers", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      missingData: `# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=Is legal approval required?
- rised_item_2: source=### 5.3 Open scope boundaries -> unclear_scope_points; rised=true; unresolved_item=Should pilot include partner-managed approval queues?

## 6. Latest User Answers
- answers: This was recorded in ## 7. Business Rules and Decision Logic - BR-1.
- answers: This was recorded in ## 5. Scope and Boundaries - unclear_scope_points.

## 7. Loop Decision
- unresolved_after_stop: none
`
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 0);
  });
});

const terminalSummaryProblem =
  "missing_br_data.md -> ## 7. Loop Decision -> unresolved_after_stop must be exactly `none` when the unresolved ledger is empty or every rised_item_N is rised=true";

function allRisedMissingData(unresolvedAfterStop: string): string {
  return `# Missing Business Data

## 1. Gate Status
- gate_result: failed

## 3. Unresolved Items Ledger (Rised)
- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=Is legal approval required?

## 6. Latest User Answers
- answers: This was recorded in ## 7. Business Rules and Decision Logic - BR-1.

## 7. Loop Decision
- unresolved_after_stop: ${unresolvedAfterStop}
`;
}

function emptyLedgerMissingData(unresolvedAfterStop: string): string {
  return `# Missing Business Data

## 2. Missing Business Fields
- none

## 3. Unresolved Items Ledger (Rised)

## 6. Latest User Answers
- answers: [UNFILLED]

## 7. Loop Decision
- unresolved_after_stop: ${unresolvedAfterStop}
`;
}

test("validator keeps a mixed ledger on the filled-summary path", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      missingData: `# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=Is legal approval required?
- rised_item_2: source=### 5.3 Open scope boundaries -> unclear_scope_points; rised=false; unresolved_item=Should pilot include partner queues?

## 6. Latest User Answers
- answers: This was recorded in ## 7. Business Rules and Decision Logic - BR-1.

## 7. Loop Decision
- unresolved_after_stop: Pending pilot scope decision from business owner.
`
    });
    assert.equal(validateTaskToBr(featureDir, root).exitCode, 0);
  });
});

test("validator passes an empty ledger whose terminal summary is none", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      missingData: emptyLedgerMissingData("none")
    });
    assert.equal(validateTaskToBr(featureDir, root).exitCode, 0);
  });
});

test("validator rejects an empty ledger whose terminal summary is stale or unfilled", () => {
  for (const value of ["[UNFILLED]", "Waiting for user input.", ""]) {
    withWorkspace((root) => {
      const featureDir = createFeatureFixture(root, {
        missingData: emptyLedgerMissingData(value)
      });
      const result = validateTaskToBr(featureDir, root);
      assert.equal(result.exitCode, 1);
      assert.deepEqual(result.problems, [terminalSummaryProblem]);
    });
  }
});

test("validator rejects an all-rised ledger whose terminal summary is not the exact literal", () => {
  for (const value of ["Waiting for user input.", "[UNFILLED]", '"none"', "'none'", "None"]) {
    withWorkspace((root) => {
      const featureDir = createFeatureFixture(root, {
        missingData: allRisedMissingData(value)
      });
      const result = validateTaskToBr(featureDir, root);
      assert.equal(result.exitCode, 1, `expected exit 1 for unresolved_after_stop: ${value}`);
      assert.deepEqual(result.problems, [terminalSummaryProblem]);
    });
  }
});

test("validator rejects a terminal ledger with no unresolved_after_stop field at all", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      missingData: allRisedMissingData("none").replace("- unresolved_after_stop: none\n", "")
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [terminalSummaryProblem]);
  });
});

test("validator passes an all-rised ledger with a historical failed gate_result and reads it only", () => {
  withWorkspace((root) => {
    const ledger = allRisedMissingData("none");
    const featureDir = createFeatureFixture(root, { missingData: ledger });
    const ledgerPath = path.join(featureDir, "missing_br_data.md");
    const before = readFileSync(ledgerPath, "utf8");

    const result = validateTaskToBr(featureDir, root);

    assert.equal(result.exitCode, 0);
    assert.equal(readFileSync(ledgerPath, "utf8"), before);
  });
});

const captureRecordRef = "projects/project-a/feature-alpha/user_br_input.md";
const canonicalSourceRefs = `- source_refs: ${captureRecordRef}; feature-story.md`;

test("validator passes when the complete captured-source binding is present", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 0);
  });
});

test("validator reports a missing capture-record reference", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: completeSummary().replace(canonicalSourceRefs, "- source_refs: feature-story.md")
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      `## 1. Document Meta -> source_refs must include the captured source reference: ${captureRecordRef}`
    ]);
  });
});

test("validator reports a missing original story reference", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: completeSummary().replace(canonicalSourceRefs, `- source_refs: ${captureRecordRef}`)
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      "## 1. Document Meta -> source_refs must include the captured source reference: feature-story.md"
    ]);
  });
});

test("validator does not accept story content that impersonates the capture metadata", () => {
  withWorkspace((root) => {
    // Real metadata field removed; the story body claims its own source file.
    const impersonated = userInput()
      .replace("- epic_story_source_file: feature-story.md\n", "")
      .replace(
        "  As a product owner I want invoice approval visibility.",
        "  As a product owner I want invoice approval visibility.\n  - epic_story_source_file: fabricated.md"
      );
    const featureDir = createFeatureFixture(root, {
      summary: completeSummary().replace(
        canonicalSourceRefs,
        `- source_refs: ${captureRecordRef}; fabricated.md`
      ),
      userInput: impersonated
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      "user_br_input.md -> epic_story_source_file is unfilled; rerun task-to-BR capture so the original story source is recorded"
    ]);
  });
});

test("validator reports an unfilled source_refs field", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: completeSummary().replace(canonicalSourceRefs, "- source_refs: [UNFILLED]")
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, ["## 1. Document Meta -> source_refs is unfilled"]);
  });
});

test("validator rejects a placeholder element kept alongside the required references", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: completeSummary().replace(
        canonicalSourceRefs,
        `- source_refs: ${captureRecordRef}; feature-story.md; [UNFILLED]`
      )
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      "## 1. Document Meta -> source_refs must not keep [UNFILLED] placeholder elements alongside real source references"
    ]);
  });
});

test("validator rejects a leading placeholder element", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: completeSummary().replace(
        canonicalSourceRefs,
        `- source_refs: [UNFILLED]; ${captureRecordRef}; feature-story.md`
      )
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      "## 1. Document Meta -> source_refs must not keep [UNFILLED] placeholder elements alongside real source references"
    ]);
  });
});

test("validator reports an all-placeholder source_refs field as unfilled only", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: completeSummary().replace(
        canonicalSourceRefs,
        "- source_refs: [UNFILLED]; [UNFILLED]"
      )
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, ["## 1. Document Meta -> source_refs is unfilled"]);
  });
});

test("validator reports an absent source_refs field", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: completeSummary().replace(`${canonicalSourceRefs}\n`, "")
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, ["## 1. Document Meta -> source_refs is unfilled"]);
  });
});

test("validator reports an unfilled epic_story_source_file before checking the summary", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      userInput: userInput().replace(
        "- epic_story_source_file: feature-story.md",
        "- epic_story_source_file: [UNFILLED]"
      )
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      "user_br_input.md -> epic_story_source_file is unfilled; rerun task-to-BR capture so the original story source is recorded"
    ]);
  });
});

test("validator does not accept a required reference that is only a substring", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: completeSummary().replace(
        canonicalSourceRefs,
        `- source_refs: archive/${captureRecordRef}; docs/feature-story.md.bak`
      )
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      `## 1. Document Meta -> source_refs must include the captured source reference: ${captureRecordRef}`,
      "## 1. Document Meta -> source_refs must include the captured source reference: feature-story.md"
    ]);
  });
});

test("validator accepts alternate order and an additional populated reference", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: completeSummary().replace(
        canonicalSourceRefs,
        `- source_refs: JIRA-AUTH-241 ; feature-story.md;${captureRecordRef}`
      )
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 0);
  });
});

test("validator reports the missing capture record before source-reference checks", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: completeSummary().replace(canonicalSourceRefs, "- source_refs: [UNFILLED]"),
      userInput: null
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, ["user_br_input.md is missing"]);
  });
});

test("validator returns exit code 2 when the target BR summary is missing", () => {
  withWorkspace((root) => {
    const featureDir = path.join(root, "projects", "project-a", "feature-alpha");
    writeFileSync(path.join(root, "seed.txt"), "seed");
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /Target BR summary not found:/);
  });
});

const ambiguousRejectionProblem =
  "ambiguity trigger `simple` remains in ### Negative and rejection cases -> rejection_cases; move the unresolved wording to missing_br_data.md as rised_item_N with rised=false and set that field to [UNFILLED], or record an answered rised=true item naming that field to confirm the wording";

function summaryWithSections(sections: string): string {
  return completeSummary().replace("## 15. Open Questions", `${sections}## 15. Open Questions`);
}

function ambiguousRejectionSummary(
  rejectionCases = "Unknown email, expired token, simple error."
): string {
  return summaryWithSections(`## 10. Failure Cases and Edge Cases
### Negative and rejection cases
- rejection_cases: ${rejectionCases}

`);
}

function repeatedTriggerSummary(): string {
  return ambiguousRejectionSummary().replace(
    "- BR-1: Approval requests above threshold require compliance review before release.",
    "- BR-1: Rejected approvals must show a simple non-sensitive message."
  );
}

function ledgerWithRisedItem(item: string, answered: boolean): string {
  return `# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
${item}

## 6. Latest User Answers
- answers: ${answered ? "Confirmed: the rejection response stays a simple non-sensitive message." : "[UNFILLED]"}

## 7. Loop Decision
- unresolved_after_stop: ${answered ? "none" : "Pending rejection-response clarification."}
`;
}

test("validator reports an ambiguity trigger in rejection_cases outside the legacy move list", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, { summary: ambiguousRejectionSummary() });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [ambiguousRejectionProblem]);
  });
});

test("validator passes once the ambiguous rejection value is externalized to the ledger", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: ambiguousRejectionSummary("[UNFILLED]"),
      missingData: ledgerWithRisedItem(
        "- rised_item_1: source=### Negative and rejection cases -> rejection_cases; rised=false; unresolved_item=What exact rejection response must the user receive?",
        false
      )
    });
    assert.equal(validateTaskToBr(featureDir, root).exitCode, 0);
  });
});

test("validator accepts a retained trigger confirmed by a matching rised=true ledger item", () => {
  for (const section of [
    "### Negative and rejection cases",
    "## 10. Failure Cases and Edge Cases"
  ]) {
    withWorkspace((root) => {
      const featureDir = createFeatureFixture(root, {
        summary: ambiguousRejectionSummary(),
        missingData: ledgerWithRisedItem(
          `- rised_item_1: source=${section} -> rejection_cases; rised=true; unresolved_item=Is the simple rejection message accepted as written?`,
          true
        )
      });
      assert.equal(validateTaskToBr(featureDir, root).exitCode, 0, section);
    });
  }
});

test("validator matches the confirming ledger locator through whitespace and case variants", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: ambiguousRejectionSummary(),
      missingData: ledgerWithRisedItem(
        "- rised_item_1: source=###   Negative And Rejection   Cases -> Rejection_Cases ; rised=true; unresolved_item=Is the simple rejection message accepted as written?",
        true
      )
    });
    assert.equal(validateTaskToBr(featureDir, root).exitCode, 0);
  });
});

test("validator keeps reporting a retained trigger for nonmatching or unanswered ledger items", () => {
  const cases = [
    {
      name: "different field",
      item: "- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=Is legal approval required?",
      answered: true
    },
    {
      name: "different section",
      item: "- rised_item_1: source=### Edge cases -> rejection_cases; rised=true; unresolved_item=Is the simple rejection message accepted?",
      answered: true
    },
    {
      name: "pending item",
      item: "- rised_item_1: source=### Negative and rejection cases -> rejection_cases; rised=false; unresolved_item=What exact rejection response must the user receive?",
      answered: false
    }
  ];

  for (const { name, item, answered } of cases) {
    withWorkspace((root) => {
      const featureDir = createFeatureFixture(root, {
        summary: ambiguousRejectionSummary(),
        missingData: ledgerWithRisedItem(item, answered)
      });
      const result = validateTaskToBr(featureDir, root);
      assert.equal(result.exitCode, 1, name);
      assert.deepEqual(result.problems, [ambiguousRejectionProblem], name);
    });
  }
});

test("validator does not scan metadata, raw source references, repo evidence, or artifact locators", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: summaryWithSections(`## 13. Existing-System Context
### 13.1 Repository: backend
- known_workarounds: Support runs the manual reset as needed.

## 16. Linked Artifacts
- title: TBD reset flow diagram

`)
        .replace(
          "### 2.1 Original request summary",
          `### 2.2 Raw source references
- related_docs: fast-track-notes.md, etc.

### 2.1 Original request summary`
        )
        .replace(
          "- source_type: User input",
          "- source_type: User input\n- feature_title: Fast reset"
        )
    });
    assert.equal(validateTaskToBr(featureDir, root).exitCode, 0);
  });
});

test("validator matches ambiguity triggers as whole words and phrases only", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: ambiguousRejectionSummary(
        "Faster retries and simplified logging are already covered."
      )
    });
    assert.equal(validateTaskToBr(featureDir, root).exitCode, 0);
  });

  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: ambiguousRejectionSummary("Approvers retry as needed.")
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      "ambiguity trigger `as needed` remains in ### Negative and rejection cases -> rejection_cases; move the unresolved wording to missing_br_data.md as rised_item_N with rised=false and set that field to [UNFILLED], or record an answered rised=true item naming that field to confirm the wording"
    ]);
  });
});

test("validator reports ambiguity alongside existing recoverable problems and keeps exit code 1", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: ambiguousRejectionSummary().replace(
        "- critical_questions: [UNFILLED]",
        "- critical_questions: Is legal approval required for cross-region invoice routing?"
      )
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      "## 15. Open Questions -> unresolved items must be moved to missing_br_data.md as rised_item_N with rised=false",
      ambiguousRejectionProblem
    ]);
  });
});

test("validator reports one grouped problem when a trigger repeats across fields", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: repeatedTriggerSummary()
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      "ambiguity trigger `simple` remains in ## 7. Business Rules and Decision Logic -> BR-1, ### Negative and rejection cases -> rejection_cases; move the unresolved wording to missing_br_data.md as rised_item_N with rised=false and set those fields to [UNFILLED], or record an answered rised=true item naming those fields to confirm the wording"
    ]);
  });
});

test("validator clears a repeated trigger from one answered item naming both fields", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: repeatedTriggerSummary(),
      missingData: ledgerWithRisedItem(
        "- rised_item_1: source=### Negative and rejection cases -> rejection_cases, ## 7. Business Rules and Decision Logic -> BR-1; rised=true; unresolved_item=Is the simple rejection message accepted in rejection_cases and BR-1?",
        true
      )
    });
    assert.equal(validateTaskToBr(featureDir, root).exitCode, 0);
  });
});

test("validator keeps reporting fields an answered item does not name", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: repeatedTriggerSummary(),
      missingData: ledgerWithRisedItem(
        "- rised_item_1: source=### Negative and rejection cases -> rejection_cases; rised=true; unresolved_item=Is the simple rejection message accepted?",
        true
      )
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      "ambiguity trigger `simple` remains in ## 7. Business Rules and Decision Logic -> BR-1; move the unresolved wording to missing_br_data.md as rised_item_N with rised=false and set that field to [UNFILLED], or record an answered rised=true item naming that field to confirm the wording"
    ]);
  });
});

test("validator groups each trigger separately", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: ambiguousRejectionSummary("Rejections are handled as needed.").replace(
        "- BR-1: Approval requests above threshold require compliance review before release.",
        "- BR-1: Rejected approvals must show a simple non-sensitive message."
      )
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.equal(result.problems.length, 2);
    assert.match(result.problems[0] ?? "", /^ambiguity trigger `simple` remains in ## 7\./);
    assert.match(
      result.problems[1] ?? "",
      /^ambiguity trigger `as needed` remains in ### Negative/
    );
  });
});

test("validator reports every trigger a single field carries", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: ambiguousRejectionSummary("Provide a fast and simple response as needed.")
    });
    const result = validateTaskToBr(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(
      result.problems.map((problem) => problem.match(/^ambiguity trigger `([^`]+)`/)?.[1]),
      ["fast", "simple", "as needed"]
    );
    for (const problem of result.problems) {
      assert.match(problem, /remains in ### Negative and rejection cases -> rejection_cases;/);
    }
  });
});

test("validator clears every trigger of a field the ledger confirms", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: ambiguousRejectionSummary("Provide a fast and simple response as needed."),
      missingData: ledgerWithRisedItem(
        "- rised_item_1: source=### Negative and rejection cases -> rejection_cases; rised=true; unresolved_item=Is the fast, simple, as-needed rejection wording accepted as written?",
        true
      )
    });
    assert.equal(validateTaskToBr(featureDir, root).exitCode, 0);
  });
});
