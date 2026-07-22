import { existsSync, statSync } from "node:fs";
import path from "node:path";

import { displayPath } from "../parse/index.js";
import { readProjectDefinitionMetadata } from "../parse/project-definition.js";
import { computeCrossClassPeerTrigger } from "../repo/index.js";
import type { ContextResult } from "../types/index.js";
import type { SurfaceMapClass } from "../validate/surface-map.js";
import { detectRuntimeRoot, resolveProjectPath } from "../workspace/index.js";

const TEMPLATE_BY_CLASS: Record<SurfaceMapClass, string> = {
  backend: "assets/project_stack_blueprint_be_TEMPLATE.md",
  frontend: "assets/project_stack_blueprint_fe_TEMPLATE.md",
  mobile: "assets/project_stack_blueprint_mobile_TEMPLATE.md"
};

const GOLDEN_BY_CLASS: Record<SurfaceMapClass, string> = {
  backend: "assets/project_stack_blueprint_be_GOLDEN_EXAMPLE.md",
  frontend: "assets/project_stack_blueprint_fe_GOLDEN_EXAMPLE.md",
  mobile: "assets/project_stack_blueprint_mobile_GOLDEN_EXAMPLE.md"
};

export function buildStackBlueprintContext(
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
    return contextError("Stack blueprint generation applies only to project type A.");
  }
  if (!metadata.projectClasses.includes(klass)) {
    return contextError(`Class '${klass}' is not active in project_classes.`);
  }

  const target = `${projectDisplay}/project_stack_blueprint_${klass}.md`;
  const externalSources = path.join(workspaceRoot, ".setup", "external_sources.yaml");
  const externalSourcesStatus =
    existsSync(externalSources) && statSync(externalSources).isFile()
      ? displayPath(externalSources, workspaceRoot)
      : "unavailable";
  const peerTrigger = computeCrossClassPeerTrigger(definitionPath);
  const lines = [
    "# stack-blueprint context",
    "",
    "## Runtime Paths",
    `- workspace_root: ${workspaceRoot}`,
    `- project_root: ${projectDisplay}`,
    `- progress_definition: ${displayPath(definitionPath, workspaceRoot)}`,
    `- target_class: ${klass}`,
    `- target_blueprint: ${target}`,
    `- gate_command: node .overmind/overmind.js gate stack-blueprint ${target}`,
    "",
    "## Skill Assets",
    `- stack_blueprint_template_asset: ${TEMPLATE_BY_CLASS[klass]}`,
    `- stack_blueprint_golden_example_asset: ${GOLDEN_BY_CLASS[klass]}`,
    "",
    "## Deterministic Inputs",
    `- cross_class_peer_trigger: ${peerTrigger}`,
    `- external_sources_status: ${externalSourcesStatus}`,
    "",
    "## Read-Only Inputs",
    `- read_only_input: ${displayPath(definitionPath, workspaceRoot)}`,
    ...(externalSourcesStatus !== "unavailable"
      ? [`- read_only_input: ${externalSourcesStatus}`]
      : []),
    "",
    "## Allowed Write Surface",
    `- ${target}`
  ];

  return { exitCode: 0, text: `${lines.join("\n")}\n` };
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
