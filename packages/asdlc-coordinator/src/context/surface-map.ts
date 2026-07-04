import { existsSync, readFileSync, statSync } from "node:fs";
import path from "node:path";

import {
  checkRepoBranchState,
  collectReadyRepoPaths,
  listCommittedSiblingFeatures
} from "../repo/index.js";
import { displayPath, resolveFeatureWithinWorkspace, stripQuotes } from "../parse/index.js";
import type { ContextResult } from "../types/index.js";
import type { SurfaceMapClass } from "../validate/surface-map.js";
import { buildReadOnlyInputManifest } from "./read-only-inputs.js";

interface ClassBinding {
  templateAsset: string;
  goldenAsset: string;
}

const CLASS_BINDINGS: Record<SurfaceMapClass, ClassBinding> = {
  backend: {
    templateAsset: "assets/project_surface_struct_resp_map_be_TEMPLATE.md",
    goldenAsset: "assets/project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md"
  },
  frontend: {
    templateAsset: "assets/project_surface_struct_resp_map_fe_TEMPLATE.md",
    goldenAsset: "assets/project_surface_struct_resp_map_fe_GOLDEN_EXAMPLE.md"
  },
  mobile: {
    templateAsset: "assets/project_surface_struct_resp_map_fe_TEMPLATE.md",
    goldenAsset: "assets/project_surface_struct_resp_map_fe_GOLDEN_EXAMPLE.md"
  }
};

