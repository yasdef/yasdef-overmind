import { existsSync, readFileSync, statSync } from "node:fs";
import path from "node:path";

import {
  displayPath,
  parseImplementationSlicesProjectClasses,
  resolveFeatureWithinWorkspace
} from "../parse/index.js";
import type { GateResult } from "../types/index.js";

const SURFACE_CLASSES = new Set(["backend", "frontend", "mobile"]);
const META_KEYS = [
  "feature_id",
  "feature_title",
  "project_type_code",
  "source_requirements_ears",
  "source_technical_requirements",
  "source_feature_contract_delta",
  "source_surface_map_artifacts",
  "analyzed_repo_classes",
  "ordering_scope",
  "traceability_scope",
  "last_updated",
  "confidence_level"
] as const;
const SLICE_FIELDS = [
  "repo",
  "status",
  "objective",
  "first_increment",
  "prerequisites",
  "preserved_operator_surface",
  "evidence"
] as const;
const HANDOFF_KEYS = [
  "ordering_intent",
  "unresolved_ordering_questions",
  "unresolved_traceability_questions"
] as const;

interface SliceBlock {
  number: number;
  heading: string;
  fields: Map<string, string>;
  bullets: string[];
}

export function validateImplementationSlices(inputPath: string, cwd = process.cwd()): GateResult {
  if (!inputPath || inputPath.trim() === "")
    return gateError("Missing target feature path argument.");
  const resolved = resolveFeatureWithinWorkspace(inputPath, cwd);
  if (!resolved.ok) return gateError(resolved.message);
  const { workspaceRoot, featureDir, relativeFeature } = resolved.value;
  const parts = relativeFeature.split(path.sep);
  if (parts.length !== 3 || parts[0] !== "projects") {
    return gateError(
      `Feature path must resolve under projects/<project-id>/<feature-folder>: ${relativeFeature}`
    );
  }

  const projectDir = path.dirname(featureDir);
  const targetPath = path.join(featureDir, "implementation_slices.md");
  const definitionPath = path.join(projectDir, "init_progress_definition.yaml");
  const requirementsPath = path.join(featureDir, "requirements_ears.md");
  const technicalPath = path.join(featureDir, "technical_requirements.md");
  const contractPath = path.join(featureDir, "feature_contract_delta.md");
  const prerequisiteGapsPath = path.join(featureDir, "prerequisite_gaps.md");

  if (!isFile(targetPath))
    return gateError(
      `Target implementation slices artifact not found: ${displayPath(targetPath, workspaceRoot)}`
    );
  const content = readFileSync(targetPath, "utf8");
  if (!/\S/.test(content))
    return gateFailure([
      `target implementation slices artifact is empty: ${displayPath(targetPath, workspaceRoot)}`
    ]);
  for (const [file, label] of [
    [requirementsPath, "Required sibling artifact not found for quality check"],
    [technicalPath, "Required sibling artifact not found for quality check"],
    [contractPath, "Required sibling artifact not found for quality check"],
    [definitionPath, "Required project definition not found for quality check"]
  ] as const) {
    if (!isFile(file)) return gateError(`${label}: ${displayPath(file, workspaceRoot)}`);
  }

  try {
    const activeClasses = new Set(
      parseImplementationSlicesProjectClasses(definitionPath).filter((item) =>
        SURFACE_CLASSES.has(item)
      )
    );
    if (activeClasses.size === 0)
      return gateError(
        `No supported repo classes found in ${displayPath(definitionPath, workspaceRoot)}`
      );
    const requiredSurfaces = isFile(prerequisiteGapsPath)
      ? extractRequiredMissingSurfaces(readFileSync(prerequisiteGapsPath, "utf8"))
      : [];
    const problems = validateImplementationSlicesContent(content, activeClasses, requiredSurfaces);
    return problems.length === 0
      ? {
          exitCode: 0,
          passMessage: "quality gate passed: implementation slices structure is complete",
          problems: []
        }
      : gateFailure(problems);
  } catch (err) {
    return gateError(err instanceof Error ? err.message : String(err));
  }
}

