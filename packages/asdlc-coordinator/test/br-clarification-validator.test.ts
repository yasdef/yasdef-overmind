import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import { validateBrClarification } from "../src/validate/br-clarification.js";

import { completeSummary, createFeatureFixture, emptyMissingData } from "./fixtures.js";

const bundlePath = fileURLToPath(new URL("../overmind.js", import.meta.url));

function withWorkspace(fn: (root: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-br-clarification-validator-"));
  try {
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function missingDataWithLedger(entries: string): string {
  return `# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
${entries}

## 6. Latest User Answers
- answers: This was recorded in ## 7. Business Rules and Decision Logic - BR-1.

## 7. Loop Decision
- unresolved_after_stop: Pending business clarification.
`;
}

test("br-clarification validator passes when ledger is empty or all rised", () => {
  withWorkspace((root) => {
    const emptyFeature = createFeatureFixture(root, { missingData: emptyMissingData() });
    assert.equal(validateBrClarification(emptyFeature, root).exitCode, 0);
  });

  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      missingData: missingDataWithLedger(
        "- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=Answered?"
      )
    });
    assert.equal(validateBrClarification(featureDir, root).exitCode, 0);
  });
});

test("br-clarification validator fails explicit rised=false with actionable missing line", () => {
  for (const entry of [
    "- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=false; unresolved_item=A?"
  ]) {
    withWorkspace((root) => {
      const featureDir = createFeatureFixture(root, { missingData: missingDataWithLedger(entry) });
      const result = validateBrClarification(featureDir, root);
      assert.equal(result.exitCode, 1);
      assert.deepEqual(result.problems, [
        "missing_br_data.md -> unresolved user BR clarification items remain; continue until every rised_item_N is rised=true"
      ]);
    });
  }
});

test("br-clarification validator surfaces invalid rised markers as base task-to-br failure", () => {
  for (const entry of [
    "- rised_item_1: source=## 15. Open Questions -> critical_questions; non-rised; unresolved_item=A?",
    "- rised_item_1: source=## 15. Open Questions -> critical_questions; not-rised; unresolved_item=A?",
    "- rised_item_1: source=## 15. Open Questions -> critical_questions; unresolved_item=A?"
  ]) {
    withWorkspace((root) => {
      const featureDir = createFeatureFixture(root, { missingData: missingDataWithLedger(entry) });
      const result = validateBrClarification(featureDir, root);
      assert.equal(result.exitCode, 1);
      assert.deepEqual(result.problems, [
        "missing_br_data.md -> every unresolved ledger item must include rised=false or rised=true"
      ]);
    });
  }
});

test("br-clarification validator surfaces base task-to-br failure verbatim", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: completeSummary().replace("- source_type: User input", "- source_type: Story")
    });
    const result = validateBrClarification(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.problems, [
      "## 1. Document Meta -> source_type must include User input"
    ]);
  });
});

test("overmind gate br-clarification prints progress for base task-to-br failure", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: completeSummary().replace("- source_type: User input", "- source_type: Story")
    });
    const result = spawnSync(
      process.execPath,
      [bundlePath, "gate", "br-clarification", featureDir],
      {
        cwd: root,
        encoding: "utf8"
      }
    );
    assert.equal(result.status, 1);
    assert.match(
      result.stdout,
      /^rule 1: task-to-br base business-context validation \.\.\. FAIL/m
    );
    assert.match(
      result.stdout,
      /^missing: ## 1\. Document Meta -> source_type must include User input/m
    );
  });
});

test("br-clarification validator exits 2 on runtime target error", () => {
  withWorkspace((root) => {
    const result = validateBrClarification(path.join(root, "missing-feature"), root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /Target BR summary not found:/);
  });
});

test("overmind gate br-clarification exits 1 with missing line for unresolved ledger", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      missingData: missingDataWithLedger(
        "- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=false; unresolved_item=A?"
      )
    });
    const result = spawnSync(
      process.execPath,
      [bundlePath, "gate", "br-clarification", featureDir],
      {
        cwd: root,
        encoding: "utf8"
      }
    );
    assert.equal(result.status, 1);
    assert.match(
      result.stdout,
      /^rule 1: task-to-br base business-context validation \.\.\. PASS/m
    );
    assert.match(
      result.stdout,
      /^rule 2: missing_br_data unresolved BR clarification ledger \.\.\. FAIL/m
    );
    assert.match(result.stdout, /^business-context gate failed/m);
    assert.match(
      result.stdout,
      /^missing: missing_br_data\.md -> unresolved user BR clarification items remain/m
    );
  });
});

test("overmind gate br-clarification exits 0 for all-rised ledger", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      missingData: missingDataWithLedger(
        "- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=A?"
      )
    });
    const result = spawnSync(
      process.execPath,
      [bundlePath, "gate", "br-clarification", featureDir],
      {
        cwd: root,
        encoding: "utf8"
      }
    );
    assert.equal(result.status, 0);
    assert.match(
      result.stdout,
      /^rule 1: task-to-br base business-context validation \.\.\. PASS/m
    );
    assert.match(
      result.stdout,
      /^rule 2: missing_br_data unresolved BR clarification ledger \.\.\. PASS/m
    );
    assert.match(
      result.stdout,
      /^rule 3: BR clarification is complete for EARS readiness \.\.\. PASS/m
    );
    assert.match(result.stdout, /^business-context gate passed/m);
  });
});
