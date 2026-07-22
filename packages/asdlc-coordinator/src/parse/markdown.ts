import { existsSync, readFileSync, statSync } from "node:fs";
import path from "node:path";

import type { FeatureArtifacts } from "../types/index.js";

export function trimValue(value: string): string {
  return value.trim();
}

export function stripQuotes(value: string): string {
  const trimmed = trimValue(value);
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

export function normalizeValue(value: string): string {
  return stripQuotes(trimValue(value));
}

export function isUnfilled(value: string | undefined): boolean {
  if (value === undefined) {
    return true;
  }
  const normalized = normalizeValue(value);
  return normalized === "" || normalized.toUpperCase() === "[UNFILLED]";
}

/**
 * Splits a `- key: value` bullet into its parts.
 *
 * `value` is normalized (trimmed and unquoted) because quoting is presentational
 * for almost every field. `rawValue` is only trimmed, for the rare field whose
 * contract is an exact literal and must therefore reject a quoted variant.
 */
export function parseBulletField(
  line: string
): { key: string; value: string; rawValue: string } | undefined {
  const normalized = line.replace(/^\s*-\s*/, "");
  const colonIndex = normalized.indexOf(":");
  if (colonIndex < 0) {
    return undefined;
  }
  const key = trimValue(normalized.slice(0, colonIndex));
  if (key === "") {
    return undefined;
  }
  const rawValue = trimValue(normalized.slice(colonIndex + 1));
  return {
    key,
    value: stripQuotes(rawValue),
    rawValue
  };
}

export function readRequiredTextFile(filePath: string): string {
  return readFileSync(filePath, "utf8");
}

export function resolveInputPath(inputPath: string, cwd = process.cwd()): string {
  return path.isAbsolute(inputPath) ? path.normalize(inputPath) : path.resolve(cwd, inputPath);
}

export function resolveTaskToBrArtifacts(inputPath: string, cwd = process.cwd()): FeatureArtifacts {
  const resolved = resolveInputPath(inputPath, cwd);
  let featureDir = resolved;
  let targetBrPath = path.join(resolved, "feature_br_summary.md");

  if (existsSync(resolved) && statSync(resolved).isFile()) {
    featureDir = path.dirname(resolved);
    targetBrPath = resolved;
  }

  return {
    featureDir,
    targetBrPath,
    userInputPath: path.join(featureDir, "user_br_input.md"),
    missingDataPath: path.join(featureDir, "missing_br_data.md")
  };
}

export function displayPath(filePath: string, cwd = process.cwd()): string {
  const relative = path.relative(cwd, filePath);
  if (relative !== "" && !relative.startsWith("..") && !path.isAbsolute(relative)) {
    return relative;
  }
  return filePath;
}

export function getBlockField(content: string, fieldName: string): string {
  const lines = content.split(/\r?\n/);
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index]!;
    if (!new RegExp(`^-\\s+${escapeRegExp(fieldName)}:\\s*\\|\\s*$`).test(line)) {
      continue;
    }

    const blockLines: string[] = [];
    for (let cursor = index + 1; cursor < lines.length; cursor += 1) {
      const candidate = lines[cursor]!;
      if (isBlockBoundary(candidate)) {
        break;
      }
      if (candidate.startsWith("  ")) {
        blockLines.push(candidate.slice(2));
      } else if (candidate.trim() === "") {
        blockLines.push("");
      }
    }
    return blockLines.join("\n").trimEnd();
  }
  return "";
}

export function getScalarField(content: string, fieldName: string): string | undefined {
  for (const line of scalarFieldLines(content)) {
    const field = parseBulletField(line);
    if (field?.key === fieldName) {
      return field.value;
    }
  }
  return undefined;
}

/**
 * Document lines eligible to hold a scalar field, with `key: |` block bodies removed.
 *
 * A block body is indented free text — a captured story, a pasted Jira description —
 * so a bullet-shaped line inside it is content, not a field. `parseBulletField`
 * tolerates leading whitespace, so without this filter a body line such as
 * `  - request_summary: ...` parses as the document's `request_summary`, and
 * because scanning returns the first match it wins over the real field written
 * after the block. Block termination mirrors `getBlockField`, so both parsers
 * agree on where a body ends.
 */
function scalarFieldLines(content: string): string[] {
  const lines: string[] = [];
  let inBlockBody = false;

  for (const line of content.split(/\r?\n/)) {
    if (inBlockBody) {
      if (!isBlockBoundary(line)) {
        continue;
      }
      inBlockBody = false;
    }
    if (isBlockFieldStart(line)) {
      inBlockBody = true;
      continue;
    }
    lines.push(line);
  }

  return lines;
}

function isBlockFieldStart(line: string): boolean {
  return /^-\s+[A-Za-z0-9_-]+:\s*\|\s*$/.test(line);
}

function isBlockBoundary(line: string): boolean {
  return /^-\s+[A-Za-z0-9_-]+:\s*/.test(line) || /^##\s+/.test(line);
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
