import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import {
  findUnresolvedRisedItems,
  flipReadyToEarsFalseToTrue,
  readDocumentMetaValue
} from "../src/parse/br-summary.js";

function withWorkspace(fn: (root: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-br-summary-parser-"));
  try {
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test("findUnresolvedRisedItems detects false, non-rised, not-rised, and missing flags", () => {
  const content = `# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=false; unresolved_item=A?
- rised_item_2: source=## 15. Open Questions -> critical_questions; non-rised; unresolved_item=B?
- rised_item_3: source=## 15. Open Questions -> critical_questions; not-rised; unresolved_item=C?
- rised_item_4: source=## 15. Open Questions -> critical_questions; unresolved_item=D?
- rised_item_5: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=E?
`;

  assert.deepEqual(
    findUnresolvedRisedItems(content).map((item) => item.id),
    ["rised_item_1", "rised_item_2", "rised_item_3", "rised_item_4"]
  );
});

test("findUnresolvedRisedItems ignores quoted examples and non-ledger lines", () => {
  const content = `# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
> - rised_item_1: rised=false; example only
"- rised_item_2: rised=false; quoted example only"
- other_item_1: rised=false
- rised_item_3: rised=true; unresolved_item=Answered
`;

  assert.deepEqual(findUnresolvedRisedItems(content), []);
});

test("document meta reader strips quotes and readiness flip enforces false precondition", () => {
  withWorkspace((root) => {
    const filePath = path.join(root, "feature_br_summary.md");
    writeFileSync(
      filePath,
      `# Feature Business Requirements Summary

## 1. Document Meta
- source_type: "User input"
- ready_to_ears: "false"

## 2. Source Request Snapshot
`
    );

    const content = readFileSync(filePath, "utf8");
    assert.equal(readDocumentMetaValue(content, "source_type"), "User input");
    assert.equal(readDocumentMetaValue(content, "ready_to_ears"), "false");

    flipReadyToEarsFalseToTrue(filePath);
    assert.match(readFileSync(filePath, "utf8"), /- ready_to_ears: true/);
    assert.throws(() => flipReadyToEarsFalseToTrue(filePath), /Expected ready_to_ears to be false/);
  });
});

test("readiness flip fails when ready_to_ears is absent", () => {
  withWorkspace((root) => {
    const filePath = path.join(root, "feature_br_summary.md");
    writeFileSync(
      filePath,
      "# Feature Business Requirements Summary\n\n## 1. Document Meta\n- source_type: User input\n"
    );
    assert.throws(() => flipReadyToEarsFalseToTrue(filePath), /Missing key ready_to_ears/);
  });
});
