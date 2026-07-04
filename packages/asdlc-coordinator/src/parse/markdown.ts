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

export function parseBulletField(line: string): { key: string; value: string } | undefined {
  const normalized = line.replace(/^\s*-\s*/, "");
  const colonIndex = normalized.indexOf(":");
  if (colonIndex < 0) {
    return undefined;
  }
  const key = trimValue(normalized.slice(0, colonIndex));
  if (key === "") {
    return undefined;
  }
  return {
    key,
    value: normalizeValue(normalized.slice(colonIndex + 1))
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
      if (/^-\s+[A-Za-z0-9_-]+:\s*/.test(candidate) || /^##\s+/.test(candidate)) {
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
  const lines = content.split(/\r?\n/);
  for (const line of lines) {
    const field = parseBulletField(line);
    if (field?.key === fieldName) {
      return field.value;
    }
  }
  return undefined;
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
