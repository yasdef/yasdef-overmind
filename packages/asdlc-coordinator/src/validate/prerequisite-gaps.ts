import { existsSync, readFileSync, statSync } from "node:fs";
import path from "node:path";

import { displayPath, resolveFeatureWithinWorkspace } from "../parse/index.js";
import type { GateResult } from "../types/index.js";

interface PrerequisiteBlock {
  name: string;
  status: string;
  surfaceKind: string;
  surfaceIdentity: string;
  evidence: string;
  sliceRef: string;
}

interface RequirementCoverageBlock {
  name: string;
  summary: string;
  prerequisites: string;
}

export function validatePrerequisiteGaps(inputPath: string, cwd = process.cwd()): GateResult {
  if (!inputPath || inputPath.trim() === "") return gateError("Missing target feature path argument.");
  const resolved = resolveFeatureWithinWorkspace(inputPath, cwd);
  if (!resolved.ok) return gateError(resolved.message);
  const { workspaceRoot, featureDir, relativeFeature } = resolved.value;
  const parts = relativeFeature.split(path.sep);
  if (parts.length !== 3 || parts[0] !== "projects") {
    return gateError(`Feature path must resolve under projects/<project-id>/<feature-folder>: ${relativeFeature}`);
  }
  const targetPath = path.join(featureDir, "prerequisite_gaps.md");
  const requirementsPath = path.join(featureDir, "requirements_ears.md");
  const technicalPath = path.join(featureDir, "technical_requirements.md");
  if (!isFile(targetPath)) return gateError(`Target prerequisite gaps artifact not found: ${displayPath(targetPath, workspaceRoot)}`);
  const content = readFileSync(targetPath, "utf8");
  if (!/\S/.test(content)) return gateFailure([`target prerequisite gaps artifact is empty: ${displayPath(targetPath, workspaceRoot)}`]);
  if (!isFile(requirementsPath)) return gateError(`Required sibling artifact not found for quality check: ${displayPath(requirementsPath, workspaceRoot)}`);
  if (!isFile(technicalPath)) return gateError(`Required sibling artifact not found for quality check: ${displayPath(technicalPath, workspaceRoot)}`);

  try {
    const problems = validatePrerequisiteGapsContent(
      content,
      readFileSync(requirementsPath, "utf8"),
      readFileSync(technicalPath, "utf8")
    );
    return problems.length === 0
      ? { exitCode: 0, passMessage: "quality gate passed", problems: [] }
      : gateFailure(problems);
  } catch (err) {
    return gateError(err instanceof Error ? err.message : String(err));
  }
}

