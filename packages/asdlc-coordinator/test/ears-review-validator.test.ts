import { chmodSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import { validateEarsReview } from "../src/validate/ears-review.js";
import { createFeatureFixture } from "./fixtures.js";

const bundlePath = fileURLToPath(new URL("../overmind.js", import.meta.url));

function withWorkspace(fn: (root: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-ears-review-validator-"));
  try {
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function writeReview(featureDir: string, content: string): void {
  mkdirSync(featureDir, { recursive: true });
  writeFileSync(path.join(featureDir, "requirements_ears_review.md"), content, "utf8");
}

function validReview(): string {
  return `# Requirements EARS Extra Review

## 1. Document Meta
- feature_id: FEAT-REVIEW-001
- feature_title: Payments access review
- source_feature_br_summary: projects/project-a/feature-alpha/feature_br_summary.md
- source_requirements_ears: projects/project-a/feature-alpha/requirements_ears.md
- review_status: complete
- last_updated: 2026-04-11

## 2. Review Guidance
- completion_rule: Set review_status complete only when every finding is terminal.
- pending_state: escalated
- allowed_severity: High, Medium, Low
- user_question_format: Here is the finding: <finding summary>. I would recommend: <recommended change>. Should I add recommended changes? Please answer yes/no or provide your answer.

## 3. Findings Ledger
### Finding 1 - Close missing ACTIVE guard
- severity: Medium
- state: added to ears
- source_br_summary_reference: feature_br_summary.md -> access guard notes
- related_requirement_targets: Requirement 8, Requirement 10
- gap_summary: ACTIVE was missing after authentication.
- recommendation: Add explicit ACTIVE post-auth guard.
- suggested_ears_change: Update the affected requirements and add a new guard requirement if needed.
- user_prompt: Here is the finding: ACTIVE was missing after authentication. I would recommend: add explicit ACTIVE post-auth guard behavior in requirements_ears.md. Should I add recommended changes? Please answer yes/no or provide your answer.
- user_response: yes
- resolution_notes: Added ACTIVE guard wording to the affected requirements.
`;
}

function noFindingsReview(): string {
  return `# Requirements EARS Extra Review

## 1. Document Meta
- feature_id: FEAT-REVIEW-001
- feature_title: Payments access review
- source_feature_br_summary: projects/project-a/feature-alpha/feature_br_summary.md
- source_requirements_ears: projects/project-a/feature-alpha/requirements_ears.md
- review_status: complete
- last_updated: 2026-04-11

## 2. Review Guidance
- completion_rule: Set review_status complete only when every finding is terminal.

## 3. Findings Ledger
- no_findings: true
`;
}

test("ears-review validator passes valid complete ledger", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    writeReview(featureDir, validReview());

    const result = validateEarsReview(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 0);
    assert.match(result.passMessage, /quality gate passed/);
  });
});

test("ears-review validator accepts no_findings complete ledger", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    writeReview(featureDir, noFindingsReview());

    const result = validateEarsReview(featureDir, root);
    assert.equal(result.exitCode, 0);
  });
});

test("ears-review validator exits 2 when target argument or artifact is missing", () => {
  withWorkspace((root) => {
    const missingArg = validateEarsReview("", root);
    assert.equal(missingArg.exitCode, 2);
    assert.match(
      missingArg.errorMessage ?? "",
      /Missing target requirements ears review path argument/
    );

    const featureDir = createFeatureFixture(root);
    const missingTarget = validateEarsReview(featureDir, root);
    assert.equal(missingTarget.exitCode, 2);
    assert.match(
      missingTarget.errorMessage ?? "",
      /Target requirements ears review artifact not found:/
    );
  });
});

test("ears-review validator exits 2 when target is a directory or unreadable", (t) => {
  if (process.platform === "win32") {
    t.skip("POSIX permissions are required for this unreadable-file case.");
    return;
  }

  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    mkdirSync(path.join(featureDir, "requirements_ears_review.md"));
    const directoryResult = validateEarsReview(featureDir, root);
    assert.equal(directoryResult.exitCode, 2);
    assert.match(directoryResult.errorMessage ?? "", /is a directory:/);

    rmSync(path.join(featureDir, "requirements_ears_review.md"), { recursive: true, force: true });
    writeReview(featureDir, validReview());
    const targetPath = path.join(featureDir, "requirements_ears_review.md");
    chmodSync(targetPath, 0o000);
    try {
      const unreadable = validateEarsReview(featureDir, root);
      assert.equal(unreadable.exitCode, 2);
      assert.match(unreadable.errorMessage ?? "", /EACCES|permission denied/i);
    } finally {
      chmodSync(targetPath, 0o644);
    }
  });
});

