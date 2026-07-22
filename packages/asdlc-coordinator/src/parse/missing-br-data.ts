import { isUnfilled, parseBulletField, readRequiredTextFile } from "./markdown.js";

import type { MissingBrData, RisedItem, RisedItemSource } from "../types/index.js";

/** Locator text stops at the ledger separator so free-form item text cannot leak in. */
const LEDGER_SOURCE_PATTERN = /source\s*=\s*([^;]+)(?:;|$)/i;

export function normalizeLedgerLocatorPart(value: string): string {
  return value.trim().replace(/\s+/g, " ").toLowerCase();
}

/**
 * Reads every `<section> -> <field>` locator of one ledger item. A single answered
 * question often covers several BR fields that restate the same fact, so an item
 * may list them comma-separated; a one-locator item is the same syntax with one
 * element. Parts without `->` are skipped rather than guessed at.
 */
export function parseRisedItemSources(line: string): RisedItemSource[] {
  const payload = line.match(LEDGER_SOURCE_PATTERN)?.[1];
  if (payload === undefined) {
    return [];
  }

  const sources: RisedItemSource[] = [];
  for (const part of payload.split(",")) {
    const separator = part.indexOf("->");
    if (separator < 0) {
      continue;
    }
    const section = normalizeLedgerLocatorPart(part.slice(0, separator));
    const field = normalizeLedgerLocatorPart(part.slice(separator + 2));
    if (section !== "" && field !== "") {
      sources.push({ section, field });
    }
  }
  return sources;
}

export function readMissingBrData(filePath: string): MissingBrData {
  const content = readRequiredTextFile(filePath);
  const lines = content.split(/\r?\n/);
  const risedItems: RisedItem[] = [];
  let inUnresolvedLedger = false;
  let inLatestAnswers = false;
  let inLoopDecision = false;
  let hasFilledAnswer = false;
  let hasFilledUnresolvedAfterStop = false;
  let unresolvedAfterStop: string | undefined;

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
      risedItems.push({ id, raw: line, risedState, sources: parseRisedItemSources(line) });
    }

    const field = parseBulletField(line);
    if (!field) {
      continue;
    }

    if (inLatestAnswers && field.key === "answers" && !isUnfilled(field.value)) {
      hasFilledAnswer = true;
    }
    if (inLoopDecision && field.key === "unresolved_after_stop") {
      // The terminal contract is an exact literal, so a quoted variant must not
      // normalize into a pass. The pending path keeps the normalized value: a
      // pending summary is free text, where quoting carries no meaning.
      unresolvedAfterStop = field.rawValue;
      if (!isUnfilled(field.value)) {
        hasFilledUnresolvedAfterStop = true;
      }
    }
  }

  return {
    path: filePath,
    content,
    risedItems,
    hasFilledAnswer,
    hasFilledUnresolvedAfterStop,
    unresolvedAfterStop
  };
}
