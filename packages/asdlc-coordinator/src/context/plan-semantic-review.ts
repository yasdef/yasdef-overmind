import { existsSync, statSync } from "node:fs";
import path from "node:path";

import {
  displayPath,
  parseImplementationSlicesProjectClasses,
  resolveFeatureWithinWorkspace
} from "../parse/index.js";
import { PLAN_SEMANTIC_REVIEW_MUTABLE_GATES } from "../sequencing/review-session-contract.js";
import type { ContextResult } from "../types/index.js";
import { buildReadOnlyInputManifest } from "./read-only-inputs.js";

const SUPPORTED_CLASSES = new Set(["backend", "frontend", "mobile"]);
const VALID_CLASSES = new Set([...SUPPORTED_CLASSES, "infrastructure"]);

export function buildPlanSemanticReviewContext(
  inputPath: string,
  cwd = process.cwd()
): ContextResult {
  const resolved = resolveFeatureWithinWorkspace(inputPath, cwd);
  if (!resolved.ok) return contextError(resolved.message);
  const { workspaceRoot, featureDir, relativeFeature } = resolved.value;
  const parts = relativeFeature.split(path.sep);
  if (parts.length !== 3 || parts[0] !== "projects" || !parts[1] || !parts[2]) {
    return contextError(
      `Feature path must resolve under projects/<project-id>/<feature-folder>: ${relativeFeature}`
    );
  }

  const projectDir = path.join(workspaceRoot, "projects", parts[1]);
  const definitionPath = path.join(projectDir, "init_progress_definition.yaml");
  const requirementsPath = path.join(featureDir, "requirements_ears.md");
  const technicalPath = path.join(featureDir, "technical_requirements.md");
  const prerequisitePath = path.join(featureDir, "prerequisite_gaps.md");
  const planPath = path.join(featureDir, "implementation_plan.md");
  for (const required of [
    definitionPath,
    requirementsPath,
    technicalPath,
    prerequisitePath,
    planPath
  ]) {
    if (!isFile(required))
      return contextError(`Required file not found: ${displayPath(required, workspaceRoot)}`);
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
    const surfaceMaps = activeClasses.map((item) => ({
      klass: item,
      file: path.join(featureDir, `project_surface_struct_resp_map_${item}.md`)
    }));
    const missingMaps = surfaceMaps.filter(({ file }) => !isFile(file)).map(({ klass }) => klass);
    if (missingMaps.length > 0) {
      return contextError(
        `Required surface-map artifacts not found for active repo classes: ${missingMaps.join(" ")}`
      );
    }

    const featurePath = displayPath(featureDir, workspaceRoot);
    const readOnlyInputs = [
      definitionPath,
      requirementsPath,
      technicalPath,
      prerequisitePath,
      ...surfaceMaps.map(({ file }) => file)
    ];
    const readOnlyManifest = buildReadOnlyInputManifest(readOnlyInputs, workspaceRoot);
    const lines = [
      "# plan-semantic-review context",
      "",
      "## Runtime Paths",
      `- workspace_root: ${workspaceRoot}`,
      `- project_root: ${displayPath(projectDir, workspaceRoot)}`,
      `- feature_root: ${featurePath}`,
      ...PLAN_SEMANTIC_REVIEW_MUTABLE_GATES.map(
        (entry) => `- mutable_target: ${featurePath}/${entry.artifact}`
      ),
      `- review_gate_command: node .overmind/overmind.js gate plan-semantic-review ${featurePath}`,
      `- implementation_plan_gate_command: node .overmind/overmind.js gate implementation-plan ${featurePath}`,
      "",
      "## Skill Assets",
      "- implementation_plan_semantic_review_template_asset: assets/implementation_plan_semantic_review_TEMPLATE.md",
      "- implementation_plan_semantic_review_golden_example_asset: assets/implementation_plan_semantic_review_GOLDEN_EXAMPLE.md",
      "",
      "## Read-Only Inputs",
      ...readOnlyManifest.lines,
      "",
      "## Active Repo Classes",
      ...(activeClasses.length > 0 ? activeClasses.map((item) => `- ${item}`) : ["- none"]),
      "",
      "## Allowed Write Surface",
      ...PLAN_SEMANTIC_REVIEW_MUTABLE_GATES.map((entry) => `- ${featurePath}/${entry.artifact}`)
    ];
    return { exitCode: 0, text: `${lines.join("\n")}\n`, readOnlyInputs: readOnlyManifest.paths };
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
