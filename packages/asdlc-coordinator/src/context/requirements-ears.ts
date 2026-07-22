import { existsSync, statSync } from "node:fs";
import path from "node:path";

import {
  displayPath,
  readDocumentMetaValue,
  readRequiredTextFile,
  resolveInputPath
} from "../parse/index.js";

import type { ContextResult } from "../types/index.js";

export function buildRequirementsEarsContext(
  inputPath: string,
  cwd = process.cwd()
): ContextResult {
  if (!inputPath || inputPath.trim() === "") {
    return contextError("Missing feature path.");
  }

  const featureDir = resolveInputPath(inputPath, cwd);
  if (!existsSync(featureDir) || !statSync(featureDir).isDirectory()) {
    return contextError(`Feature path directory not found: ${inputPath}`);
  }

  const brSummaryPath = path.join(featureDir, "feature_br_summary.md");
  const targetEarsPath = path.join(featureDir, "requirements_ears.md");
  if (!existsSync(brSummaryPath)) {
    return contextError(
      `Upstream BR summary is required before BR-to-EARS conversion: ${displayPath(brSummaryPath, cwd)}`
    );
  }

  const featurePathForCommand = displayPath(featureDir, cwd);
  const brSummaryContent = readRequiredTextFile(brSummaryPath);
  const readiness = readDocumentMetaValue(brSummaryContent, "ready_to_ears");
  if (readiness !== "true") {
    return contextError(
      `Expected ready_to_ears: true in ${displayPath(brSummaryPath, cwd)}. Run \`readiness br-clarification\` for ${featurePathForCommand} first.`
    );
  }

  const lines = [
    "# requirements-ears context",
    "",
    "## Runtime Paths",
    `- workspace_root: ${cwd}`,
    `- feature_path: ${featureDir}`,
    `- feature_path_for_command: ${featurePathForCommand}`,
    `- target_ears_artifact: ${targetEarsPath}`,
    `- read_only_br_source: ${brSummaryPath}`,
    `- gate_command: node .overmind/overmind.js gate requirements-ears ${featurePathForCommand}`,
    "",
    "## Skill Assets",
    "- Use asset paths relative to the loaded overmind-requirements-ears skill directory, not relative to the ASDLC workspace root:",
    "- ears_template_asset: assets/reqirements_ears_TEMPLATE.md",
    "- ears_golden_example_asset: assets/reqirements_ears_GOLDEN_EXAMPLE.md",
    "- step_rule_location: inlined in SKILL.md",
    "",
    "## Allowed Write Surface",
    "- requirements_ears.md",
    "",
    "## Model Instructions",
    "- Treat the runtime paths above as authoritative for this invocation.",
    "- Read feature_br_summary.md as input only.",
    "- Update only the allowed-write artifact listed above.",
    "- Follow the loaded SKILL.md for conversion rules and gate exit handling.",
    "- Run the gate command after every write or repair."
  ];

  return {
    exitCode: 0,
    text: `${lines.join("\n")}\n`
  };
}

function contextError(message: string): ContextResult {
  return {
    exitCode: 2,
    errorMessage: message
  };
}
