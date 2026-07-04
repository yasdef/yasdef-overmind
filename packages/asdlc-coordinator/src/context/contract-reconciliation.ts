import { existsSync, realpathSync, statSync } from "node:fs";
import path from "node:path";

import { displayPath } from "../parse/index.js";
import { readProjectDefinitionMetadata } from "../parse/project-definition.js";
import type { ContextResult } from "../types/index.js";
import { detectRuntimeRoot, resolveProjectPath } from "../workspace/index.js";

const TEMPLATE_ASSET = "assets/common_contract_definition_TEMPLATE.md";
const GOLDEN_ASSET = "assets/common_contract_definition_GOLDEN_EXAMPLE.md";

export interface ReconciliationClassMapping {
  class: string;
  repoPath: string;
}

/**
 * Deterministic in-process context for the project reconciliation session (D5).
 * Resolves the project and requested classes without shell output parsing, validates
 * each class is ready with a present git repo, deduplicates shared repositories for
 * inspection while retaining every class-to-repo mapping, and emits the exact gate
 * command the model must rebuild authoritative context with.
 */
export function buildContractReconciliationContext(
  projectInput: string,
  classes: string[],
  cwd = process.cwd()
): ContextResult {
  if (!projectInput || projectInput.trim() === "") {
    return contextError("Missing target project path argument.");
  }
  if (classes.length === 0) {
    return contextError("At least one --class is required for contract reconciliation.");
  }

  const requested = classes.map((value) => value.trim().toLowerCase());
  const seenRequest = new Set<string>();
  for (const klass of requested) {
    if (klass === "") return contextError("Class names must be non-empty.");
    if (seenRequest.has(klass)) return contextError(`Duplicate class requested: ${klass}`);
    seenRequest.add(klass);
  }

  const startPath = path.resolve(cwd, projectInput);
  const workspace = detectRuntimeRoot(startPath);
  if (!workspace.path) {
    return contextError(workspace.diagnostics.map((d) => d.reason).join("; "));
  }
  const workspaceRoot = workspace.path;
  const project = resolveProjectPath(startPath, path.join(workspaceRoot, "projects"));
  if (!project.path) {
    return contextError(project.diagnostics.map((d) => d.reason).join("; "));
  }
  const projectRoot = project.path;

  const definitionPath = path.join(projectRoot, "init_progress_definition.yaml");
  const metadata = readProjectDefinitionMetadata(definitionPath);
  if (!metadata.parsed) {
    return contextError(metadata.diagnostics.map((d) => d.reason).join("; "));
  }

  const inScope: ReconciliationClassMapping[] = [];
  const uniqueRepoPaths: string[] = [];
  const seenRepo = new Set<string>();
  for (const klass of requested) {
    const entry = metadata.classRepoPaths[klass];
    if (!entry) {
      return contextError(
        `Class '${klass}' is not present in meta_info.class_repo_paths of ${displayPath(definitionPath, workspaceRoot)}`
      );
    }
    if (entry.state !== "ready") {
      return contextError(`Class '${klass}' is not ready (state: ${entry.state ?? "unset"}).`);
    }
    const repoPath = (entry.path ?? "").trim();
    if (repoPath === "") {
      return contextError(`Class '${klass}' is ready but has an empty repo path.`);
    }
    if (!existsSync(repoPath) || !statSync(repoPath).isDirectory()) {
      return contextError(`Class '${klass}' repo path is not an existing directory: ${repoPath}`);
    }
    const resolved = realpathSync(repoPath);
    if (!existsSync(path.join(resolved, ".git"))) {
      return contextError(`Class '${klass}' repo path is not a git worktree: ${resolved}`);
    }
    inScope.push({ class: klass, repoPath: resolved });
    if (!seenRepo.has(resolved)) {
      seenRepo.add(resolved);
      uniqueRepoPaths.push(resolved);
    }
  }

  const outOfScope = Object.entries(metadata.classRepoPaths)
    .filter(([className]) => !seenRequest.has(className))
    .map(([className, entry]) => ({ class: className, state: entry.state ?? "unset" }));

  const projectDisplay = displayPath(projectRoot, workspaceRoot);
  const targetContract = `${projectDisplay}/common_contract_definition.md`;
  const gateCommand = `node .overmind/overmind.js gate contract-reconciliation ${projectDisplay}`;

  const lines = [
    "# contract-reconciliation context",
    "",
    "## Runtime Paths",
    `- workspace_root: ${workspaceRoot}`,
    `- project_root: ${projectDisplay}`,
    `- progress_definition: ${displayPath(definitionPath, workspaceRoot)}`,
    `- target_common_contract: ${targetContract}`,
    `- gate_command: ${gateCommand}`,
    "",
    "## Skill Assets",
    `- common_contract_template_asset: ${TEMPLATE_ASSET}`,
    `- common_contract_golden_example_asset: ${GOLDEN_ASSET}`,
    "",
    "## In-Scope Classes",
    ...inScope.map((mapping) => `- ${mapping.class}: ${mapping.repoPath}`),
    "",
    "## Unique Repository Inspection Paths",
    ...uniqueRepoPaths.map((repoPath) => `- ${repoPath}`),
    "",
    "## Out-Of-Scope Classes",
    ...(outOfScope.length > 0
      ? outOfScope.map((entry) => `- ${entry.class}: ${entry.state}`)
      : ["- none"]),
    "",
    "## Read-Only Inputs",
    `- ${displayPath(definitionPath, workspaceRoot)}`,
    ...uniqueRepoPaths.map((repoPath) => `- ${repoPath}`),
    "",
    "## Allowed Write Surface",
    `- ${targetContract}`
  ];

  const readOnlyInputs = [definitionPath, ...uniqueRepoPaths];
  return { exitCode: 0, text: `${lines.join("\n")}\n`, readOnlyInputs };
}

function contextError(message: string): ContextResult {
  return { exitCode: 2, errorMessage: message };
}
