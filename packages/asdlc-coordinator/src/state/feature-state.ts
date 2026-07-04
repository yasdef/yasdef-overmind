import { existsSync, mkdirSync, realpathSync, renameSync, statSync, writeFileSync } from "node:fs";
import { readFileSync } from "node:fs";
import path from "node:path";

import type { Diagnostic } from "../types/index.js";

/** Basename of the per-project JSON feature-state cache (replaces the shell `.env`). */
export const FEATURE_STATE_FILE_NAME = ".overmind_feature_state.json";

/** Basename of the retired shell state cache; recognized only to be ignored. */
export const LEGACY_FEATURE_STATE_FILE_NAME = ".project_add_feature_e2e_state.env";

export type FeatureStateReadState = "valid" | "stale" | "missing";

export interface FeatureStateReadResult {
  /** Workspace-relative feature path when the cache is `valid`. */
  featurePath?: string;
  state: FeatureStateReadState;
  /** Raw cached value when present (for a "ignoring stale cache" notice). */
  raw?: string;
  diagnostics: Diagnostic[];
  notices: string[];
}

export interface FeatureStateWriteResult {
  ok: boolean;
  diagnostics: Diagnostic[];
}

function stateFilePath(projectRoot: string): string {
  return path.join(projectRoot, FEATURE_STATE_FILE_NAME);
}

/**
 * Read `<project>/.overmind_feature_state.json`. The cached `featurePath` is
 * workspace-relative; it is only returned as `valid` when it resolves to an
 * existing directory that stays inside the workspace and under the selected
 * project. Missing, malformed, escaping, or no-longer-existing values degrade
 * to `stale`/`missing` with an actionable notice and never throw.
 */
export function readFeatureState(
  workspaceRoot: string,
  projectRoot: string
): FeatureStateReadResult {
  const filePath = stateFilePath(projectRoot);
  if (!existsSync(filePath)) {
    return { state: "missing", diagnostics: [], notices: [] };
  }

  let raw: string;
  try {
    raw = readFileSync(filePath, "utf8");
  } catch (error) {
    return {
      state: "stale",
      diagnostics: [
        {
          severity: "warning",
          source: filePath,
          reason: `Unable to read feature-state cache: ${message(error)}`
        }
      ],
      notices: ["Ignoring unreadable saved feature_path cache."]
    };
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return {
      state: "stale",
      diagnostics: [
        {
          severity: "warning",
          source: filePath,
          reason: "Malformed feature-state cache JSON; ignoring."
        }
      ],
      notices: ["Ignoring malformed saved feature_path cache."]
    };
  }

  const cachedValue =
    parsed &&
    typeof parsed === "object" &&
    typeof (parsed as { featurePath?: unknown }).featurePath === "string"
      ? (parsed as { featurePath: string }).featurePath.trim()
      : undefined;

  if (!cachedValue) {
    return {
      state: "stale",
      diagnostics: [
        {
          severity: "warning",
          source: filePath,
          reason: "Feature-state cache is missing a string 'featurePath'; ignoring."
        }
      ],
      notices: ["Ignoring malformed saved feature_path cache."]
    };
  }

  const candidate = path.resolve(workspaceRoot, cachedValue);
  // Guard the stat directly (no separate existsSync): a missing directory — or one
  // that disappears mid-check — must degrade to stale, never throw ENOENT.
  let candidateIsDirectory = false;
  try {
    candidateIsDirectory = statSync(candidate).isDirectory();
  } catch {
    candidateIsDirectory = false;
  }
  if (!candidateIsDirectory) {
    return staleCandidate(cachedValue, `Saved feature_path no longer exists: ${cachedValue}`);
  }

  let resolvedWorkspace: string;
  let resolvedFeature: string;
  let resolvedProject: string;
  try {
    resolvedWorkspace = realpathSync(workspaceRoot);
    resolvedFeature = realpathSync(candidate);
    resolvedProject = realpathSync(projectRoot);
  } catch (error) {
    return staleCandidate(cachedValue, `Unable to resolve cached feature_path: ${message(error)}`);
  }

  const insideWorkspace =
    resolvedFeature === resolvedWorkspace ||
    resolvedFeature.startsWith(resolvedWorkspace + path.sep);
  const underProject = resolvedFeature.startsWith(resolvedProject + path.sep);
  if (!insideWorkspace || !underProject) {
    return staleCandidate(
      cachedValue,
      `Saved feature_path escapes the selected project or workspace: ${cachedValue}`
    );
  }

  return {
    state: "valid",
    featurePath: path.relative(resolvedWorkspace, resolvedFeature),
    raw: cachedValue,
    diagnostics: [],
    notices: []
  };

  function staleCandidate(rawValue: string, reason: string): FeatureStateReadResult {
    return {
      state: "stale",
      raw: rawValue,
      diagnostics: [{ severity: "warning", source: filePath, reason }],
      notices: [`Ignoring stale saved feature_path cache: ${rawValue}`]
    };
  }
}

/**
 * Persist the selected/scaffolded feature as one workspace-relative `featurePath`
 * in `<project>/.overmind_feature_state.json`. Written atomically via a temp file
 * rename so a crash mid-write never leaves a torn cache.
 */
export function writeFeatureState(
  projectRoot: string,
  featurePath: string
): FeatureStateWriteResult {
  const filePath = stateFilePath(projectRoot);
  const payload = `${JSON.stringify({ featurePath }, null, 2)}\n`;
  const tempPath = `${filePath}.tmp-${process.pid}`;
  try {
    mkdirSync(path.dirname(filePath), { recursive: true });
    writeFileSync(tempPath, payload);
    renameSync(tempPath, filePath);
    return { ok: true, diagnostics: [] };
  } catch (error) {
    return {
      ok: false,
      diagnostics: [
        {
          severity: "warning",
          source: filePath,
          reason: `Unable to persist feature-state cache: ${message(error)}`
        }
      ]
    };
  }
}

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
