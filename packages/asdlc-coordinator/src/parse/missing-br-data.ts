import { isUnfilled, parseBulletField, readRequiredTextFile } from "./markdown.js";

import type { MissingBrData, RisedItem } from "../types/index.js";

export function readMissingBrData(filePath: string): MissingBrData {
  const content = readRequiredTextFile(filePath);
  const lines = content.split(/\r?\n/);
  const risedItems: RisedItem[] = [];
  let inUnresolvedLedger = false;
  let inLatestAnswers = false;
  let inLoopDecision = false;
  let hasFilledAnswer = false;
  let hasFilledUnresolvedAfterStop = false;

  for (const line of lines) {
    const trimmed = line.trim();
    if (/^##\s+/.test(trimmed)) {
      inUnresolvedLedger = /^##\s+3\.\s+Unresolved\s+Items\s+Ledger\s+\(Rised\)\s*$/.test(trimmed);
      inLatestAnswers = /^##\s+6\.\s+Latest\s+User\s+Answers\s*$/.test(trimmed);
      inLoopDecision = /^##\s+7\.\s+Loop\s+Decision\s*$/.test(trimmed);
      continue;
    }

    if (inUnresolvedLedger && /^\s*-\s*rised_item_[0-9]+:\s*/.test(line)) {
      const lowered = line.toLowerCase();
      let risedState: RisedItem["risedState"] = "missing";
      if (/rised\s*=\s*false/.test(lowered) || /rised:\s*false/.test(lowered)) {
        risedState = "false";
      } else if (/rised\s*=\s*true/.test(lowered) || /rised:\s*true/.test(lowered)) {
        risedState = "true";
      }
      const id = line.match(/rised_item_[0-9]+/)?.[0] ?? "rised_item_unknown";
      risedItems.push({ id, raw: line, risedState });
    }

    const field = parseBulletField(line);
    if (!field) {
      continue;
    }

    if (inLatestAnswers && field.key === "answers" && !isUnfilled(field.value)) {
      hasFilledAnswer = true;
    }
    if (inLoopDecision && field.key === "unresolved_after_stop" && !isUnfilled(field.value)) {
      hasFilledUnresolvedAfterStop = true;
    }
  }

  return {
    path: filePath,
    content,
    risedItems,
    hasFilledAnswer,
    hasFilledUnresolvedAfterStop
  };
}
