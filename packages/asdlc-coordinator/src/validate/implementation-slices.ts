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
  "evidence"
] as const;
const HANDOFF_KEYS = [
  "ordering_intent",
  "unresolved_ordering_questions",
  "unresolved_traceability_questions"
] as const;

interface SliceBlock {
  number: number;
  declaredNumber: number;
  heading: string;
  fields: Map<string, string>;
  bullets: string[];
}

/**
 * A required missing operator-facing surface as recorded in `prerequisite_gaps.md`,
 * carrying the slice link that decides its coverage (CRP-171 D1).
 */
export interface RequiredSurface {
  surface: string;
  sliceRef: string;
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
  requiredSurfaces: RequiredSurface[] = []
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
    const sliceHeading = rawLine.match(/^###\s+Slice\s+([0-9]+):/);
    if (section === "3" && sliceHeading) {
      currentSlice = {
        number: slices.length + 1,
        declaredNumber: Number(sliceHeading[1]),
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
  const slicesByDeclaredNumber = new Map<number, SliceBlock>();
  const duplicateNumbers = new Set<number>();
  for (const slice of slices) {
    if (slicesByDeclaredNumber.has(slice.declaredNumber))
      duplicateNumbers.add(slice.declaredNumber);
    else slicesByDeclaredNumber.set(slice.declaredNumber, slice);
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
  }
  if (slices.length < 1) fail("slice candidates section must contain at least one Slice block");
  if (plannedCount < 1) fail("slice candidates must contain at least one planned slice");
  for (const number of [...duplicateNumbers].sort((left, right) => left - right))
    fail(`slice candidates declare duplicate slice number: ${number}`);
  for (const { surface, sliceRef } of requiredSurfaces) {
    const reference = sliceRef.trim();
    const parsed = reference.match(/^slice-([0-9]+)$/i);
    if (!parsed) {
      fail(
        `required missing operator-facing surface has an unusable slice_ref: ${surface} -> ${reference === "" ? "(empty)" : reference}`
      );
      continue;
    }
    // A duplicated number makes the link ambiguous; the duplicate itself is already
    // reported, so no coverage conclusion is drawn from an arbitrary matching slice.
    if (duplicateNumbers.has(Number(parsed[1]))) continue;
    const linked = slicesByDeclaredNumber.get(Number(parsed[1]));
    if (!linked) {
      fail(
        `required missing operator-facing surface is linked to a slice that is not declared: ${surface} -> ${reference}`
      );
      continue;
    }
  }
  for (const key of HANDOFF_KEYS)
    if (unfilled(handoff.get(key))) fail(`missing or unfilled handoff key: ${key}`);
  return problems;
}

export function extractRequiredMissingSurfaces(content: string): RequiredSurface[] {
  const surfaces = new Map<string, RequiredSurface>();
  let inPrerequisite = false;
  let status = "";
  let surfaceKind = "";
  let surfaceIdentity = "";
  let sliceRef = "";
  const flush = (): void => {
    if (
      inPrerequisite &&
      status === "scheduled_in_slices" &&
      surfaceKind === "required_missing_user_reachable_surface" &&
      !unfilledOrNone(surfaceIdentity)
    ) {
      const surface = surfaceIdentity.trim();
      const reference = unfilledPlaceholder(sliceRef) ? "" : sliceRef.trim();
      surfaces.set(`${surface} ${reference}`, { surface, sliceRef: reference });
    }
    inPrerequisite = false;
    status = "";
    surfaceKind = "";
    surfaceIdentity = "";
    sliceRef = "";
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
    else if (kv.key === "slice_ref") sliceRef = kv.value;
  }
  flush();
  return [...surfaces.values()].sort((left, right) => left.surface.localeCompare(right.surface));
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
