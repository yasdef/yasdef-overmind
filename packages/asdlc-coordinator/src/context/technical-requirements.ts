import { existsSync, readFileSync, statSync } from "node:fs";
import path from "node:path";

import { displayPath, resolveFeatureWithinWorkspace, stripQuotes } from "../parse/index.js";
import type { ContextResult } from "../types/index.js";

const SURFACE_CLASSES = new Set(["backend", "frontend", "mobile"]);
const VALID_PROJECT_CLASSES = new Set([...SURFACE_CLASSES, "infrastructure"]);

export function parseTechnicalRequirementsProjectClasses(definitionPath: string): string[] {
  const classes: string[] = [];
  let inMeta = false;
  let inClasses = false;
  const record = (raw: string): void => {
    const value = stripQuotes(raw).trim().toLowerCase();
    if (value !== "" && !classes.includes(value)) classes.push(value);
  };

  for (const rawLine of readFileSync(definitionPath, "utf8").split(/\r?\n/)) {
    if (/^meta_info:\s*$/.test(rawLine)) {
      inMeta = true;
      continue;
    }
    if (/^steps:\s*$/.test(rawLine) && inMeta) break;
    if (!inMeta) continue;
    const inline = rawLine.match(/^\s{2}project_classes:\s*\[([^\]]*)\]\s*$/);
    if (inline) {
      for (const item of inline[1]!.split(",")) record(item);
      inClasses = false;
      continue;
    }
    if (/^\s{2}project_classes:\s*$/.test(rawLine)) {
      inClasses = true;
      continue;
    }
    if (inClasses) {
      const item = rawLine.match(/^\s{4}-\s*(.*)$/);
      if (item) {
        record(item[1]!);
        continue;
      }
      inClasses = false;
    }
  }
  return classes;
}

export function buildTechnicalRequirementsContext(
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
  const contractPath = path.join(projectDir, "common_contract_definition.md");

  for (const requiredPath of [definitionPath, requirementsPath, contractPath]) {
    if (!isFile(requiredPath))
      return contextError(`Required file not found: ${displayPath(requiredPath, workspaceRoot)}`);
  }

  try {
    const projectClasses = parseTechnicalRequirementsProjectClasses(definitionPath);
    const unsupportedClass = projectClasses.find((item) => !VALID_PROJECT_CLASSES.has(item));
    if (unsupportedClass) {
      return contextError(
        `Unsupported project class '${unsupportedClass}' in ${displayPath(definitionPath, workspaceRoot)}; expected backend, frontend, mobile, or infrastructure`
      );
    }
    const classes = projectClasses.filter((item) => SURFACE_CLASSES.has(item));
    if (classes.length === 0) {
      return contextError(
        `No supported repo classes found in ${displayPath(definitionPath, workspaceRoot)}`
      );
    }
    const surfaceMaps = classes.map((klass) => ({
      klass,
      file: path.join(featureDir, `project_surface_struct_resp_map_${klass}.md`)
    }));
    for (const surface of surfaceMaps) {
      if (!isFile(surface.file)) {
        return contextError(`Required file not found: ${displayPath(surface.file, workspaceRoot)}`);
      }
    }

    const featurePath = displayPath(featureDir, workspaceRoot);
    const readOnly = [
      definitionPath,
      requirementsPath,
      contractPath,
      ...surfaceMaps.map((surface) => surface.file)
    ];
    const lines = [
      "# technical-requirements context",
      "",
      "## Runtime Paths",
      `- workspace_root: ${workspaceRoot}`,
      `- project_root: ${displayPath(projectDir, workspaceRoot)}`,
      `- feature_root: ${featurePath}`,
      `- progress_definition: ${displayPath(definitionPath, workspaceRoot)}`,
      `- requirements_ears_source: ${displayPath(requirementsPath, workspaceRoot)}`,
      `- common_contract_definition_source: ${displayPath(contractPath, workspaceRoot)}`,
      `- target_artifact: ${featurePath}/technical_requirements.md`,
      `- gate_command: node .overmind/overmind.js gate technical-requirements ${featurePath}`,
      "",
      "## Skill Assets",
      "- technical_requirements_template_asset: assets/technical_requirements_TEMPLATE.md",
      "- technical_requirements_golden_example_asset: assets/technical_requirements_GOLDEN_EXAMPLE.md",
      "",
      "## Read-Only Inputs",
      ...readOnly.map((file) => `- read_only_input: ${displayPath(file, workspaceRoot)}`),
      "",
      "## Active Surface-Map Classes",
      ...surfaceMaps.map(
        (surface) => `- ${surface.klass}: ${displayPath(surface.file, workspaceRoot)}`
      ),
      "",
      "## Allowed Write Surface",
      `- ${featurePath}/technical_requirements.md`
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
