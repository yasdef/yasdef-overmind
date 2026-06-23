import { existsSync, statSync } from "node:fs";
import path from "node:path";

import { displayPath, parseImplementationSlicesProjectClasses, resolveFeatureWithinWorkspace } from "../parse/index.js";
import type { ContextResult } from "../types/index.js";

const SURFACE_CLASSES = new Set(["backend", "frontend", "mobile"]);
const VALID_PROJECT_CLASSES = new Set([...SURFACE_CLASSES, "infrastructure"]);

export function buildImplementationSlicesContext(inputPath: string, cwd = process.cwd()): ContextResult {
  const resolved = resolveFeatureWithinWorkspace(inputPath, cwd);
  if (!resolved.ok) return contextError(resolved.message);

  const { workspaceRoot, featureDir, relativeFeature } = resolved.value;
  const parts = relativeFeature.split(path.sep);
  if (parts.length !== 3 || parts[0] !== "projects" || parts[1] === "" || parts[2] === "") {
    return contextError(`Feature path must resolve under projects/<project-id>/<feature-folder>: ${relativeFeature}`);
  }

  const projectDir = path.join(workspaceRoot, "projects", parts[1]);
  const definitionPath = path.join(projectDir, "init_progress_definition.yaml");
  const requirementsPath = path.join(featureDir, "requirements_ears.md");
  const technicalRequirementsPath = path.join(featureDir, "technical_requirements.md");
  const contractDeltaPath = path.join(featureDir, "feature_contract_delta.md");
  const prerequisiteGapsPath = path.join(featureDir, "prerequisite_gaps.md");

  for (const requiredPath of [definitionPath, requirementsPath, technicalRequirementsPath, contractDeltaPath]) {
    if (!isFile(requiredPath)) return contextError(`Required file not found: ${displayPath(requiredPath, workspaceRoot)}`);
  }

  try {
    const projectClasses = parseImplementationSlicesProjectClasses(definitionPath);
    const unsupportedClass = projectClasses.find((item) => !VALID_PROJECT_CLASSES.has(item));
    if (unsupportedClass) {
      return contextError(
        `Unsupported project class '${unsupportedClass}' in ${displayPath(definitionPath, workspaceRoot)}; expected backend, frontend, mobile, or infrastructure`
      );
    }
    const classes = projectClasses.filter((item) => SURFACE_CLASSES.has(item));
    if (classes.length === 0) {
      return contextError(`No supported repo classes found in ${displayPath(definitionPath, workspaceRoot)}`);
    }
    const surfaceMaps = classes.map((klass) => ({
      klass,
      file: path.join(featureDir, `project_surface_struct_resp_map_${klass}.md`)
    }));
    for (const surface of surfaceMaps) {
      if (!isFile(surface.file)) return contextError(`Required file not found: ${displayPath(surface.file, workspaceRoot)}`);
    }

    const featurePath = displayPath(featureDir, workspaceRoot);
    const readOnly = [definitionPath, requirementsPath, technicalRequirementsPath, contractDeltaPath, ...surfaceMaps.map((surface) => surface.file)];
    if (isFile(prerequisiteGapsPath)) readOnly.push(prerequisiteGapsPath);
    const lines = [
      "# implementation-slices context",
      "",
      "## Runtime Paths",
      `- workspace_root: ${workspaceRoot}`,
      `- project_root: ${displayPath(projectDir, workspaceRoot)}`,
      `- feature_root: ${featurePath}`,
      `- progress_definition: ${displayPath(definitionPath, workspaceRoot)}`,
      `- requirements_ears_source: ${displayPath(requirementsPath, workspaceRoot)}`,
      `- technical_requirements_source: ${displayPath(technicalRequirementsPath, workspaceRoot)}`,
      `- feature_contract_delta_source: ${displayPath(contractDeltaPath, workspaceRoot)}`,
      `- target_artifact: ${featurePath}/implementation_slices.md`,
      `- gate_command: node .overmind/overmind.js gate implementation-slices ${featurePath}`,
      "",
      "## Skill Assets",
      "- implementation_slices_template_asset: assets/implementation_slices_TEMPLATE.md",
      "- implementation_slices_golden_example_asset: assets/implementation_slices_GOLDEN_EXAMPLE.md",
      "",
      "## Read-Only Inputs",
      ...readOnly.map((file) => `- read_only_input: ${displayPath(file, workspaceRoot)}`),
      "",
      "## Active Repo Classes",
      ...surfaceMaps.map((surface) => `- ${surface.klass}: ${displayPath(surface.file, workspaceRoot)}`),
      "",
      "## Allowed Write Surface",
      `- ${featurePath}/implementation_slices.md`
    ];
    return { exitCode: 0, text: `${lines.join("\n")}\n` };
  } catch (err) {
    return contextError(err instanceof Error ? err.message : String(err));
  }
}

function isFile(file: string): boolean {
  return existsSync(file) && statSync(file).isFile();
}

function contextError(message: string): ContextResult {
  return { exitCode: 2, errorMessage: message };
}
