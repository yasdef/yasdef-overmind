import { existsSync, statSync } from "node:fs";
import path from "node:path";

import {
  isUnfilled,
  normalizeValue,
  parseBulletField,
  readRequiredTextFile,
  resolveInputPath
} from "../parse/index.js";
import type { GateResult } from "../types/index.js";

const AGENT_CLASSES = ["backend", "frontend", "mobile"] as const;
type AgentsMdClass = (typeof AGENT_CLASSES)[number];

const REQUIRED_SECTIONS = [
  "## 1. Document Meta",
  "## Stack Baseline",
  "## Target Project Shape",
  "## Layer Responsibilities",
  "## Mission",
  "## Non-Negotiable Engineering Rules",
  "## Coding Standards",
  "## Testing Standard",
  "## Linting and Quality Gates",
  "## Definition of Done",
  "## Decision Guidance for Agents"
] as const;

const OPTIONAL_UI_SECTIONS = [
  "## Accessibility (a11y)",
  "## Internationalization (i18n)",
  "## UI Automation IDs",
  "## Applied Visual Style Contract"
] as const;

const ALL_SECTIONS = new Set<string>([...REQUIRED_SECTIONS, ...OPTIONAL_UI_SECTIONS]);
const TESTING_STANDARD_SECTION = "## Testing Standard";

export function validateAgentsMd(inputPath: string, cwd = process.cwd()): GateResult {
  if (!inputPath || inputPath.trim() === "") {
    return gateError("Missing target project agents-md artifact path argument.");
  }

  try {
    const targetPath = resolveInputPath(inputPath, cwd);
    if (!existsSync(targetPath)) {
      return gateError(`Target project agents-md artifact not found: ${targetPath}`);
    }
    if (statSync(targetPath).isDirectory()) {
      return gateError(`Target project agents-md artifact is a directory: ${targetPath}`);
    }

    const content = readRequiredTextFile(targetPath);
    if (!/[^ \t\r\n]/.test(content)) {
      return gateRecoverable([
        `quality gate failed: target project agents-md artifact is empty: ${targetPath}`
      ]);
    }

    const problems = validateAgentsMdContent(content);
    const filenameClass = classFromFilename(targetPath);
    const contentClass = classFromContent(content);
    if (filenameClass && contentClass && filenameClass !== contentClass) {
      problems.push(
        `quality gate failed: class '${contentClass}' does not match filename class '${filenameClass}'`
      );
    }
    return problems.length > 0 ? gateRecoverable(problems) : gatePassed();
  } catch (error) {
    return gateError(error instanceof Error ? error.message : String(error));
  }
}

