import { existsSync, realpathSync, statSync } from "node:fs";
import path from "node:path";

import { resolveInputPath } from "./markdown.js";

export interface WorkspaceFeature {
  /** realpath of the workspace root (cwd), with symlinks resolved. */
  workspaceRoot: string;
  /** realpath of the feature directory, guaranteed inside workspaceRoot. */
  featureDir: string;
  /** featureDir relative to workspaceRoot (e.g. "projects/p1/feature-a"). */
  relativeFeature: string;
}

export type ResolveFeatureResult =
  { ok: true; value: WorkspaceFeature } | { ok: false; message: string };

/**
 * Resolve a feature path to its canonical location and enforce that it stays
 * inside the ASDLC workspace. Mirrors the deleted bash `resolve_feature_path`,
 * which `pwd -P`'d (realpath) the candidate and asserted the resolved path was
 * still under the runtime root. Without this, a symlinked feature directory
 * passes a purely lexical `projects/<id>/<feature>` check while reads/writes
 * follow the link to another feature or outside the workspace.
 */
export function resolveFeatureWithinWorkspace(
  inputPath: string,
  cwd: string
): ResolveFeatureResult {
  if (!inputPath || inputPath.trim() === "") {
    return { ok: false, message: "Missing feature path." };
  }
  const candidate = resolveInputPath(inputPath, cwd);
  if (!existsSync(candidate) || !statSync(candidate).isDirectory()) {
    return { ok: false, message: `Feature path directory not found: ${inputPath}` };
  }

  let workspaceRoot: string;
  try {
    workspaceRoot = realpathSync(cwd);
  } catch {
    return { ok: false, message: "Workspace root could not be resolved." };
  }
  let featureDir: string;
  try {
    featureDir = realpathSync(candidate);
  } catch {
    return { ok: false, message: `Feature path directory not found: ${inputPath}` };
  }

  if (featureDir !== workspaceRoot && !featureDir.startsWith(workspaceRoot + path.sep)) {
    return {
      ok: false,
      message: `Feature path must resolve inside ASDLC workspace: ${featureDir}`
    };
  }

  return {
    ok: true,
    value: { workspaceRoot, featureDir, relativeFeature: path.relative(workspaceRoot, featureDir) }
  };
}
