import { realpathSync } from "node:fs";
import path from "node:path";

import { displayPath, isUnfilled } from "./markdown.js";

/** Serialization used for `source_refs` values and the context binding. */
export const SOURCE_REF_SEPARATOR = "; ";

export interface CapturedSourceRefs {
  /** Workspace-relative path to the durable capture record. */
  captureRecordRef: string;
  /** Trimmed `epic_story_source_file` locator, absent when the field is unfilled. */
  originalSourceRef?: string;
  /** True when `epic_story_source_file` cannot complete the required set. */
  originalSourceUnfilled: boolean;
  /** Canonical required references, capture record first, duplicates removed. */
  required: string[];
}

/**
 * Derive the canonical captured-source reference set from an already-read
 * `user_br_input.md`. Task-to-BR context and the task-to-BR gate share this
 * derivation so their expected values cannot drift.
 */
export function deriveCapturedSourceRefs(options: {
  userInputPath: string;
  epicStorySourceFile: string | undefined;
  cwd: string;
}): CapturedSourceRefs {
  // Resolve symlinks on both sides so the capture record stays workspace-relative
  // when the workspace root and the caller's cwd spell the same directory
  // differently (for example /var vs /private/var on macOS).
  const captureRecordRef = displayPath(
    canonicalFilePath(options.userInputPath),
    canonicalDirPath(options.cwd)
  );
  const originalSourceUnfilled = isUnfilled(options.epicStorySourceFile);
  const originalSourceRef = originalSourceUnfilled
    ? undefined
    : (options.epicStorySourceFile as string).trim();

  const required: string[] = [];
  for (const ref of [captureRecordRef, originalSourceRef]) {
    if (ref !== undefined && ref !== "" && !required.includes(ref)) {
      required.push(ref);
    }
  }

  return { captureRecordRef, originalSourceRef, originalSourceUnfilled, required };
}

/** Realpath a directory, falling back to a lexical resolve when it does not exist. */
function canonicalDirPath(dirPath: string): string {
  try {
    return realpathSync(dirPath);
  } catch {
    return path.resolve(dirPath);
  }
}

/** Realpath a file's directory and rejoin its basename, so a missing file still normalizes. */
function canonicalFilePath(filePath: string): string {
  const resolved = path.resolve(filePath);
  return path.join(canonicalDirPath(path.dirname(resolved)), path.basename(resolved));
}

/** Resolve the capture-record path for a feature directory. */
export function capturedUserInputPath(featureDir: string): string {
  return path.join(featureDir, "user_br_input.md");
}

/** Split a `source_refs` value into exact, whitespace-trimmed elements. */
export function parseSourceRefs(value: string): string[] {
  return value
    .split(";")
    .map((element) => element.trim())
    .filter((element) => element !== "");
}

/** Render references as the canonical semicolon-delimited value. */
export function formatSourceRefs(refs: string[]): string {
  return refs.join(SOURCE_REF_SEPARATOR);
}