export function validateImplementationSlicesContent(
  content: string,
  activeClasses: Set<string>,
  requiredSurfaces: string[] = []
): string[] {
  const problems: string[] = [];
  const fail = (message: string): void => {
    problems.push(message);
  };
  const meta = new Map<string, string>();
  const handoff = new Map<string, string>();
  const slices: SliceBlock[] = [];
  const seenSections = new Set<string>();
  let section = "";
  let currentSlice: SliceBlock | undefined;
  let hasPlaceholderValue = false;

  for (const rawLine of content.split(/\r?\n/)) {
    const heading = rawLine.trim();
    if (/^##\s+/.test(rawLine)) {
      currentSlice = undefined;
      section = "";
      if (/^##\s+1\.\s+Document\s+Meta\s*$/.test(heading)) section = "1";
      else if (/^##\s+2\.\s+Slice\s+Planning\s+Guardrails\s*$/.test(heading)) section = "2";
      else if (/^##\s+3\.\s+Slice\s+Candidates\s*$/.test(heading)) section = "3";
      else if (/^##\s+4\.\s+Handoff\s+To\s+Ordered\s+Plan\s*$/.test(heading)) section = "4";
      if (section !== "") seenSections.add(section);
      continue;
    }
    const sliceHeading = rawLine.match(/^###\s+Slice\s+[0-9]+:/);
    if (section === "3" && sliceHeading) {
      currentSlice = {
        number: slices.length + 1,
        heading: normalize(rawLine),
        fields: new Map(),
        bullets: []
      };
      slices.push(currentSlice);
      if (unfilledPlaceholder(rawLine.slice(rawLine.indexOf(":") + 1))) hasPlaceholderValue = true;
      continue;
    }
    const bullet = rawLine.match(/^- \[[ xX]\]\s+(.*)$/);
    if (section === "3" && currentSlice && bullet) {
      const text = bullet[1]!.trim();
      currentSlice.bullets.push(text);
      if (unfilledPlaceholder(text)) hasPlaceholderValue = true;
      if (text === "Plan and discuss the slice" || text === "Review slice readiness") {
        fail(
          `slice ${currentSlice.number} contains forbidden lifecycle boilerplate bullet: ${text}`
        );
      }
      continue;
    }
    const kv = parseKeyValue(rawLine);
    if (!kv) continue;
    if (section === "1") {
      meta.set(kv.key, kv.value);
      if (unfilledPlaceholder(kv.value)) hasPlaceholderValue = true;
    } else if (section === "3" && currentSlice) {
      currentSlice.fields.set(kv.key, kv.value);
      if (unfilledPlaceholder(kv.value)) hasPlaceholderValue = true;
    } else if (section === "4") {
      handoff.set(kv.key, kv.value);
      if (unfilledPlaceholder(kv.value)) hasPlaceholderValue = true;
    }
  }

  if (hasPlaceholderValue) fail("artifact still contains [UNFILLED] placeholder values");
  for (const [number, label] of [
    ["1", "## 1. Document Meta"],
    ["2", "## 2. Slice Planning Guardrails"],
    ["3", "## 3. Slice Candidates"],
    ["4", "## 4. Handoff To Ordered Plan"]
  ] as const) {
    if (!seenSections.has(number)) fail(`missing section: ${label}`);
  }
  for (const key of META_KEYS)
    if (unfilled(meta.get(key))) fail(`missing or unfilled meta key: ${key}`);
  if ((meta.get("ordering_scope") ?? "").toLowerCase() !== "local_prerequisites_only")
    fail("ordering_scope must be local_prerequisites_only");
  if ((meta.get("traceability_scope") ?? "").toLowerCase() !== "slice_level_only")
    fail("traceability_scope must be slice_level_only");

  let plannedCount = 0;
  const coveredSurfaces: string[] = [];
  for (const slice of slices) {
    for (const key of SLICE_FIELDS)
      if (unfilled(slice.fields.get(key)))
        fail(`slice ${slice.number} missing or unfilled key: ${key}`);
    const repo = (slice.fields.get("repo") ?? "").toLowerCase();
    if (!activeClasses.has(repo))
      fail(`slice ${slice.number} uses repo outside active project classes: ${repo}`);
    if (!SURFACE_CLASSES.has(repo)) fail(`slice ${slice.number} has invalid repo value: ${repo}`);
    const status = (slice.fields.get("status") ?? "").toLowerCase();
    if (status !== "existing" && status !== "planned")
      fail(`slice ${slice.number} has invalid status: ${slice.fields.get("status") ?? ""}`);
    if (status === "planned") plannedCount += 1;

    const evidenceTokens = (slice.fields.get("evidence") ?? "").split(",");
    let validEvidence = 0;
    for (const rawToken of evidenceTokens) {
      const token = rawToken.trim();
      if (token === "") {
        fail(`slice ${slice.number} has empty evidence token entry`);
      } else if (
        /^gap\/TECH_REQ-([0-9]+|NFR-[0-9]+)$/.test(token) ||
        /^comp\/[a-z0-9]+(?:-[a-z0-9]+)*$/.test(token)
      ) {
        validEvidence += 1;
      } else {
        fail(`slice ${slice.number} has invalid evidence token: ${token}`);
      }
    }
    if (validEvidence === 0)
      fail(`slice ${slice.number} must include at least one valid evidence token`);
    if (
      (slice.fields.get("kind") ?? "").toLowerCase() === "coordination" &&
      unfilled(slice.fields.get("signal_ref"))
    ) {
      fail(`slice ${slice.number} has kind: coordination but signal_ref is missing or empty`);
    }
    if (slice.bullets.length < 2)
      fail(`slice ${slice.number} must include at least 2 concrete checklist bullets`);

    const preservedSurface = (slice.fields.get("preserved_operator_surface") ?? "").trim();
    if (preservedSurface.toLowerCase() !== "none") {
      if (!hasSurfaceTerms(preservedSurface))
        fail(
          `slice ${slice.number} preserved_operator_surface is not operator-facing: ${preservedSurface}`
        );
      const coverageText = [
        slice.heading,
        slice.fields.get("objective"),
        slice.fields.get("first_increment"),
        ...slice.bullets
      ]
        .join(" ")
        .toLowerCase();
      if (looksSupportingOnly(coverageText))
        fail(
          `slice ${slice.number} marks preserved_operator_surface but describes supporting-only scaffolding work`
        );
      coveredSurfaces.push(preservedSurface);
    }
  }
  if (slices.length < 1) fail("slice candidates section must contain at least one Slice block");
  if (plannedCount < 1) fail("slice candidates must contain at least one planned slice");
  for (const requiredSurface of requiredSurfaces) {
    if (!coveredSurfaces.some((candidate) => surfaceMatches(requiredSurface, candidate))) {
      fail(
        `required missing operator-facing surface is not preserved by any slice: ${requiredSurface}`
      );
    }
  }
  for (const key of HANDOFF_KEYS)
    if (unfilled(handoff.get(key))) fail(`missing or unfilled handoff key: ${key}`);
  return problems;
}

export function extractRequiredMissingSurfaces(content: string): string[] {
  const surfaces = new Set<string>();
  let inPrerequisite = false;
  let status = "";
  let surfaceKind = "";
  let surfaceIdentity = "";
  const flush = (): void => {
    if (
      inPrerequisite &&
      (status === "scheduled_in_slices" || status === "unmet") &&
      surfaceKind === "required_missing_user_reachable_surface" &&
      !unfilledOrNone(surfaceIdentity)
    ) {
      surfaces.add(surfaceIdentity.trim());
    }
    inPrerequisite = false;
    status = "";
    surfaceKind = "";
    surfaceIdentity = "";
  };
  for (const line of content.split(/\r?\n/)) {
    if (/^#### Prerequisite:/.test(line)) {
      flush();
      inPrerequisite = true;
      continue;
    }
    if (/^### Requirement:/.test(line)) {
      flush();
      continue;
    }
    if (!inPrerequisite) continue;
    const kv = parseKeyValue(line);
    if (!kv) continue;
    if (kv.key === "status") status = kv.value;
    else if (kv.key === "surface_kind") surfaceKind = kv.value;
    else if (kv.key === "surface_identity") surfaceIdentity = kv.value;
  }
  flush();
  return [...surfaces].sort();
}

export function canonicalSurface(value: string): string {
  return value
    .toLowerCase()
    .trim()
    .replace(/sign[\s-]*in|log[\s-]*in|authenticate|authentication/g, "login")
    .replace(/screen|view/g, "page")
    .replace(/path|url|entry\s*point|entry/g, "route")
    .replace(/portal|console|dashboard/g, "route")
    .replace(/container/g, "shell")
    .replace(/search|find/g, "lookup")
    .replace(/cli\s+tool|admin\s+tool|tooling\s+command|tool\s+command/g, "command")
    .replace(/cli/g, "command")
    .replace(/scheduled\s+task|cron\s+job/g, "job")
    .replace(/rest\s+endpoint|api\s+endpoint|http\s+endpoint/g, "endpoint")
    .replace(/\b(?:post|get|put|patch|delete)\s+\/\S+/g, "endpoint")
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function hasSurfaceTerms(value: string): boolean {
  return /(?:login|shell|route|lookup|page|workspace|form|command|job|endpoint|tool|link)/.test(
    canonicalSurface(value)
  );
}

export function looksSupportingOnly(value: string): boolean {
  const lower = value.toLowerCase();
  const hasSupport =
    /(?:auth|token|api|contract|schema|state|coordination|middleware|service|repository|adapter|dto|mapper|payload)/.test(
      lower
    );
  const hasSurface =
    /(?:login|sign[ -]?in|route|page|screen|shell|workspace|entry|lookup|search|dashboard|portal|console|form|command|cli|job|endpoint|tool|http|deep link|deeplink)/.test(
      lower
    );
  return hasSupport && !hasSurface;
}

export function surfaceMatches(requiredValue: string, candidateValue: string): boolean {
  const required = canonicalSurface(requiredValue);
  const candidate = canonicalSurface(candidateValue);
  if (required === "" || candidate === "") return false;
  if (required === candidate || candidate.includes(required) || required.includes(candidate))
    return true;
  const candidateTokens = new Set(candidate.split(/\s+/));
  let sharedSpecific = 0;
  let requiredSpecific = 0;
  let sharedContent = 0;
  let requiredContent = 0;
  for (const token of required.split(/\s+/)) {
    if (/^(?:login|shell|route|lookup|command|job|endpoint|tool)$/.test(token)) {
      requiredSpecific += 1;
      if (candidateTokens.has(token)) sharedSpecific += 1;
    } else if (!/^(?:page|form|link)$/.test(token) && !isWeakContentToken(token)) {
      requiredContent += 1;
      if (candidateTokens.has(token)) sharedContent += 1;
    }
  }
  if (requiredSpecific > 0)
    return requiredContent > 0 ? sharedSpecific > 0 && sharedContent > 0 : sharedSpecific > 0;
  return sharedContent >= 2;
}

function isWeakContentToken(token: string): boolean {
  return /^(?:operator|admin|user|protected|authenticated|workflow|surface|account)$/.test(token);
}

function parseKeyValue(line: string): { key: string; value: string } | undefined {
  const match = line.match(/^\s*-\s*([^:]+):(.*)$/);
  if (!match) return undefined;
  return { key: normalize(match[1]!), value: normalize(match[2]!) };
}

function normalize(value: string): string {
  const trimmed = value.trim();
  return (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
    ? trimmed.slice(1, -1).trim()
    : trimmed;
}

function unfilled(value: string | undefined): boolean {
  return value === undefined || value.trim() === "" || unfilledPlaceholder(value);
}

function unfilledPlaceholder(value: string): boolean {
  return /^\[[^\]\r\n]*\bUNFILLED\b[^\]\r\n]*\]$/i.test(normalize(value));
}

function unfilledOrNone(value: string): boolean {
  return unfilled(value) || value.trim().toLowerCase() === "none";
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