test("ears-review validator exits 1 for empty and unfilled target", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    writeReview(featureDir, "   \n\t\n");
    const empty = validateEarsReview(featureDir, root);
    assert.equal(empty.exitCode, 1);
    assert.match(empty.problems.join("\n"), /target requirements ears review artifact is empty/);

    writeReview(
      featureDir,
      validReview().replace("- user_response: yes", "- user_response: [UNFILLED]")
    );
    const unfilled = validateEarsReview(featureDir, root);
    assert.equal(unfilled.exitCode, 1);
    assert.match(unfilled.problems.join("\n"), /artifact still contains \[UNFILLED\] placeholders/);
  });
});

test("ears-review validator reports missing sections and meta keys", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    writeReview(
      featureDir,
      validReview()
        .replace("## 2. Review Guidance", "## 2. Missing")
        .replace("- feature_title: Payments access review\n", "")
    );

    const result = validateEarsReview(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.match(result.problems.join("\n"), /missing section: ## 2\. Review Guidance/);
    assert.match(result.problems.join("\n"), /missing or unfilled meta key: feature_title/);
  });
});

test("ears-review validator reports missing finding field and invalid severity or state", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    writeReview(
      featureDir,
      validReview()
        .replace("- source_br_summary_reference: feature_br_summary.md -> access guard notes\n", "")
        .replace("- severity: Medium", "- severity: Critical")
        .replace("- state: added to ears", "- state: pending")
    );

    const result = validateEarsReview(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.match(
      result.problems.join("\n"),
      /finding block 1 missing or unfilled key: source_br_summary_reference/
    );
    assert.match(result.problems.join("\n"), /finding block 1 has invalid severity: Critical/);
    assert.match(result.problems.join("\n"), /finding block 1 has invalid state: pending/);
  });
});

test("ears-review validator normalizes quoted and spaced finding state", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    writeReview(
      featureDir,
      validReview().replace("- state: added to ears", '- state: "added   to   ears"')
    );

    const result = validateEarsReview(featureDir, root);
    assert.equal(result.exitCode, 0);
  });
});

test("ears-review validator enforces no_findings and review_status consistency", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);

    writeReview(
      featureDir,
      noFindingsReview().replace("- no_findings: true", "- no_findings: false")
    );
    const missingNoFindings = validateEarsReview(featureDir, root);
    assert.equal(missingNoFindings.exitCode, 1);
    assert.match(missingNoFindings.problems.join("\n"), /must declare - no_findings: true/);

    writeReview(
      featureDir,
      noFindingsReview().replace("- review_status: complete", "- review_status: in_progress")
    );
    const incompleteNoFindings = validateEarsReview(featureDir, root);
    assert.equal(incompleteNoFindings.exitCode, 1);
    assert.match(
      incompleteNoFindings.problems.join("\n"),
      /review_status must be complete when no_findings is true/
    );

    writeReview(
      featureDir,
      validReview().replace("## 3. Findings Ledger", "## 3. Findings Ledger\n- no_findings: true")
    );
    const findingsWithNoFindings = validateEarsReview(featureDir, root);
    assert.equal(findingsWithNoFindings.exitCode, 1);
    assert.match(
      findingsWithNoFindings.problems.join("\n"),
      /no_findings must not be true when Finding blocks are present/
    );
  });
});

test("ears-review validator enforces review_status versus escalated findings", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);

    writeReview(featureDir, validReview().replace("- state: added to ears", "- state: escalated"));
    const completeWithEscalated = validateEarsReview(featureDir, root);
    assert.equal(completeWithEscalated.exitCode, 1);
    assert.match(
      completeWithEscalated.problems.join("\n"),
      /review_status is complete but escalated findings remain/
    );

    writeReview(
      featureDir,
      validReview().replace("- review_status: complete", "- review_status: in_progress")
    );
    const inProgressWithoutEscalated = validateEarsReview(featureDir, root);
    assert.equal(inProgressWithoutEscalated.exitCode, 1);
    assert.match(
      inProgressWithoutEscalated.problems.join("\n"),
      /review_status is in_progress but no escalated findings remain/
    );
  });
});

test("overmind gate ears-review uses common usage, unknown-step, and recoverable output", () => {
  withWorkspace((root) => {
    const missingArg = spawnSync(process.execPath, [bundlePath, "gate", "ears-review"], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(missingArg.status, 2);
    assert.match(missingArg.stderr, /ERROR: Usage: overmind gate <step> <path>/);

    const unknown = spawnSync(process.execPath, [bundlePath, "gate", "unknown-ears-review", "."], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(unknown.status, 2);
    assert.match(unknown.stderr, /ERROR: Unknown gate step: unknown-ears-review/);

    const featureDir = createFeatureFixture(root);
    writeReview(featureDir, "");
    const recoverable = spawnSync(
      process.execPath,
      [bundlePath, "gate", "ears-review", path.relative(root, featureDir)],
      {
        cwd: root,
        encoding: "utf8"
      }
    );
    assert.equal(recoverable.status, 1);
    assert.match(recoverable.stdout, /business-context gate failed/);
    assert.match(
      recoverable.stdout,
      /missing: quality gate failed: target requirements ears review artifact is empty:/
    );
  });
});
