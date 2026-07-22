import { existsSync, statSync } from "node:fs";
import path from "node:path";

import { displayPath, resolveInputPath } from "../parse/index.js";

import type { ContextResult } from "../types/index.js";

export function buildBrClarificationContext(inputPath: string, cwd = process.cwd()): ContextResult {
  if (!inputPath || inputPath.trim() === "") {
    return contextError("Missing feature path.");
  }

  const featureDir = resolveInputPath(inputPath, cwd);
  if (!existsSync(featureDir) || !statSync(featureDir).isDirectory()) {
    return contextError(`Feature path directory not found: ${inputPath}`);
  }

  const targetBrPath = path.join(featureDir, "feature_br_summary.md");
  const missingDataPath = path.join(featureDir, "missing_br_data.md");
  if (!existsSync(targetBrPath)) {
    return contextError(`Required file not found: ${displayPath(targetBrPath, cwd)}`);
  }
  if (!existsSync(missingDataPath)) {
    return contextError(
      `Required missing-data artifact not found: ${displayPath(missingDataPath, cwd)}. Run the overmind-task-to-br skill for this feature before user BR clarification.`
    );
  }

  const featurePathForCommand = displayPath(featureDir, cwd);
  const lines = [
    "# br-clarification context",
    "",
    "## Runtime Paths",
    `- workspace_root: ${cwd}`,
    `- feature_path: ${featurePathForCommand}`,
    `- target_br_artifact: ${displayPath(targetBrPath, cwd)}`,
    `- missing_data_artifact: ${displayPath(missingDataPath, cwd)}`,
    `- gate_command: node .overmind/overmind.js gate br-clarification ${featurePathForCommand}`,
    "",
    "## Skill Assets",
    "- Use asset paths relative to the loaded overmind-br-clarification skill directory, not relative to the ASDLC workspace root:",
    "- feature_br_template_asset: assets/feature_br_summary_TEMPLATE.md",
    "- feature_br_golden_example_asset: assets/feature_br_summary_GOLDEN_EXAMPLE.md",
    "",
    "## Allowed Write Surface",
    "- feature_br_summary.md",
    "- missing_br_data.md",
    "",
    "## Model Instructions",
    "- Treat the runtime paths above as authoritative for this invocation.",
    "- Update only the allowed-write artifacts listed above.",
    "- Follow the loaded SKILL.md for rules and gate exit handling.",
    "- Run the gate command after each answer round."
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