function parseProjectClasses(definitionPath: string): string[] {
  const lines = readFileSync(definitionPath, "utf8").split(/\r?\n/);
  const classes: string[] = [];
  let inMeta = false;
  let inClasses = false;
  const record = (raw: string): void => {
    const value = stripQuotes(raw).toLowerCase();
    if (value !== "" && !classes.includes(value)) {
      classes.push(value);
    }
  };
  for (const rawLine of lines) {
    if (/^meta_info:\s*$/.test(rawLine)) {
      inMeta = true;
      continue;
    }
    if (/^steps:\s*$/.test(rawLine) && inMeta) {
      break;
    }
    if (!inMeta) {
      continue;
    }
    const inline = rawLine.match(/^\s{2}project_classes:\s*\[([^\]]*)\]\s*$/);
    if (inline) {
      for (const value of inline[1]!.split(",")) {
        record(value);
      }
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

export function buildSurfaceMapContext(
  inputPath: string,
  klass: SurfaceMapClass,
  cwd = process.cwd()
): ContextResult {
  const resolved = resolveFeatureWithinWorkspace(inputPath, cwd);
  if (!resolved.ok) {
    return contextError(resolved.message);
  }
  const { workspaceRoot, featureDir, relativeFeature } = resolved.value;
  const parts = relativeFeature.split(path.sep);
  if (parts.length !== 3 || parts[0] !== "projects" || parts[1] === "" || parts[2] === "") {
    return contextError(
      `Feature path must resolve under projects/<project-id>/<feature-folder>: ${relativeFeature}`
    );
  }

  const projectDir = path.join(workspaceRoot, "projects", parts[1]!);
  const definitionPath = path.join(projectDir, "init_progress_definition.yaml");
  const earsPath = path.join(featureDir, "requirements_ears.md");
  const contractDeltaPath = path.join(featureDir, "feature_contract_delta.md");

  for (const requiredPath of [definitionPath, earsPath, contractDeltaPath]) {
    if (!existsSync(requiredPath) || !statSync(requiredPath).isFile()) {
      return contextError(`Required file not found: ${displayPath(requiredPath, workspaceRoot)}`);
    }
  }

  try {
    const projectClasses = parseProjectClasses(definitionPath);
    if (!projectClasses.includes(klass)) {
      return contextError(
        `Class '${klass}' is not an active meta_info.project_classes member in ${displayPath(definitionPath, workspaceRoot)}`
      );
    }

    const readyRepo = collectReadyRepoPaths(definitionPath).find((repo) => repo.class === klass);
    const blueprintPath = path.join(projectDir, `project_stack_blueprint_${klass}.md`);
    // A blueprint is never retired: it remains read-only fallback evidence for
    // unmaterialized layers whenever it exists, independent of whether a ready
    // repo also exists. Its inclusion is gated on existence, not on fallback.
    const blueprintExists = existsSync(blueprintPath) && statSync(blueprintPath).isFile();
    let scanScopePath = "";
    if (readyRepo) {
      const stateResult = checkRepoBranchState(readyRepo.path);
      if (!stateResult.ok) {
        return { exitCode: 2, errorMessage: stateResult.blockedMessage, verbatim: true };
      }
      scanScopePath = readyRepo.path;
    } else if (!blueprintExists) {
      return contextError(
        `Class '${klass}' has neither a ready repository nor a stack blueprint (${displayPath(blueprintPath, workspaceRoot)}); it is not analyzable`
      );
    }

    const inFlightPlanPaths = listCommittedSiblingFeatures(featureDir)
      .map((name) => path.join(projectDir, name, "implementation_plan.md"))
      .filter((candidate) => existsSync(candidate) && statSync(candidate).isFile());

    const featurePath = displayPath(featureDir, workspaceRoot);
    const targetArtifact = `${featurePath}/project_surface_struct_resp_map_${klass}.md`;
    const binding = CLASS_BINDINGS[klass];

    const readOnlyPaths = [definitionPath, earsPath, contractDeltaPath];
    if (blueprintExists) {
      readOnlyPaths.push(blueprintPath);
    }
    readOnlyPaths.push(...inFlightPlanPaths);
    const readOnlyInputs = buildReadOnlyInputManifest(readOnlyPaths, workspaceRoot);

    const inFlightLines =
      inFlightPlanPaths.length > 0
        ? inFlightPlanPaths.map((p) => `- In-flight plan source: ${displayPath(p, projectDir)}`)
        : ["- none"];

    const scanScopeLine = scanScopePath
      ? `- ${klass}: ${scanScopePath}`
      : `- ${klass}: (no ready repository; blueprint evidence is primary planned structural evidence)`;

    const lines = [
      "# surface-map context",
      "",
      "## Runtime Paths",
      `- workspace_root: ${workspaceRoot}`,
      `- project_root: ${displayPath(projectDir, workspaceRoot)}`,
      `- feature_root: ${featurePath}`,
      `- target_class: ${klass}`,
      `- track_label: ${klass}`,
      `- project_classes: ${klass}`,
      `- progress_definition: ${displayPath(definitionPath, workspaceRoot)}`,
      `- requirements_ears_source: ${displayPath(earsPath, workspaceRoot)}`,
      `- feature_contract_delta_source: ${displayPath(contractDeltaPath, workspaceRoot)}`,
      `- target_artifact: ${targetArtifact}`,
      `- gate_command: node .overmind/overmind.js gate surface-map ${featurePath} --class ${klass}`,
      "",
      "## Skill Assets",
      `- surface_map_template_asset: ${binding.templateAsset}`,
      `- surface_map_golden_example_asset: ${binding.goldenAsset}`,
      "",
      "## Read-Only Inputs",
      ...readOnlyInputs.lines,
      "",
      "## Allowed Write Surface",
      `- ${targetArtifact}`,
      "",
      "## Scan Scope",
      scanScopeLine,
      ...(blueprintExists
        ? [`- Stack blueprint source: ${displayPath(blueprintPath, workspaceRoot)}`]
        : []),
      "",
      "## In-Flight Promise Evidence",
      ...inFlightLines
    ];

    return { exitCode: 0, text: `${lines.join("\n")}\n`, readOnlyInputs: readOnlyInputs.paths };
  } catch (err) {
    return contextError(err instanceof Error ? err.message : String(err));
  }
}

function contextError(message: string): ContextResult {
  return { exitCode: 2, errorMessage: message };
}
