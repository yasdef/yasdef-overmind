import { existsSync, realpathSync, statSync } from "node:fs";
import path from "node:path";

import { flipReadyToEarsFalseToTrue, resolveInputPath } from "../parse/index.js";
import { collectReadyRepoPaths } from "../repo/index.js";
import { validateBrClarification, validateRepoBrScan } from "../validate/index.js";

import type { GateResult, ReadinessResult } from "../types/index.js";

export function runBrClarificationReadiness(
  inputPath: string,
  cwd = process.cwd()
): ReadinessResult {
  if (!inputPath || inputPath.trim() === "") {
    return readinessError("Missing feature path.");
  }

  const featureDir = resolveInputPath(inputPath, cwd);
  if (!existsSync(featureDir) || !statSync(featureDir).isDirectory()) {
    return readinessError(`Feature path directory not found: ${inputPath}`);
  }

  if (!isPathInsideWorkspace(featureDir, cwd)) {
    return readinessError(`Feature path must resolve inside ASDLC workspace: ${inputPath}`);
  }

  const targetBrPath = path.join(featureDir, "feature_br_summary.md");
  if (!existsSync(targetBrPath)) {
    return readinessError(`Required file not found: ${targetBrPath}`);
  }

  const definitionPath = path.join(path.dirname(featureDir), "init_progress_definition.yaml");
  if (!existsSync(definitionPath)) {
    return readinessError(`Required file not found: ${definitionPath}`);
  }

  const brResult = validateBrClarification(featureDir, cwd);
  if (brResult.exitCode !== 0) {
    return gateToReadiness(brResult);
  }

  let readyRepos: Array<{ class: string; path: string }>;
  try {
    readyRepos = collectReadyRepoPaths(definitionPath);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return readinessError(msg);
  }

  const messages: string[] = [];
  if (readyRepos.length === 0) {
    messages.push(
      "Skipping repository business-context readiness gate: no class_repo_paths entries have state ready."
    );
  } else {
    const repoResult = validateRepoBrScan(featureDir, cwd);
    if (repoResult.exitCode !== 0) {
      return gateToReadiness(repoResult);
    }
  }

  try {
    flipReadyToEarsFalseToTrue(targetBrPath);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return readinessError(msg);
  }

  messages.push("EARS readiness check passed.");
  return {
    exitCode: 0,
    message: messages.join("\n")
  };
}

function isPathInsideWorkspace(featureDir: string, cwd: string): boolean {
  const workspaceRoot = realpathSync(cwd);
  const resolvedFeatureDir = realpathSync(featureDir);
  const relative = path.relative(workspaceRoot, resolvedFeatureDir);
  return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
}

function gateToReadiness(result: GateResult): ReadinessResult {
  if (result.exitCode === 1) {
    return {
      exitCode: 1,
      problems: result.problems
    };
  }
  return readinessError(result.errorMessage ?? "Validation cannot run.");
}

function readinessError(message: string): ReadinessResult {
  return {
    exitCode: 2,
    errorMessage: message
  };
}
