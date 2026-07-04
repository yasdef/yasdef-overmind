import { existsSync, readFileSync, statSync } from "node:fs";
import path from "node:path";

import { displayPath, readUserBrInput, resolveInputPath } from "../parse/index.js";

import type { ContextResult } from "../types/index.js";

export function buildTaskToBrContext(inputPath: string, cwd = process.cwd()): ContextResult {
  if (!inputPath || inputPath.trim() === "") {
    return contextError("Missing feature path.");
  }

  const featureDir = resolveInputPath(inputPath, cwd);
  if (!existsSync(featureDir) || !statSync(featureDir).isDirectory()) {
    return contextError(`Feature path directory not found: ${inputPath}`);
  }

  const targetBrPath = path.join(featureDir, "feature_br_summary.md");
  const userInputPath = path.join(featureDir, "user_br_input.md");
  const missingDataPath = path.join(featureDir, "missing_br_data.md");

  if (!existsSync(targetBrPath)) {
    return contextError(`Required file not found: ${displayPath(targetBrPath, cwd)}`);
  }
  if (!existsSync(userInputPath)) {
    return contextError(`Required file not found: ${displayPath(userInputPath, cwd)}`);
  }

  const userInput = readUserBrInput(userInputPath);
  const featurePathForCommand = displayPath(featureDir, cwd);
  const sourceFile = userInput.epicStorySourceFile ?? "[UNFILLED]";
  const jiraNames = sourceFile.startsWith("jira:")
    ? extractJiraSourceNames(path.join(cwd, ".setup", "external_sources.yaml"))
    : [];

  const lines = [
    "# task-to-br context",
    "",
    "## Runtime Paths",
    `- workspace_root: ${cwd}`,
    `- feature_path: ${featurePathForCommand}`,
    `- target_br_artifact: ${displayPath(targetBrPath, cwd)}`,
    `- captured_user_input_artifact: ${displayPath(userInputPath, cwd)}`,
    `- missing_data_artifact: ${displayPath(missingDataPath, cwd)}`,
    `- gate_command: node .overmind/overmind.js gate task-to-br ${featurePathForCommand}`,
    "",
    "## Skill Assets",
    "- Use asset paths relative to the loaded overmind-task-to-br skill directory, not relative to the ASDLC workspace root:",
    "- feature_br_template_asset: assets/feature_br_summary_TEMPLATE.md",
    "- feature_br_golden_example_asset: assets/feature_br_summary_GOLDEN_EXAMPLE.md",
    "- missing_data_template_asset: assets/missing_br_data_TEMPLATE.md",
    "- missing_data_golden_example_asset: assets/missing_br_data_GOLDEN_EXAMPLE.md",
    "",
    "## Captured User Input",
    `- feature_id: ${userInput.featureId ?? "[UNFILLED]"}`,
    `- feature_title: ${userInput.featureTitle ?? "[UNFILLED]"}`,
    `- epic_story_source_file: ${sourceFile}`,
    `- request_summary: ${userInput.requestSummary ?? "[UNFILLED]"}`,
    `- additional_business_context: ${userInput.additionalBusinessContext ?? "[UNFILLED]"}`,
    "",
    "## Epic/Story Input",
    userInput.epicOrStory.trim() === "" ? "[UNFILLED]" : userInput.epicOrStory,
    "",
    "## Model Instructions",
    "- Treat the runtime paths above as authoritative for this invocation.",
    "- Update only feature_br_summary.md, missing_br_data.md, and user_br_input.md when a Jira fetch result must be persisted.",
    "- Create or refresh missing_br_data.md even when no unresolved business gaps remain.",
    "- Run the gate command after writing or repairing artifacts."
  ];

  if (sourceFile.startsWith("jira:")) {
    lines.push(
      "",
      "## Jira MCP Fetch Instruction",
      `- epic_story_source: ${sourceFile}`,
      "- external_sources_config: .setup/external_sources.yaml",
      "- eligible_jira_mcp_source_names:"
    );
    if (jiraNames.length === 0) {
      lines.push("  - none configured");
    } else {
      for (const name of jiraNames) {
        lines.push(`  - ${name}`);
      }
    }
    lines.push(
      "- Fetch the Jira story through an eligible MCP source and persist the fetched story text into user_br_input.md -> epic_or_story before finalizing.",
      "- If no eligible source is reachable or the ticket cannot be retrieved, stop and ask the user for a local .txt or .md story file."
    );
  }

  return {
    exitCode: 0,
    text: `${lines.join("\n")}\n`
  };
}

export function extractJiraSourceNames(sourcesPath: string): string[] {
  if (!existsSync(sourcesPath)) {
    return [];
  }

  const content = readFileSyncUtf8(sourcesPath);
  const names: string[] = [];
  let inSources = false;
  let currentName = "";
  let currentType = "";

  const flush = () => {
    if (currentName !== "" && currentType.toLowerCase().includes("jira")) {
      names.push(currentName);
    }
    currentName = "";
    currentType = "";
  };

  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trimEnd();
    if (/^sources:\s*\[\]\s*$/.test(line)) {
      return [];
    }
    if (/^sources:\s*$/.test(line)) {
      inSources = true;
      continue;
    }
    if (!inSources) {
      continue;
    }
    if (/^[^\s#]/.test(line)) {
      flush();
      break;
    }
    const nameMatch = line.match(/^\s*-\s*name:\s*(.*)$/);
    if (nameMatch) {
      flush();
      currentName = stripYamlScalar(nameMatch[1] ?? "");
      continue;
    }
    const typeMatch = line.match(/^\s+type:\s*(.*)$/);
    if (typeMatch) {
      currentType = stripYamlScalar(typeMatch[1] ?? "");
    }
  }
  flush();
  return names;
}

function readFileSyncUtf8(filePath: string): string {
  return existsSync(filePath) ? readFileSync(filePath, "utf8") : "";
}

function stripYamlScalar(value: string): string {
  const trimmed = value.trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1).trim();
  }
  return trimmed;
}

function contextError(message: string): ContextResult {
  return {
    exitCode: 2,
    errorMessage: message
  };
}
