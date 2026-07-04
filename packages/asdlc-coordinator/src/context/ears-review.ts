import { existsSync, statSync } from "node:fs";
import path from "node:path";

import { displayPath, resolveInputPath } from "../parse/index.js";

import type { ContextResult } from "../types/index.js";

export function buildEarsReviewContext(inputPath: string, cwd = process.cwd()): ContextResult {
  if (!inputPath || inputPath.trim() === "") {
    return contextError("Missing feature path.");
  }

  const featureDir = resolveInputPath(inputPath, cwd);
  if (!existsSync(featureDir) || !statSync(featureDir).isDirectory()) {
    return contextError(`Feature path directory not found: ${inputPath}`);
  }

  const brSummaryPath = path.join(featureDir, "feature_br_summary.md");
  const requirementsEarsPath = path.join(featureDir, "requirements_ears.md");
  const reviewLedgerPath = path.join(featureDir, "requirements_ears_review.md");
  if (!existsSync(brSummaryPath)) {
    return contextError(
      `Upstream BR summary is required before EARS review: ${displayPath(brSummaryPath, cwd)}`
    );
  }
  if (!existsSync(requirementsEarsPath)) {
    return contextError(
      `Upstream EARS requirements are required before EARS review: ${displayPath(requirementsEarsPath, cwd)}`
    );
  }

  const featurePathForCommand = displayPath(featureDir, cwd);
  const lines = [
    "# ears-review context",
    "",
    "## Runtime Paths",
    `- workspace_root: ${cwd}`,
    `- feature_path: ${featureDir}`,
    `- feature_path_for_command: ${featurePathForCommand}`,
    `- read_only_br_source: ${brSummaryPath}`,
    `- requirements_ears_artifact: ${requirementsEarsPath}`,
    `- review_ledger_artifact: ${reviewLedgerPath}`,
    `- gate_command: node .overmind/overmind.js gate ears-review ${featurePathForCommand}`,
    "",
    "## Skill Assets",
    "- Use asset paths relative to the loaded overmind-ears-review skill directory, not relative to the ASDLC workspace root:",
    "- review_template_asset: assets/requirements_ears_review_TEMPLATE.md",
    "- review_golden_example_asset: assets/requirements_ears_review_GOLDEN_EXAMPLE.md",
    "- step_rule_location: inlined in SKILL.md",
    "",
    "## Allowed Write Surface",
    "- requirements_ears.md",
    "- requirements_ears_review.md",
    "",
    "## Model Instructions",
    "- Treat the runtime paths above as authoritative for this invocation.",
    "- Read feature_br_summary.md as input only.",
    "- Update only the allowed-write artifacts listed above.",
    "- Follow the loaded SKILL.md for review rules and gate exit handling.",
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
