import { existsSync, readFileSync, statSync } from "node:fs";
import path from "node:path";

import { displayPath, resolveFeatureWithinWorkspace, stripQuotes } from "../parse/index.js";
import type { ContextResult } from "../types/index.js";

const PLACEHOLDER_LITERAL = "<to be defined during implementation>";
const EXTERNAL_SOURCES_FILE = ".setup/external_sources.yaml";
const SURFACE_MAP_CLASSES = ["backend", "frontend", "mobile"] as const;

function parseExternalSourceNames(content: string): string[] {
  const lines = content.split(/\r?\n/);
  const names: string[] = [];
  let inSources = false;

  for (const line of lines) {
    if (/^sources:\s*\[\]\s*$/.test(line)) return [];
    if (/^sources:\s*$/.test(line)) {
      inSources = true;
      continue;
    }
    if (inSources && /^[^\s#]/.test(line)) {
      inSources = false;
      continue;
    }
    if (!inSources) continue;
    const match = line.match(/^\s*-\s+name:\s*(.*)$/);
    if (match) {
      const name = stripQuotes(match[1]!.trim());
      if (name) names.push(name);
    }
  }
  return names;
}

function isKnowledgeBaseName(name: string): boolean {
  const lower = name.toLowerCase();
  return lower.includes("knowledge") || lower.includes("kb");
}

export function buildSurfaceMapEnrichContext(
  inputPath: string,
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

  const mapsWithPlaceholders: Array<{ relPath: string; klass: string }> = [];
  for (const klass of SURFACE_MAP_CLASSES) {
    const mapPath = path.join(featureDir, `project_surface_struct_resp_map_${klass}.md`);
    if (!existsSync(mapPath) || !statSync(mapPath).isFile()) continue;
    if (readFileSync(mapPath, "utf8").includes(PLACEHOLDER_LITERAL)) {
      mapsWithPlaceholders.push({ relPath: displayPath(mapPath, workspaceRoot), klass });
    }
  }

  if (mapsWithPlaceholders.length === 0) {
    return noOpContext("No surface maps with placeholder fields found.");
  }

  const sourcesPath = path.join(workspaceRoot, EXTERNAL_SOURCES_FILE);
  if (!existsSync(sourcesPath) || !statSync(sourcesPath).isFile()) {
    return contextError(`Required file not found: ${EXTERNAL_SOURCES_FILE}`);
  }

  const eligibleNames = parseExternalSourceNames(readFileSync(sourcesPath, "utf8")).filter(
    isKnowledgeBaseName
  );

  if (eligibleNames.length === 0) {
    return noOpContext(
      "No eligible knowledge-base MCP sources configured in .setup/external_sources.yaml."
    );
  }

  const featurePath = displayPath(featureDir, workspaceRoot);
  const mapEntries: string[] = [];
  const gateEntries: string[] = [];
  const writeEntries: string[] = [];

  for (const { relPath, klass } of mapsWithPlaceholders) {
    mapEntries.push(`  - file: ${relPath}`, `    class: ${klass}`);
    gateEntries.push(
      `  - node .overmind/overmind.js gate surface-map ${featurePath} --class ${klass}`
    );
    writeEntries.push(`- ${relPath}`);
  }

  const sourceEntries = eligibleNames.map((n) => `  - ${n}`);

  const lines = [
    "# surface-map-enrich context",
    "",
    "## Runtime Paths",
    `- workspace_root: ${workspaceRoot}`,
    `- feature_root: ${featurePath}`,
    `- external_sources: ${EXTERNAL_SOURCES_FILE}`,
    "",
    "## Surface Maps With Placeholders",
    ...mapEntries,
    "",
    "## Gate Commands (per class)",
    ...gateEntries,
    "",
    "## Eligible Knowledge-Base MCP Source Names",
    ...sourceEntries,
    "",
    "## Read-Only Inputs",
    `- read_only_input: ${EXTERNAL_SOURCES_FILE}`,
    "",
    "## Allowed Write Surface",
    ...writeEntries
  ];

  return { exitCode: 0, text: `${lines.join("\n")}\n` };
}

function noOpContext(reason: string): ContextResult {
  const lines = ["# surface-map-enrich context", "", "no_op: true", `reason: ${reason}`];
  return { exitCode: 0, text: `${lines.join("\n")}\n` };
}

function contextError(message: string): ContextResult {
  return { exitCode: 2, errorMessage: message };
}
