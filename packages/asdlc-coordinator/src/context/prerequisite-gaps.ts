import { existsSync, statSync } from "node:fs";
import path from "node:path";

import {
  displayPath,
  parseImplementationSlicesProjectClasses,
  resolveFeatureWithinWorkspace
} from "../parse/index.js";
import { listCommittedSiblingFeatures } from "../repo/index.js";
import type { ContextResult } from "../types/index.js";
import { buildReadOnlyInputManifest } from "./read-only-inputs.js";

const SUPPORTED_CLASSES = new Set(["backend", "frontend", "mobile"]);
const VALID_CLASSES = new Set([...SUPPORTED_CLASSES, "infrastructure"]);

export function buildPrerequisiteGapsContext(
  inputPath: string,
  cwd = process.cwd()
): ContextResult {
  const resolved = resolveFeatureWithinWorkspace(inputPath, cwd);
  if (!resolved.ok) return contextError(resolved.message);
  const { workspaceRoot, featureDir, relativeFeature } = resolved.value;
  const parts = relativeFeature.split(path.sep);
  if (parts.length !== 3 || parts[0] !== "projects" || parts[1] === "" || parts[2] === "") {
    return contextError(
      `Feature path must resolve under projects/<project-id>/<feature-folder>: ${relativeFeature}`
    );
  }

  const projectDir = path.join(workspaceRoot, "projects", parts[1]!);
  const definitionPath = path.join(projectDir, "init_progress_definition.yaml");
  const requirementsPath = path.join(featureDir, "requirements_ears.md");
  const technicalPath = path.join(featureDir, "technical_requirements.md");
  const slicesPath = path.join(featureDir, "implementation_slices.md");
  for (const requiredPath of [definitionPath, requirementsPath, technicalPath, slicesPath]) {
    if (!isFile(requiredPath))
      return contextError(`Required file not found: ${displayPath(requiredPath, workspaceRoot)}`);
  }

  try {
    const projectClasses = parseImplementationSlicesProjectClasses(definitionPath);
    const unsupported = projectClasses.find((item) => !VALID_CLASSES.has(item));
    if (unsupported) {
      return contextError(
        `Unsupported project class '${unsupported}' in ${displayPath(definitionPath, workspaceRoot)}; expected backend, frontend, mobile, or infrastructure`
      );
    }
    const activeClasses = projectClasses.filter((item) => SUPPORTED_CLASSES.has(item));
    if (activeClasses.length === 0)
      return contextError(
        `No supported repo classes found in ${displayPath(definitionPath, workspaceRoot)}`
      );

    const siblingPlans = listCommittedSiblingFeatures(featureDir)
      .map((name) => path.join(projectDir, name, "implementation_plan.md"))
      .filter(isFile);
    const featurePath = displayPath(featureDir, workspaceRoot);
    const readOnly = [definitionPath, requirementsPath, technicalPath, slicesPath, ...siblingPlans];
    const readOnlyInputs = buildReadOnlyInputManifest(readOnly, workspaceRoot);
    const lines = [
      "# prerequisite-gaps context",
      "",
      "## Runtime Paths",
      `- workspace_root: ${workspaceRoot}`,
      `- project_root: ${displayPath(projectDir, workspaceRoot)}`,
      `- feature_root: ${featurePath}`,
      `- progress_definition: ${displayPath(definitionPath, workspaceRoot)}`,
      `- requirements_ears_source: ${displayPath(requirementsPath, workspaceRoot)}`,
      `- technical_requirements_source: ${displayPath(technicalPath, workspaceRoot)}`,
      `- implementation_slices_source: ${displayPath(slicesPath, workspaceRoot)}`,
      `- target_artifact: ${featurePath}/prerequisite_gaps.md`,
      `- gate_command: node .overmind/overmind.js gate prerequisite-gaps ${featurePath}`,
      "",
      "## Skill Assets",
      "- prerequisite_gaps_template_asset: assets/prerequisite_gaps_TEMPLATE.md",
      "- prerequisite_gaps_golden_example_asset: assets/prerequisite_gaps_GOLDEN_EXAMPLE.md",
      "",
      "## Read-Only Inputs",
      ...readOnlyInputs.lines,
      "",
      "## Active Repo Classes",
      ...activeClasses.map((klass) => `- ${klass}`),
      "",
      "## Allowed Write Surface",
      `- ${featurePath}/prerequisite_gaps.md`
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
