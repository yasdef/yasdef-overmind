import { existsSync } from "node:fs";
import path from "node:path";

import { checkRepoBranchState, collectReadyRepoPaths } from "../repo/index.js";
import { displayPath, resolveFeatureWithinWorkspace } from "../parse/index.js";
import type { ContextResult } from "../types/index.js";

function findDefinitionFile(startDir: string, cwd: string): string | undefined {
  let searchDir = startDir;
  while (true) {
    const candidate = path.join(searchDir, "init_progress_definition.yaml");
    if (existsSync(candidate)) {
      return candidate;
    }
    if (searchDir === cwd) {
      break;
    }
    const parent = path.dirname(searchDir);
    if (parent === searchDir) {
      break;
    }
    if (!parent.startsWith(cwd)) {
      break;
    }
    searchDir = parent;
  }
  return undefined;
}

export function buildRepoBrScanContext(inputPath: string, cwd = process.cwd()): ContextResult {
  const resolved = resolveFeatureWithinWorkspace(inputPath, cwd);
  if (!resolved.ok) {
    return contextError(resolved.message);
  }
  const { workspaceRoot, featureDir } = resolved.value;

  const targetBrPath = path.join(featureDir, "feature_br_summary.md");
  if (!existsSync(targetBrPath)) {
    return contextError(`Required file not found: ${displayPath(targetBrPath, workspaceRoot)}`);
  }

  const definitionPath = findDefinitionFile(featureDir, workspaceRoot);
  if (!definitionPath) {
    return contextError(
      `Required file not found: <path ancestor>/init_progress_definition.yaml (path: ${displayPath(featureDir, workspaceRoot)})`
    );
  }

  let readyRepos: Array<{ class: string; path: string }>;
  try {
    readyRepos = collectReadyRepoPaths(definitionPath);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return contextError(msg);
  }

  if (readyRepos.length === 0) {
    return {
      exitCode: 0,
      text: [
        "# repo-br-scan context",
        "",
        "No ready class repositories found. Repo scan is a no-op for this run.",
        "",
        "Instruction: the repo scan phase is complete without changes. Do not edit any artifact. Finish the session.",
        ""
      ].join("\n")
    };
  }

  for (const repo of readyRepos) {
    const stateResult = checkRepoBranchState(repo.path);
    if (!stateResult.ok) {
      return contextBlocked(stateResult.blockedMessage);
    }
  }

  const featurePathForCommand = displayPath(featureDir, workspaceRoot);
  const targetBrRelPath = displayPath(targetBrPath, workspaceRoot);
  const definitionRelPath = displayPath(definitionPath, workspaceRoot);

  const repoLines = readyRepos.map((r) => `- ${r.class}: ${r.path}`);

  const lines = [
    "# repo-br-scan context",
    "",
    "## Runtime Paths",
    `- workspace_root: ${workspaceRoot}`,
    `- feature_path: ${featurePathForCommand}`,
    `- target_br_artifact: ${targetBrRelPath}`,
    `- progress_definition: ${definitionRelPath}`,
    `- gate_command: node .overmind/overmind.js gate repo-br-scan ${featurePathForCommand}`,
    "",
    "## Skill Assets",
    "- Use asset paths relative to the loaded overmind-repo-br-scan skill directory, not relative to the ASDLC workspace root:",
    "- feature_br_template_asset: assets/feature_br_summary_TEMPLATE.md",
    "- feature_br_golden_example_asset: assets/feature_br_summary_GOLDEN_EXAMPLE.md",
    "",
    "## Read-Only Inputs",
    `- init_progress_definition.yaml: ${definitionRelPath}`,
    "- Repositories listed below are READ-ONLY. Do not edit any file inside them.",
    "",
    "## Allowed Write Surface",
    "- In feature_br_summary.md, you may ONLY edit:",
    "  - ## 1. Document Meta: last_updated, source_type",
    "  - ## 13. Existing-System Context: all existing fields",
    "",
    "## Repositories to Scan",
    ...repoLines
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

function contextBlocked(message: string): ContextResult {
  return {
    exitCode: 2,
    errorMessage: message,
    verbatim: true
  };
}
