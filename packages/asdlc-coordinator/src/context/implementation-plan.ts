import { existsSync, statSync } from "node:fs";
import path from "node:path";

import {
  displayPath,
  parseImplementationSlicesProjectClasses,
  resolveFeatureWithinWorkspace
} from "../parse/index.js";
import type { ContextResult } from "../types/index.js";
import { buildReadOnlyInputManifest } from "./read-only-inputs.js";

const SUPPORTED_CLASSES = new Set(["backend", "frontend", "mobile"]);
const VALID_CLASSES = new Set([...SUPPORTED_CLASSES, "infrastructure"]);

export function buildImplementationPlanContext(
  inputPath: string,
  cwd = process.cwd()
): ContextResult {
  const resolved = resolveFeatureWithinWorkspace(inputPath, cwd);
  if (!resolved.ok) return contextError(resolved.message);
  const { workspaceRoot, featureDir, relativeFeature } = resolved.value;
  const parts = relativeFeature.split(path.sep);
  if (parts.length !== 3 || parts[0] !== "projects" || !parts[1] || !parts[2])
    return contextError(
      `Feature path must resolve under projects/<project-id>/<feature-folder>: ${relativeFeature}`
    );
  const projectDir = path.join(workspaceRoot, "projects", parts[1]);
  const definitionPath = path.join(projectDir, "init_progress_definition.yaml");
  const files = [
    "requirements_ears.md",
    "technical_requirements.md",
    "feature_contract_delta.md",
    "implementation_slices.md",
    "prerequisite_gaps.md"
  ].map((name) => path.join(featureDir, name));
  for (const required of [definitionPath, ...files])
    if (!isFile(required))
      return contextError(`Required file not found: ${displayPath(required, workspaceRoot)}`);
  try {
    const projectClasses = parseImplementationSlicesProjectClasses(definitionPath);
    const unsupported = projectClasses.find((item) => !VALID_CLASSES.has(item));
    if (unsupported)
      return contextError(
        `Unsupported project class '${unsupported}' in ${displayPath(definitionPath, workspaceRoot)}; expected backend, frontend, mobile, or infrastructure`
      );
    const activeClasses = projectClasses.filter((item) => SUPPORTED_CLASSES.has(item));
    if (activeClasses.length === 0)
      return contextError(
        `No supported repo classes found in ${displayPath(definitionPath, workspaceRoot)}`
      );
    const featurePath = displayPath(featureDir, workspaceRoot);
    const readOnlyInputs = buildReadOnlyInputManifest([definitionPath, ...files], workspaceRoot);
    const lines = [
      "# implementation-plan context",
      "",
      "## Runtime Paths",
      `- workspace_root: ${workspaceRoot}`,
      `- project_root: ${displayPath(projectDir, workspaceRoot)}`,
      `- feature_root: ${featurePath}`,
      `- progress_definition: ${displayPath(definitionPath, workspaceRoot)}`,
      `- requirements_ears_source: ${displayPath(files[0]!, workspaceRoot)}`,
      `- technical_requirements_source: ${displayPath(files[1]!, workspaceRoot)}`,
      `- feature_contract_delta_source: ${displayPath(files[2]!, workspaceRoot)}`,
      `- implementation_slices_source: ${displayPath(files[3]!, workspaceRoot)}`,
      `- prerequisite_gaps_source: ${displayPath(files[4]!, workspaceRoot)}`,
      `- target_artifact: ${featurePath}/implementation_plan.md`,
      `- gate_command: node .overmind/overmind.js gate implementation-plan ${featurePath}`,
      "",
      "## Skill Assets",
      "- implementation_plan_template_asset: assets/implementation_plan_TEMPLATE.md",
      "- implementation_plan_golden_example_asset: assets/implementation_plan_GOLDEN_EXAMPLE.md",
      "",
      "## Read-Only Inputs",
      ...readOnlyInputs.lines,
      "",
      "## Active Repo Classes",
      ...activeClasses.map((item) => `- ${item}`),
      "",
      "## Allowed Write Surface",
      `- ${featurePath}/implementation_plan.md`
    ];
    return { exitCode: 0, text: `${lines.join("\n")}\n`, readOnlyInputs: readOnlyInputs.paths };
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
