import { readFileSync, writeFileSync } from "node:fs";

import { normalizeValue, parseBulletField } from "./markdown.js";

export interface UnresolvedRisedItem {
  id: string;
  raw: string;
}

export function findUnresolvedRisedItems(content: string): UnresolvedRisedItem[] {
  const unresolved: UnresolvedRisedItem[] = [];
  let inUnresolvedLedger = false;

  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (/^##\s+/.test(trimmed)) {
      inUnresolvedLedger = /^##\s+3\.\s+Unresolved\s+Items\s+Ledger\s+\(Rised\)\s*$/.test(trimmed);
      continue;
    }
    if (!inUnresolvedLedger) {
      continue;
    }

    const lowered = trimmed.toLowerCase();
    if (!/^-\s*rised_item_[0-9]+:\s*/.test(lowered)) {
      continue;
    }

    if (
      /non-rised|not-rised|rised\s*=\s*false|rised:\s*false/.test(lowered) ||
      (!/rised\s*=\s*true/.test(lowered) && !/rised:\s*true/.test(lowered))
    ) {
      unresolved.push({
        id: trimmed.match(/rised_item_[0-9]+/)?.[0] ?? "rised_item_unknown",
        raw: line
      });
    }
  }

  return unresolved;
}

export function readDocumentMetaValue(content: string, targetKey: string): string | undefined {
  let inMeta = false;

  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (/^##\s+/.test(trimmed)) {
      inMeta = /^##\s+1\.\s+Document\s+Meta\s*$/.test(trimmed);
      continue;
    }
    if (!inMeta) {
      continue;
    }

    const field = parseBulletField(line);
    if (field?.key === targetKey) {
      return normalizeValue(field.value);
    }
  }

  return undefined;
}

export function flipReadyToEarsFalseToTrue(filePath: string): void {
  const content = readFileSync(filePath, "utf8");
  const currentValue = readDocumentMetaValue(content, "ready_to_ears");
  if (currentValue === undefined) {
    throw new Error("Missing key ready_to_ears in ## 1. Document Meta");
  }
  if (currentValue !== "false") {
    throw new Error(`Expected ready_to_ears to be false before readiness check; found '${currentValue}'.`);
  }

  let inMeta = false;
  let updated = false;
  const lines = content.split(/\r?\n/).map((line) => {
    const trimmed = line.trim();
    if (/^##\s+/.test(trimmed)) {
      inMeta = /^##\s+1\.\s+Document\s+Meta\s*$/.test(trimmed);
      return line;
    }
    if (!inMeta || updated) {
      return line;
    }

    const withoutBullet = line.replace(/^(\s*-\s*)/, "");
    const colonIndex = withoutBullet.indexOf(":");
    if (colonIndex < 0) {
      return line;
    }
    const key = withoutBullet.slice(0, colonIndex).trim();
    if (key !== "ready_to_ears") {
      return line;
    }

    updated = true;
    return line.replace(/:\s*.*/, ": true");
  });

  if (!updated) {
    throw new Error("Failed to update ready_to_ears in ## 1. Document Meta");
  }
  writeFileSync(filePath, lines.join("\n"), "utf8");
}