export function validateAgentsMdContent(content: string): string[] {
  const problems: string[] = [];
  const fail = (message: string): void => {
    problems.push(`quality gate failed: ${message}`);
  };

  if (!/[^ \t\r\n]/.test(content)) {
    fail("artifact is empty");
    return problems;
  }

  const seenSections = new Set<string>();
  const sectionBodies = new Map<string, string[]>();
  const meta = new Map<string, string>();
  let currentSection = "";
  let inComment = false;

  for (const rawLine of content.split(/\r?\n/)) {
    if (inComment) {
      if (rawLine.includes("-->")) inComment = false;
      continue;
    }
    if (rawLine.includes("<!--")) {
      if (!rawLine.includes("-->")) inComment = true;
      continue;
    }
    if (/\[UNFILLED\]/i.test(rawLine)) {
      fail("artifact still contains [UNFILLED] placeholders");
    }

    const heading = rawLine.trim();
    if (/^##\s+/.test(heading)) {
      currentSection = heading;
      if (!ALL_SECTIONS.has(heading)) {
        fail(`unexpected top-level section: ${heading}`);
      } else if (seenSections.has(heading)) {
        fail(`duplicate top-level section: ${heading}`);
      }
      seenSections.add(heading);
      sectionBodies.set(heading, []);
      continue;
    }

    if (currentSection !== "" && ALL_SECTIONS.has(currentSection)) {
      sectionBodies.get(currentSection)?.push(rawLine);
    }

    if (currentSection !== "## 1. Document Meta") continue;
    const field = parseBulletField(rawLine);
    if (!field) continue;
    meta.set(normalizeValue(field.key), field.value);
  }

  for (const section of REQUIRED_SECTIONS) {
    if (!seenSections.has(section)) fail(`missing section: ${section}`);
    else if (!hasSectionBody(sectionBodies.get(section) ?? [])) {
      fail(`section has no body content: ${section}`);
    }
  }

  const testingStandardBody = (sectionBodies.get(TESTING_STANDARD_SECTION) ?? []).join("\n");
  if (
    seenSections.has(TESTING_STANDARD_SECTION) &&
    !/(^|[^\d])\d{1,3}%/.test(testingStandardBody)
  ) {
    fail(`${TESTING_STANDARD_SECTION} must include a percentage coverage floor`);
  }

  for (const key of ["artifact_kind", "class", "project", "source_blueprint", "last_updated"]) {
    requireMapKey(meta, key, "meta key", fail);
  }

  const artifactKind = meta.get("artifact_kind");
  if (!isUnfilled(artifactKind) && artifactKind !== "project_agents_md_claude_md") {
    fail("artifact_kind must be project_agents_md_claude_md");
  }

  const lastUpdated = meta.get("last_updated");
  if (!isUnfilled(lastUpdated) && !/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(lastUpdated!)) {
    fail("last_updated must use YYYY-MM-DD format");
  }

  const klassValue = normalizeValue(meta.get("class") ?? "");
  const klass = klassValue as AgentsMdClass;
  const hasSupportedClass = AGENT_CLASSES.includes(klass);
  if (!isUnfilled(meta.get("class")) && !hasSupportedClass) {
    fail(`unsupported class value: ${klassValue} (allowed: backend, frontend, mobile)`);
  }

  if (!hasSupportedClass) return problems;

  const sourceBlueprint = meta.get("source_blueprint");
  if (!isUnfilled(sourceBlueprint) && sourceBlueprint !== `project_stack_blueprint_${klass}.md`) {
    fail(`source_blueprint must be project_stack_blueprint_${klass}.md`);
  }

  if (klass === "backend") {
    for (const section of OPTIONAL_UI_SECTIONS) {
      if (seenSections.has(section)) fail(`section is forbidden for backend artifacts: ${section}`);
    }
  }

  return problems;
}

function hasSectionBody(lines: string[]): boolean {
  return lines.some((line) => {
    const trimmed = line.trim();
    return trimmed !== "" && !/^<!--/.test(trimmed) && !/^-->$/.test(trimmed);
  });
}

function classFromContent(content: string): AgentsMdClass | undefined {
  for (const rawLine of content.split(/\r?\n/)) {
    const field = parseBulletField(rawLine);
    if (normalizeValue(field?.key ?? "") !== "class") continue;
    const value = normalizeValue(field?.value ?? "");
    return AGENT_CLASSES.includes(value as AgentsMdClass) ? (value as AgentsMdClass) : undefined;
  }
  return undefined;
}

function classFromFilename(filePath: string): AgentsMdClass | undefined {
  const match = path
    .basename(filePath)
    .match(/^project_agents_md_claude_md_(backend|frontend|mobile)\.md$/);
  return match?.[1] as AgentsMdClass | undefined;
}

function requireMapKey(
  values: Map<string, string>,
  key: string,
  label: string,
  fail: (message: string) => void
): void {
  if (isUnfilled(values.get(key))) fail(`missing or unfilled ${label}: ${key}`);
}

function gatePassed(): GateResult {
  return {
    exitCode: 0,
    passMessage: "quality gate passed: project agents-md structure is complete",
    problems: []
  };
}

function gateRecoverable(problems: string[]): GateResult {
  return { exitCode: 1, passMessage: "", problems };
}

function gateError(message: string): GateResult {
  return { exitCode: 2, passMessage: "", problems: [], errorMessage: message };
}
