import { existsSync, readFileSync, realpathSync, statSync, writeFileSync } from "node:fs";
import path from "node:path";

import {
  applyClassAttachment,
  readProjectDefinitionMetadata
} from "../parse/project-definition.js";
import type { Diagnostic } from "../types/index.js";

export interface AttachResult {
  ok: boolean;
  resolvedRepoPath?: string;
  diagnostics: Diagnostic[];
}

const DEFINITION_FILE = "init_progress_definition.yaml";

function fail(reason: string): AttachResult {
  return { ok: false, diagnostics: [{ severity: "error", source: "repo-attach", reason }] };
}

/**
 * Deterministic TypeScript class-repo attach primitive (D3), replacing
 * `persist_class_repo_attach.sh` without shell or awk. Validates the project, class,
 * and repo inputs; writes `state: "ready"`, canonical `path`, and `policy: "C"`;
 * clears the class's `contract_reconciled` completion state; preserves unrelated
 * definition content; and validates the resulting class record for coherence.
 */
export function attachClassRepo(
  projectRoot: string,
  className: string,
  repoPathInput: string
): AttachResult {
  const definitionPath = path.join(projectRoot, DEFINITION_FILE);
  if (!existsSync(definitionPath) || !statSync(definitionPath).isFile()) {
    return fail(`Project path must contain ${DEFINITION_FILE}: ${projectRoot}`);
  }

  if (repoPathInput.trim() === "") {
    return fail("Repo path cannot be empty.");
  }
  if (!existsSync(repoPathInput) || !statSync(repoPathInput).isDirectory()) {
    return fail(`Repo path is not a directory: ${repoPathInput}`);
  }
  let resolvedRepoPath: string;
  try {
    resolvedRepoPath = realpathSync(repoPathInput);
  } catch {
    return fail(`Failed to resolve repo path: ${repoPathInput}`);
  }
  if (!existsSync(path.join(resolvedRepoPath, ".git"))) {
    return fail(`Repo path must be a git worktree (contain .git): ${resolvedRepoPath}`);
  }

  let content: string;
  try {
    content = readFileSync(definitionPath, "utf8");
  } catch (error) {
    return fail(
      `Unable to read ${DEFINITION_FILE}: ${error instanceof Error ? error.message : String(error)}`
    );
  }

  const mutation = applyClassAttachment(content, className, resolvedRepoPath);
  if ("error" in mutation) {
    return fail(`${mutation.error} (${definitionPath})`);
  }

  try {
    writeFileSync(definitionPath, mutation.content);
  } catch (error) {
    return fail(
      `Failed to write updated definition: ${error instanceof Error ? error.message : String(error)}`
    );
  }

  const coherence = validateClassRecordCoherence(projectRoot, className);
  if (coherence) {
    return { ok: false, diagnostics: [coherence] };
  }

  return { ok: true, resolvedRepoPath, diagnostics: [] };
}

/**
 * Port of `class_repo_paths_validate_coherence` for a single class. Re-parses the
 * written definition and asserts the class record is internally consistent; returns a
 * diagnostic on failure so the project flow can restore its transaction-owned state.
 */
export function validateClassRecordCoherence(
  projectRoot: string,
  className: string
): Diagnostic | undefined {
  const definitionPath = path.join(projectRoot, DEFINITION_FILE);
  const metadata = readProjectDefinitionMetadata(definitionPath);
  if (!metadata.parsed) {
    return {
      severity: "error",
      source: "repo-attach",
      reason: `class_repo_paths coherence failed: ${metadata.diagnostics.map((d) => d.reason).join("; ")}`
    };
  }
  const entry = metadata.classRepoPaths[className.toLowerCase()];
  if (!entry) {
    return {
      severity: "error",
      source: "repo-attach",
      reason: `class_repo_paths coherence failed for class '${className}': class not found`
    };
  }
  const coherenceFail = (reason: string): Diagnostic => ({
    severity: "error",
    source: "repo-attach",
    reason: `class_repo_paths coherence failed for class '${className}': ${reason}`
  });
  const repoPath = (entry.path ?? "").trim();
  if (entry.state === "ready") {
    if (repoPath === "") return coherenceFail("state ready requires non-empty path");
    if (!existsSync(repoPath) || !statSync(repoPath).isDirectory()) {
      return coherenceFail(`path is not an existing directory: ${repoPath}`);
    }
    let resolved: string;
    try {
      resolved = realpathSync(repoPath);
    } catch {
      return coherenceFail(`failed to resolve path: ${repoPath}`);
    }
    if (!existsSync(path.join(resolved, ".git"))) {
      return coherenceFail(`path does not contain .git: ${resolved}`);
    }
  } else if (entry.state === "deferred") {
    if (repoPath !== "") return coherenceFail("state deferred requires empty or absent path");
  } else {
    return coherenceFail(`state must be ready or deferred, got '${entry.state ?? "unset"}'`);
  }
  if (entry.policy !== undefined && entry.policy !== "B" && entry.policy !== "C") {
    return coherenceFail(`policy must be B or C when present, got '${entry.policy}'`);
  }
  return undefined;
}
