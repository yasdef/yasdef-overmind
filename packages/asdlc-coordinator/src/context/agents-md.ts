import { existsSync, statSync } from "node:fs";
import path from "node:path";

import { displayPath } from "../parse/index.js";
import { readProjectDefinitionMetadata } from "../parse/project-definition.js";
import type { ContextResult } from "../types/index.js";
import type { SurfaceMapClass } from "../validate/surface-map.js";
import { detectRuntimeRoot, resolveProjectPath } from "../workspace/index.js";
import { buildReadOnlyInputManifest } from "./read-only-inputs.js";

const TEMPLATE_BY_CLASS: Record<SurfaceMapClass, string> = {
  backend: "assets/project_agents_md_claude_md_be_TEMPLATE.md",
  frontend: "assets/project_agents_md_claude_md_fe_TEMPLATE.md",
  mobile: "assets/project_agents_md_claude_md_mobile_TEMPLATE.md"
};

const GOLDEN_BY_CLASS: Record<SurfaceMapClass, string> = {
  backend: "assets/project_agents_md_claude_md_be_GOLDEN_EXAMPLE.md",
  frontend: "assets/project_agents_md_claude_md_fe_GOLDEN_EXAMPLE.md",
  mobile: "assets/project_agents_md_claude_md_mobile_GOLDEN_EXAMPLE.md"
};

export function buildAgentsMdContext(
  projectInput: string,
  klass: SurfaceMapClass,
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
  if (metadata.projectTypeCode !== "A") {
    return contextError(
      "Agent guidelines artifacts are derived from stack blueprints for project type A."
    );
  }
  if (!metadata.projectClasses.includes(klass)) {
    return contextError(`Class '${klass}' is not active in project_classes.`);
  }

  const sourceBlueprintPath = path.join(projectRoot, `project_stack_blueprint_${klass}.md`);
  if (!existsSync(sourceBlueprintPath) || !statSync(sourceBlueprintPath).isFile()) {
    return contextError(
      `Agent guidelines artifact is derived from the stack blueprint and cannot be produced before ${displayPath(
        sourceBlueprintPath,
        workspaceRoot
      )} exists.`
    );
  }

  const target = `${projectDisplay}/project_agents_md_claude_md_${klass}.md`;
  const targetPath = path.join(projectRoot, `project_agents_md_claude_md_${klass}.md`);
  const externalSources = path.join(workspaceRoot, ".setup", "external_sources.yaml");
  const externalSourcesStatus =
    existsSync(externalSources) && statSync(externalSources).isFile()
      ? displayPath(externalSources, workspaceRoot)
      : "unavailable";
  const agentsMdStatus =
    existsSync(targetPath) && statSync(targetPath).isFile() ? "present" : "absent";
  const readOnlySourcePaths = [
    definitionPath,
    sourceBlueprintPath,
    ...(externalSourcesStatus !== "unavailable" ? [externalSources] : [])
  ];
  const readOnlyInputs = buildReadOnlyInputManifest(readOnlySourcePaths, workspaceRoot);
  const lines = [
    "# agents-md context",
    "",
    "## Runtime Paths",
    `- workspace_root: ${workspaceRoot}`,
    `- project_root: ${projectDisplay}`,
    `- progress_definition: ${displayPath(definitionPath, workspaceRoot)}`,
    `- target_class: ${klass}`,
    `- target_agents_md: ${target}`,
    `- gate_command: node .overmind/overmind.js gate agents-md ${target}`,
    "",
    "## Skill Assets",
    `- agents_md_template_asset: ${TEMPLATE_BY_CLASS[klass]}`,
    `- agents_md_golden_example_asset: ${GOLDEN_BY_CLASS[klass]}`,
    "",
    "## Deterministic Inputs",
    `- external_sources_status: ${externalSourcesStatus}`,
    `- agents_md_status: ${agentsMdStatus}`,
    "",
    "## Read-Only Inputs",
    ...readOnlyInputs.lines,
    "",
    "## Blueprint Source",
    `- source_blueprint: ${displayPath(sourceBlueprintPath, workspaceRoot)}`,
    "",
    "## Allowed Write Surface",
    `- ${target}`
  ];

  return { exitCode: 0, text: `${lines.join("\n")}\n`, readOnlyInputs: readOnlyInputs.paths };
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
