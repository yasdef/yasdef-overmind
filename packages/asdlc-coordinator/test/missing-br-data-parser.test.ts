import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { normalizeLedgerLocatorPart, readMissingBrData } from "../src/parse/missing-br-data.js";

function withLedger(content: string, fn: (filePath: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-missing-br-data-"));
  try {
    const filePath = path.join(root, "missing_br_data.md");
    writeFileSync(filePath, content);
    fn(filePath);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function ledger(loopDecision: string): string {
  return `# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=A?

## 6. Latest User Answers
- answers: This was recorded in ## 7. Business Rules and Decision Logic - BR-1.

## 7. Loop Decision
${loopDecision}
`;
}

test("readMissingBrData exposes the trimmed terminal none token", () => {
  withLedger(ledger("- unresolved_after_stop:   none  "), (filePath) => {
    const data = readMissingBrData(filePath);
    assert.equal(data.unresolvedAfterStop, "none");
    assert.equal(data.hasFilledUnresolvedAfterStop, true);
  });
});

test("readMissingBrData keeps quotes around a quoted terminal token", () => {
  for (const quoted of ['"none"', "'none'"]) {
    withLedger(ledger(`- unresolved_after_stop: ${quoted}`), (filePath) => {
      const data = readMissingBrData(filePath);
      assert.equal(data.unresolvedAfterStop, quoted);
      assert.equal(data.hasFilledUnresolvedAfterStop, true);
    });
  }
});

test("readMissingBrData exposes a pending summary verbatim", () => {
  withLedger(ledger("- unresolved_after_stop: Waiting for user input."), (filePath) => {
    const data = readMissingBrData(filePath);
    assert.equal(data.unresolvedAfterStop, "Waiting for user input.");
    assert.equal(data.hasFilledUnresolvedAfterStop, true);
  });
});

test("readMissingBrData exposes an [UNFILLED] placeholder as its literal value", () => {
  withLedger(ledger("- unresolved_after_stop: [UNFILLED]"), (filePath) => {
    const data = readMissingBrData(filePath);
    assert.equal(data.unresolvedAfterStop, "[UNFILLED]");
    assert.equal(data.hasFilledUnresolvedAfterStop, false);
  });
});

test("readMissingBrData exposes an empty value as an empty string", () => {
  withLedger(ledger("- unresolved_after_stop:"), (filePath) => {
    const data = readMissingBrData(filePath);
    assert.equal(data.unresolvedAfterStop, "");
    assert.equal(data.hasFilledUnresolvedAfterStop, false);
  });
});

test("readMissingBrData leaves the value undefined when the field is absent", () => {
  withLedger(ledger(""), (filePath) => {
    const data = readMissingBrData(filePath);
    assert.equal(data.unresolvedAfterStop, undefined);
    assert.equal(data.hasFilledUnresolvedAfterStop, false);
  });
});

function ledgerWithItems(...items: string[]): string {
  return `# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
${items.join("\n")}

## 6. Latest User Answers
- answers: [UNFILLED]

## 7. Loop Decision
- unresolved_after_stop: Pending business clarification.
`;
}

test("readMissingBrData exposes the normalized source locator of a ledger item", () => {
  withLedger(
    ledgerWithItems(
      "- rised_item_1: source=### Negative and rejection cases -> rejection_cases; rised=false; unresolved_item=What exact rejection response is required?"
    ),
    (filePath) => {
      const [item] = readMissingBrData(filePath).risedItems;
      assert.deepEqual(item?.sources, [
        { section: "### negative and rejection cases", field: "rejection_cases" }
      ]);
    }
  );
});

test("readMissingBrData normalizes locator whitespace and case", () => {
  withLedger(
    ledgerWithItems(
      "- rised_item_1: source=##  10.   Failure Cases And Edge Cases   ->    Rejection_Cases  ; rised=true; unresolved_item=Confirmed wording."
    ),
    (filePath) => {
      const [item] = readMissingBrData(filePath).risedItems;
      assert.deepEqual(item?.sources, [
        { section: "## 10. failure cases and edge cases", field: "rejection_cases" }
      ]);
    }
  );
});

test("readMissingBrData stops the locator at the ledger separator", () => {
  withLedger(
    ledgerWithItems(
      "- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=false; unresolved_item=Does A -> B routing need approval?"
    ),
    (filePath) => {
      const [item] = readMissingBrData(filePath).risedItems;
      assert.deepEqual(item?.sources, [
        { section: "## 15. open questions", field: "critical_questions" }
      ]);
    }
  );
});

test("readMissingBrData leaves the locator list empty when it is absent or incomplete", () => {
  withLedger(
    ledgerWithItems(
      "- rised_item_1: rised=false; unresolved_item=No locator recorded.",
      "- rised_item_2: source=## 15. Open Questions; rised=false; unresolved_item=No field recorded.",
      "- rised_item_3: source= -> critical_questions; rised=false; unresolved_item=No section recorded."
    ),
    (filePath) => {
      const items = readMissingBrData(filePath).risedItems;
      assert.equal(items.length, 3);
      for (const item of items) {
        assert.deepEqual(item.sources, [], item.id);
      }
    }
  );
});

test("normalizeLedgerLocatorPart collapses whitespace and case", () => {
  assert.equal(normalizeLedgerLocatorPart("  ###   Needs  Validation "), "### needs validation");
});

test("readMissingBrData ignores an unresolved_after_stop outside the loop-decision section", () => {
  const content = `# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
- unresolved_after_stop: none

## 7. Loop Decision
- unresolved_after_stop: Waiting for user input.
`;
  withLedger(content, (filePath) => {
    assert.equal(readMissingBrData(filePath).unresolvedAfterStop, "Waiting for user input.");
  });
});

test("readMissingBrData reads every locator a single ledger item names", () => {
  withLedger(
    ledgerWithItems(
      "- rised_item_1: source=## 6. Functional Requirements -> FR-11, ### Recovery and retry expectations -> retry_or_recovery_expectations; rised=true; unresolved_item=What error content must the report show?"
    ),
    (filePath) => {
      const [item] = readMissingBrData(filePath).risedItems;
      assert.deepEqual(item?.sources, [
        { section: "## 6. functional requirements", field: "fr-11" },
        {
          section: "### recovery and retry expectations",
          field: "retry_or_recovery_expectations"
        }
      ]);
    }
  );
});

test("readMissingBrData skips locator parts that name no field", () => {
  withLedger(
    ledgerWithItems(
      "- rised_item_1: source=## 15. Open Questions -> critical_questions, ## 14. Assumptions; rised=false; unresolved_item=Partial locator list."
    ),
    (filePath) => {
      const [item] = readMissingBrData(filePath).risedItems;
      assert.deepEqual(item?.sources, [
        { section: "## 15. open questions", field: "critical_questions" }
      ]);
    }
  );
});