export function validatePrerequisiteGapsContent(content: string, requirements: string, technical: string): string[] {
  const problems: string[] = [];
  if (!/^## 2\. Prerequisite Catalog\s*$/m.test(content)) problems.push("missing section: ## 2. Prerequisite Catalog");
  if (!/^## 3\. Requirement Coverage\s*$/m.test(content)) problems.push("missing section: ## 3. Requirement Coverage");
  rejectCatalogContentOutsideCatalog(content, problems);
  const catalog = sectionLines(content, /^## 2\. Prerequisite Catalog\s*$/);
  const coverage = sectionLines(content, /^## 3\. Requirement Coverage\s*$/);
  const blocks = parsePrerequisites(catalog);
  for (const block of blocks) validateBlock(block, problems);

  const catalogNames = new Set<string>();
  for (const block of blocks) {
    if (catalogNames.has(block.name)) problems.push(`catalog prerequisite is declared more than once: "${block.name}"`);
    catalogNames.add(block.name);
  }

  const referencedNames = new Set<string>();
  for (const requirement of parseRequirementCoverage(coverage)) {
    if (unfilled(requirement.summary)) problems.push(`requirement ${requirement.name} is missing requirement_summary`);
    if (unfilled(requirement.prerequisites)) {
      problems.push(`requirement ${requirement.name} is missing prerequisites`);
      continue;
    }
    if (requirement.prerequisites === "none") continue;
    for (const reference of requirement.prerequisites.split(/\s*;\s*/).filter(Boolean)) {
      referencedNames.add(reference);
      if (!catalogNames.has(reference)) problems.push(`prerequisite reference does not resolve to any catalog entry: "${reference}"`);
    }
  }
  for (const name of catalogNames) {
    if (!referencedNames.has(name)) problems.push(`catalog prerequisite is referenced by no requirement: "${name}"`);
  }

  const entries = extractPrerequisiteEntries(catalog);
  const surfaces = technical.split(/\r?\n/).flatMap((line) => {
    const match = line.match(/^\s*-\s*user_reachable_surface:\s*(.*)$/);
    if (!match) return [];
    const value = match[1].trim();
    return unfilled(value) || value === "none" ? [] : [value];
  });
  for (const literal of extractEarsLiterals(requirements)) {
    if (![...entries, ...surfaces].some((value) => value.includes(literal))) {
      problems.push(`literal "${literal}" from requirements_ears.md is absent from both prerequisite_gaps.md entries and user_reachable_surface in technical_requirements.md`);
    }
  }
  return problems;
}

function extractPrerequisiteEntries(content: string): string[] {
  return content.split(/\r?\n/).flatMap((line) => {
    const match = line.match(/^\s*-\s*(?:evidence|slice_ref):\s*(.*)$/);
    if (!match) return [];
    const value = match[1].trim();
    return unfilled(value) || value === "none" ? [] : [value];
  });
}

function rejectCatalogContentOutsideCatalog(content: string, problems: string[]): void {
  let catalogSeen = false;
  let inCatalog = false;
  let inRequirementCoverage = false;
  for (const line of content.split(/\r?\n/)) {
    if (/^##\s+/.test(line)) {
      const startsFirstCatalog = !catalogSeen && /^## 2\. Prerequisite Catalog\s*$/.test(line);
      if (startsFirstCatalog) catalogSeen = true;
      inCatalog = startsFirstCatalog;
      inRequirementCoverage = /^## 3\. Requirement Coverage\s*$/.test(line);
      continue;
    }
    const heading = line.match(/^#### Prerequisite:\s*(.*)$/);
    if (heading && !inCatalog) {
      const name = heading[1].trim() || "[empty]";
      problems.push(`prerequisite "${name}" appears outside ## 2. Prerequisite Catalog`);
    }
    const catalogField = line.match(/^\s*-\s*(status|surface_kind|surface_identity|evidence|slice_ref):/);
    if (catalogField && inRequirementCoverage) {
      problems.push(`requirement coverage restates catalog field: ${catalogField[1]}`);
    }
  }
}

export function extractEarsLiterals(content: string): string[] {
  const literals = new Set<string>();
  for (const line of content.split(/\r?\n/)) {
    for (const match of line.matchAll(/(?:POST|GET|PUT|DELETE|PATCH)\s+\/[^\s`"',;.)\]]+/g)) {
      literals.add(match[0].replace(/\s+/g, " ").trim());
    }
    for (const match of line.matchAll(/`(\/[^`\s]+)`/g)) literals.add(match[1].trim());
    for (const match of line.matchAll(/\/[a-zA-Z][a-zA-Z0-9/_-]*/g)) {
      if (match[0].length > 2) literals.add(match[0]);
    }
  }
  return [...literals].sort();
}

function sectionLines(content: string, headingPattern: RegExp): string {
  const lines: string[] = [];
  let inSection = false;
  for (const line of content.split(/\r?\n/)) {
    if (/^##\s+/.test(line)) {
      if (inSection) break;
      inSection = headingPattern.test(line);
      continue;
    }
    if (inSection) lines.push(line);
  }
  return lines.join("\n");
}

function parsePrerequisites(content: string): PrerequisiteBlock[] {
  const blocks: PrerequisiteBlock[] = [];
  let current: PrerequisiteBlock | undefined;
  const flush = (): void => { if (current && current.name !== "") blocks.push(current); current = undefined; };
  for (const line of content.split(/\r?\n/)) {
    const match = line.match(/^#### Prerequisite:\s*(.*)$/);
    if (match) {
      flush();
      current = { name: match[1].trim(), status: "", surfaceKind: "", surfaceIdentity: "", evidence: "", sliceRef: "" };
      continue;
    }
    if (!current) continue;
    const kv = line.match(/^\s*-\s*(status|surface_kind|surface_identity|evidence|slice_ref):\s*(.*)$/);
    if (!kv) continue;
    const value = kv[2].trim();
    if (kv[1] === "status") current.status = value;
    else if (kv[1] === "surface_kind") current.surfaceKind = value;
    else if (kv[1] === "surface_identity") current.surfaceIdentity = value;
    else if (kv[1] === "evidence") current.evidence = value;
    else current.sliceRef = value;
  }
  flush();
  return blocks;
}

function parseRequirementCoverage(content: string): RequirementCoverageBlock[] {
  const blocks: RequirementCoverageBlock[] = [];
  let current: RequirementCoverageBlock | undefined;
  const flush = (): void => { if (current && current.name !== "") blocks.push(current); current = undefined; };
  for (const line of content.split(/\r?\n/)) {
    const heading = line.match(/^### Requirement:\s*(.*)$/);
    if (heading) {
      flush();
      current = { name: heading[1].trim(), summary: "", prerequisites: "" };
      continue;
    }
    if (!current) continue;
    const kv = line.match(/^\s*-\s*(requirement_summary|prerequisites):\s*(.*)$/);
    if (!kv) continue;
    if (kv[1] === "requirement_summary") current.summary = kv[2].trim();
    else current.prerequisites = kv[2].trim();
  }
  flush();
  return blocks;
}

function validateBlock(block: PrerequisiteBlock, problems: string[]): void {
  const { name, status, surfaceKind, surfaceIdentity, evidence, sliceRef } = block;
  const prefix = `catalog prerequisite "${name}"`;
  if (unfilled(surfaceKind)) problems.push(`${prefix} is missing surface_kind`);
  else if (!["required_missing_user_reachable_surface", "present_user_reachable_surface", "transport_or_internal_execution_gap"].includes(surfaceKind)) {
    problems.push(`${prefix} has invalid surface_kind: "${surfaceKind}"`);
  }

  if (unfilled(status)) problems.push(`${prefix} is missing status`);
  else if (status === "unmet") problems.push(`catalog has unmet prerequisite: "${name}" — resolve by adding a slice to implementation_slices.md`);
  else if (status === "present_in_repo") {
    if (unfilled(evidence)) problems.push(`${prefix} (present_in_repo) is missing evidence`);
  } else if (status === "scheduled_in_slices") {
    if (unfilled(evidence)) problems.push(`${prefix} (scheduled_in_slices) is missing evidence`);
    if (unfilled(sliceRef) || sliceRef === "none") problems.push(`${prefix} (scheduled_in_slices) is missing slice_ref`);
  } else if (scheduledInFeature(status)) {
    if (unfilled(evidence)) problems.push(`${prefix} (${status}) is missing evidence`);
    if (!unfilled(sliceRef) && sliceRef !== "none") problems.push(`${prefix} (${status}) must use slice_ref: none`);
  } else problems.push(`${prefix} has invalid status: "${status}"`);

  if (surfaceKind === "required_missing_user_reachable_surface") {
    if (status !== "unmet" && status !== "scheduled_in_slices" && !scheduledInFeature(status)) {
      problems.push(`${prefix} uses required_missing_user_reachable_surface but status is not unmet/scheduled_in_slices/scheduled_in_feature`);
    }
    if (unfilled(surfaceIdentity) || surfaceIdentity.toLowerCase() === "none") problems.push(`${prefix} (required_missing_user_reachable_surface) is missing surface_identity`);
    else if (!looksLikeSurfaceIdentity(surfaceIdentity)) problems.push(`${prefix} has non-operator-facing surface_identity: "${surfaceIdentity}"`);
  } else if (surfaceKind === "present_user_reachable_surface") {
    if (status !== "present_in_repo") problems.push(`${prefix} uses present_user_reachable_surface but status is not present_in_repo`);
    if (!unfilled(surfaceIdentity) && surfaceIdentity.toLowerCase() !== "none") problems.push(`${prefix} (present_user_reachable_surface) must use surface_identity: none`);
  } else if (surfaceKind === "transport_or_internal_execution_gap") {
    problems.push(`${prefix} is classified as transport_or_internal_execution_gap; keep transport/internal gaps out of prerequisite entries`);
  }

  if (status === "scheduled_in_slices" && !unfilled(sliceRef) && sliceRef !== "none" && !/^[A-Za-z0-9][A-Za-z0-9_.-]*$/.test(sliceRef)) {
    problems.push(`slice_ref "${sliceRef}" in catalog prerequisite "${name}" does not match required format [A-Za-z0-9][A-Za-z0-9_.-]*`);
  }
}

function looksLikeSurfaceIdentity(value: string): boolean {
  return /(route|page|screen|shell|login|sign-in|signin|workspace|entry|portal|console|ui|view|lookup|search|dashboard|form|command|cli|job|endpoint|tool|http|post |get |put |patch |delete |deep link|deeplink)/.test(value.trim().toLowerCase());
}

function scheduledInFeature(value: string): boolean {
  return /^scheduled_in_feature\s+[^/\s]+\/[^\s]+$/.test(value.trim());
}

function unfilled(value: string | undefined): boolean {
  const trimmed = (value ?? "").trim();
  return trimmed === "" || trimmed === "[UNFILLED]";
}

function isFile(file: string): boolean {
  return existsSync(file) && statSync(file).isFile();
}

function gateFailure(problems: string[]): GateResult {
  return { exitCode: 1, passMessage: "", problems };
}

function gateError(errorMessage: string): GateResult {
  return { exitCode: 2, passMessage: "", problems: [], errorMessage };
}
