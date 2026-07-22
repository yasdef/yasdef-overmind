import { existsSync, statSync } from "node:fs";
import path from "node:path";

import {
  checkRepoBranchState,
  collectReadyRepoPaths,
  computeCrossClassPeerTrigger,
  listCommittedSiblingFeatures
} from "../repo/index.js";
import { displayPath, resolveFeatureWithinWorkspace } from "../parse/index.js";
import type { ContextResult } from "../types/index.js";
import { buildReadOnlyInputManifest } from "./read-only-inputs.js";

export function buildContractDeltaContext(inputPath: string, cwd = process.cwd()): ContextResult {
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
  const featureBrPath = path.join(featureDir, "feature_br_summary.md");
  const earsPath = path.join(featureDir, "requirements_ears.md");
  const commonContractPath = path.join(projectDir, "common_contract_definition.md");

  for (const requiredPath of [definitionPath, featureBrPath, earsPath, commonContractPath]) {
    if (!existsSync(requiredPath) || !statSync(requiredPath).isFile()) {
      return contextError(`Required file not found: ${displayPath(requiredPath, workspaceRoot)}`);
    }
  }

  try {
    const readyRepos = collectReadyRepoPaths(definitionPath);
    for (const repo of readyRepos) {
      const stateResult = checkRepoBranchState(repo.path);
      if (!stateResult.ok) {
        return { exitCode: 2, errorMessage: stateResult.blockedMessage, verbatim: true };
      }
    }

    const pendingDeltaPaths = listCommittedSiblingFeatures(featureDir)
      .map((name) => path.join(projectDir, name, "feature_contract_delta.md"))
      .filter((candidate) => existsSync(candidate) && statSync(candidate).isFile());
    const trigger = computeCrossClassPeerTrigger(definitionPath);
    const featurePath = displayPath(featureDir, workspaceRoot);

    const readyRepoLines =
      readyRepos.length > 0
        ? readyRepos.map((repo) => `- ${repo.class}: ${repo.path}`)
        : ["- none"];
    const pendingLines =
      pendingDeltaPaths.length > 0
        ? pendingDeltaPaths.map(
            (pendingPath) =>
              `- Pending contract delta source: ${displayPath(pendingPath, projectDir)}`
          )
        : ["- none"];
    const readOnlyInputs = buildReadOnlyInputManifest(
      [featureBrPath, earsPath, commonContractPath, ...pendingDeltaPaths],
      workspaceRoot
    );

    const lines = [
      "# contract-delta context",
      "",
      "## Runtime Paths",
      `- workspace_root: ${workspaceRoot}`,
      `- project_root: ${displayPath(projectDir, workspaceRoot)}`,
      `- feature_root: ${featurePath}`,
      `- feature_br_source: ${displayPath(featureBrPath, workspaceRoot)}`,
      `- requirements_ears_source: ${displayPath(earsPath, workspaceRoot)}`,
      `- common_contract_baseline: ${displayPath(commonContractPath, workspaceRoot)}`,
      `- progress_definition: ${displayPath(definitionPath, workspaceRoot)}`,
      `- target_artifact: ${featurePath}/feature_contract_delta.md`,
      `- gate_command: node .overmind/overmind.js gate contract-delta ${featurePath}`,
      "",
      "## Skill Assets",
      "- feature_contract_delta_template_asset: assets/feature_contract_delta_TEMPLATE.md",
      "- feature_contract_delta_golden_example_asset: assets/feature_contract_delta_GOLDEN_EXAMPLE.md",
      "",
      "## Read-Only Inputs",
      ...readOnlyInputs.lines,
      "",
      "## Allowed Write Surface",
      `- ${featurePath}/feature_contract_delta.md`,
      "",
      "## Ready Repositories",
      ...readyRepoLines,
      "",
      "## Pending Sibling Contract Deltas",
      ...pendingLines,
      "",
      "## Deterministic Values",
      `- cross_class_peer_trigger: ${trigger}`
    ];

    return { exitCode: 0, text: `${lines.join("\n")}\n`, readOnlyInputs: readOnlyInputs.paths };
  } catch (err) {
    return contextError(err instanceof Error ? err.message : String(err));
  }
}

function contextError(message: string): ContextResult {
  return { exitCode: 2, errorMessage: message };
}
