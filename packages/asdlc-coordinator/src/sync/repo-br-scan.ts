import { existsSync } from "node:fs";
import path from "node:path";

import { collectReadyRepoPaths, syncRepoToDefaultBranch } from "../repo/index.js";
import { resolveFeatureWithinWorkspace } from "../parse/index.js";
import type { SyncStepResult } from "../types/index.js";

function findDefinitionFile(startDir: string, cwd: string): string | undefined {
  let searchDir = startDir;
  while (true) {
    const candidate = path.join(searchDir, "init_progress_definition.yaml");
    if (existsSync(candidate)) {
      return candidate;
    }
    if (searchDir === cwd) {
      break;
    }
    const parent = path.dirname(searchDir);
    if (parent === searchDir) {
      break;
    }
    if (!parent.startsWith(cwd)) {
      break;
    }
    searchDir = parent;
  }
  return undefined;
}

export function syncRepoBrScanStep(inputPath: string, cwd = process.cwd()): SyncStepResult {
  const resolved = resolveFeatureWithinWorkspace(inputPath, cwd);
  if (!resolved.ok) {
    return { exitCode: 2, errorMessage: resolved.message };
  }
  const { workspaceRoot, featureDir } = resolved.value;

  const definitionPath = findDefinitionFile(featureDir, workspaceRoot);
  if (!definitionPath) {
    return {
      exitCode: 2,
      errorMessage: `Required file not found: <path ancestor>/init_progress_definition.yaml (path: ${inputPath})`
    };
  }

  let readyRepos: Array<{ class: string; path: string }>;
  try {
    readyRepos = collectReadyRepoPaths(definitionPath);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return { exitCode: 2, errorMessage: msg };
  }

  if (readyRepos.length === 0) {
    return { exitCode: 0, syncedCount: 0 };
  }

  const blocked: string[] = [];
  for (const repo of readyRepos) {
    const result = syncRepoToDefaultBranch(repo.path);
    if (!result.ok) {
      blocked.push(result.blockedMessage);
    }
  }

  if (blocked.length > 0) {
    return { exitCode: 2, blockedMessages: blocked };
  }

  return { exitCode: 0, syncedCount: readyRepos.length };
}
