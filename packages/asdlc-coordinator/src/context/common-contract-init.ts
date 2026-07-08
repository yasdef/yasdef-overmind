import { existsSync, statSync } from "node:fs";
import path from "node:path";

import { displayPath } from "../parse/index.js";
import { readProjectDefinitionMetadata } from "../parse/project-definition.js";
import { collectReadyRepoPaths, computeCrossClassPeerTrigger } from "../repo/index.js";
import type { ContextResult } from "../types/index.js";
import { detectRuntimeRoot, resolveProjectPath } from "../workspace/index.js";
import { buildReadOnlyInputManifest } from "./read-only-inputs.js";

const STACK_CLASSES = ["backend", "frontend", "mobile"] as const;

export function buildCommonContractInitContext(
  projectInput: string,
  classes: string[],
  cwd = process.cwd()
): ContextResult {
  if (!projectInput || projectInput.trim() === "") {
    return contextError("Missing target project path argument.");
  }

  const resolved = resolveProject(projectInput, cwd);
  if (!resolved.ok) return contextError(resolved.message);
  const { workspaceRoot, projectRoot, projectDisplay } = resolved;
  const definitionPath = path.join(projectRoot, "init_progress_definition.yaml");
  const metadata = readProjectDefinitionMetadata(definitionPath);
  if (!metadata.parsed) {
    return contextError(metadata.diagnostics.map((diagnostic) => diagnostic.reason).join("; "));
  }

  const targetContract = `${projectDisplay}/common_contract_definition.md`;
  const peerTrigger = computeCrossClassPeerTrigger(definitionPath);
  const activeStackClasses = activeClasses(metadata.projectClasses, classes);
  const projectId =
    metadata.projectId && metadata.projectId !== ""
      ? metadata.projectId
      : path.basename(projectRoot);
  const readOnlyPaths: string[] = [];
  const evidenceLines: string[] = [];
  const blueprintLines: string[] = [];
  const sourceRepositoryLabels: string[] = [];

  if (metadata.projectTypeCode === "A") {
    for (const klass of activeStackClasses) {
      const blueprint = path.join(projectRoot, `project_stack_blueprint_${klass}.md`);
      if (!existsSync(blueprint) || !statSync(blueprint).isFile()) {
        return contextError(
          `Required type A stack blueprint is missing before step 2: ${displayPath(blueprint, workspaceRoot)}`
        );
      }
      readOnlyPaths.push(blueprint);
      blueprintLines.push(`- ${klass}: ${displayPath(blueprint, workspaceRoot)}`);
      sourceRepositoryLabels.push(`${klass} blueprint`);
    }
    if (blueprintLines.length === 0) {
      blueprintLines.push("- none");
    }
    evidenceLines.push("- ready repository evidence: not used for project type A");
  } else {
    let readyRepos: ReturnType<typeof collectReadyRepoPaths>;
    try {
      readyRepos = collectReadyRepoPaths(definitionPath);
    } catch (error) {
      return contextError(error instanceof Error ? error.message : String(error));
    }
    if (readyRepos.length === 0) {
      return contextError(
        "No usable repository paths found in meta_info.class_repo_paths (state: ready with existing directories required)."
      );
    }
    for (const repo of readyRepos) {
      evidenceLines.push(`- ${repo.class}: ${repo.path}`);
      sourceRepositoryLabels.push(repo.class);
    }
    blueprintLines.push("- type A stack blueprint context: not applicable");
  }

  const readOnlyInputs = buildReadOnlyInputManifest(readOnlyPaths, workspaceRoot);
  const lines = [
    "# common-contract init context",
    "",
    "## Runtime Paths",
    `- workspace_root: ${workspaceRoot}`,
    `- project_root: ${projectDisplay}`,
    `- progress_definition: ${displayPath(definitionPath, workspaceRoot)}`,
    `- target_common_contract: ${targetContract}`,
    `- gate_command: node .overmind/overmind.js gate common-contract ${projectDisplay}`,
    "",
    "## Skill Assets",
    "- common_contract_template_asset: assets/common_contract_definition_TEMPLATE.md",
    "- common_contract_golden_example_asset: assets/common_contract_definition_GOLDEN_EXAMPLE.md",
    "",
    "## Read-Only Inputs",
    ...readOnlyInputs.lines,
    "",
    "## Type-A Blueprint Context",
    ...blueprintLines,
    "",
    "## Type-B/C Ready Repository Evidence",
    ...evidenceLines,
    "",
    "## Deterministic Values",
    `- project_id: ${projectId}`,
    `- project_type_code: ${metadata.projectTypeCode ?? ""}`,
    `- source_repo_count: ${sourceRepositoryLabels.length}`,
    `- source_repositories: ${sourceRepositoryLabels.join(", ") || "none"}`,
    `- cross_class_peer_trigger: ${peerTrigger}`,
    "",
    "## Allowed Write Surface",
    `- ${targetContract}`
  ];

  return { exitCode: 0, text: `${lines.join("\n")}\n`, readOnlyInputs: readOnlyInputs.paths };
}

function activeClasses(projectClasses: string[], bindingsClasses: string[]): string[] {
  const bound = new Set(bindingsClasses.map((klass) => klass.toLowerCase()));
  const source =
    bound.size > 0 ? projectClasses.filter((klass) => bound.has(klass)) : projectClasses;
  return source.filter((klass) => (STACK_CLASSES as readonly string[]).includes(klass));
}

function resolveProject(
  projectInput: string,
  cwd: string
):
  | { ok: true; workspaceRoot: string; projectRoot: string; projectDisplay: string }
  | { ok: false; message: string } {
  const startPath = path.resolve(cwd, projectInput);
  const workspace = detectRuntimeRoot(startPath);
  if (!workspace.path) {
    return { ok: false, message: workspace.diagnostics.map((d) => d.reason).join("; ") };
  }
  const project = resolveProjectPath(startPath, path.join(workspace.path, "projects"));
  if (!project.path) {
    return { ok: false, message: project.diagnostics.map((d) => d.reason).join("; ") };
  }
  return {
    ok: true,
    workspaceRoot: workspace.path,
    projectRoot: project.path,
    projectDisplay: displayPath(project.path, workspace.path)
  };
}

function contextError(message: string): ContextResult {
  return { exitCode: 2, errorMessage: message };
}
