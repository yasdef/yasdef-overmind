import { existsSync } from "node:fs";
import path from "node:path";

import { collectReadyRepoPaths, syncRepoToDefaultBranch } from "../repo/index.js";
import { resolveFeatureWithinWorkspace } from "../parse/index.js";
import type { SyncStepResult } from "../types/index.js";
import type { SurfaceMapClass } from "../validate/surface-map.js";

export function syncSurfaceMapStep(
  inputPath: string,
  klass: SurfaceMapClass,
  cwd = process.cwd()
): SyncStepResult {
  const resolved = resolveFeatureWithinWorkspace(inputPath, cwd);
  if (!resolved.ok) {
    return { exitCode: 2, errorMessage: resolved.message };
  }
  const { workspaceRoot, relativeFeature } = resolved.value;
  const parts = relativeFeature.split(path.sep);
  if (parts.length !== 3 || parts[0] !== "projects") {
    return {
      exitCode: 2,
      errorMessage: `Feature path must resolve under projects/<project-id>/<feature-folder>: ${relativeFeature}`
    };
  }
  const definitionPath = path.join(
    workspaceRoot,
    "projects",
    parts[1]!,
    "init_progress_definition.yaml"
  );
  if (!existsSync(definitionPath)) {
    return {
      exitCode: 2,
      errorMessage: `Required file not found: ${path.relative(workspaceRoot, definitionPath)}`
    };
  }

  try {
    const readyRepo = collectReadyRepoPaths(definitionPath).find((repo) => repo.class === klass);
    if (!readyRepo) {
      return { exitCode: 0, syncedCount: 0 };
    }
    const result = syncRepoToDefaultBranch(readyRepo.path);
    if (!result.ok) {
      return { exitCode: 2, blockedMessages: [result.blockedMessage] };
    }
    return { exitCode: 0, syncedCount: 1 };
  } catch (err) {
    return { exitCode: 2, errorMessage: err instanceof Error ? err.message : String(err) };
  }
}
