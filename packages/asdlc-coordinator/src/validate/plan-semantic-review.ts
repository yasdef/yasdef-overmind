import { existsSync, readFileSync, statSync } from "node:fs";
import path from "node:path";

import { displayPath, resolveFeatureWithinWorkspace } from "../parse/index.js";
import type { GateResult } from "../types/index.js";

const REQUIRED_META = [
  "feature_id",
  "feature_title",
  "source_implementation_plan",
  "source_project_definition",
  "source_requirements_ears",
  "source_technical_requirements",
  "review_status",
  "last_updated"
];
const REQUIRED_FINDING_FIELDS = [
  "severity",
  "finding_type",
  "state",
  "target_steps",
  "related_requirements",
  "related_evidence",
  "summary",
  "rationale",
  "recommendation",
  "user_selection",
  "plan_patch_summary",
  "resolution_notes"
];
const FINDING_TYPES = new Set([
  "step_scope_overlap",
  "technical_gap_mix",
  "dependency_ordering",
  "requirement_grouping",
  "delivered_surface_consumption_unclear",
  "repo_scaffold_readiness_unclear"
]);
const STATES = new Set(["added", "applied", "rejected", "postponed"]);
const TERMINAL_STATES = new Set(["applied", "rejected", "postponed"]);

export function validatePlanSemanticReview(inputPath: string, cwd = process.cwd()): GateResult {
  if (!inputPath || inputPath.trim() === "")
    return gateError("Missing target feature path argument.");
  const resolved = resolveFeatureWithinWorkspace(inputPath, cwd);
  if (!resolved.ok) return gateError(resolved.message);
  const { workspaceRoot, featureDir, relativeFeature } = resolved.value;
  const parts = relativeFeature.split(path.sep);
  if (parts.length !== 3 || parts[0] !== "projects" || !parts[1] || !parts[2]) {
    return gateError(
      `Feature path must resolve under projects/<project-id>/<feature-folder>: ${relativeFeature}`
    );
  }
  const targetPath = path.join(featureDir, "implementation_plan_semantic_review.md");
  if (!isFile(targetPath))
    return gateError(
      `Target implementation plan semantic review artifact not found: ${displayPath(targetPath, workspaceRoot)}`
    );
  try {
    const content = readFileSync(targetPath, "utf8");
    if (!/\S/.test(content))
      return gateFailure([
        `target implementation plan semantic review artifact is empty: ${displayPath(targetPath, workspaceRoot)}`
      ]);
    const problems = validatePlanSemanticReviewContent(content);
    return problems.length === 0
      ? {
          exitCode: 0,
          passMessage:
            "quality gate passed: implementation plan semantic review structure is complete enough",
          problems: []
        }
      : gateFailure(problems);
  } catch (err) {
    return gateError(err instanceof Error ? err.message : String(err));
  }
}

export function validatePlanSemanticReviewContent(content: string): string[] {
  const problems: string[] = [];
  const meta = new Map<string, string>();
  const findings: Array<Map<string, string>> = [];
  let section = "";
  let sawSection1 = false;
  let sawSection2 = false;
  let sawSection3 = false;
  let sawNoFindings = false;
  let noFindings = "false";

  for (const rawLine of content.split(/\r?\n/)) {
    if (/^##\s+/.test(rawLine)) {
      const heading = trim(rawLine);
      section = "";
      if (/^##\s+1\.\s+Document\s+Meta\s*$/.test(heading)) {
        section = "1";
        sawSection1 = true;
      } else if (/^##\s+2\.\s+Review\s+Guidance\s*$/.test(heading)) {
        section = "2";
        sawSection2 = true;
      } else if (/^##\s+3\.\s+Findings\s+Ledger\s*$/.test(heading)) {
        section = "3";
        sawSection3 = true;
      }
      continue;
    }
    if (/^###\s+Finding\s+\d+\s+[-:]/.test(rawLine)) {
      if (section === "3") findings.push(new Map());
      continue;
    }
    if (!section) continue;
    const parsed = parseKv(rawLine);
    if (!parsed) continue;
    if (section === "1") meta.set(parsed.key, parsed.value);
    else if (section === "3") {
      if (findings.length > 0) findings[findings.length - 1]!.set(parsed.key, parsed.value);
      else if (parsed.key === "no_findings") {
        noFindings = normalizeBool(parsed.value);
        sawNoFindings = true;
      }
    }
  }

  if (/\[UNFILLED\]/i.test(content))
    problems.push("artifact still contains [UNFILLED] placeholders");
  if (!sawSection1) problems.push("missing section: ## 1. Document Meta");
  if (!sawSection2) problems.push("missing section: ## 2. Review Guidance");
  if (!sawSection3) problems.push("missing section: ## 3. Findings Ledger");
  for (const key of REQUIRED_META)
    if (!meta.has(key) || isUnfilled(meta.get(key) ?? ""))
      problems.push(`missing or unfilled meta key: ${key}`);
  const reviewStatus = (meta.get("review_status") ?? "").toLowerCase();
  if (!new Set(["in_progress", "complete"]).has(reviewStatus))
    problems.push("review_status must be in_progress or complete");
  if (findings.length === 0) {
    if (!sawNoFindings || noFindings !== "true")
      problems.push(
        "findings ledger must declare - no_findings: true when no Finding blocks exist"
      );
    if (reviewStatus !== "complete")
      problems.push("review_status must be complete when no_findings is true");
  }
  if (findings.length > 0 && noFindings === "true")
    problems.push("no_findings must not be true when Finding blocks are present");

  let terminalCount = 0;
  findings.forEach((finding, index) => {
    const number = index + 1;
    for (const key of REQUIRED_FINDING_FIELDS)
      if (!finding.has(key) || isUnfilled(finding.get(key) ?? ""))
        problems.push(`finding block ${number} missing or unfilled key: ${key}`);
    const severity = normalize(finding.get("severity") ?? "");
    if (!new Set(["High", "Medium", "Low"]).has(severity))
      problems.push(`finding block ${number} has invalid severity: ${severity}`);
    const findingType = normalize(finding.get("finding_type") ?? "");
    if (!FINDING_TYPES.has(findingType))
      problems.push(`finding block ${number} has invalid finding_type: ${findingType}`);
    const state = normalizeState(finding.get("state") ?? "");
    if (!STATES.has(state))
      problems.push(`finding block ${number} has invalid state: ${finding.get("state") ?? ""}`);
    if (state !== "added") terminalCount++;
    if (
      ["delivered_surface_consumption_unclear", "repo_scaffold_readiness_unclear"].includes(
        findingType
      ) &&
      TERMINAL_STATES.has(state) &&
      isUnfilled(finding.get("resolution_notes") ?? "")
    ) {
      problems.push(
        `finding block ${number} (${findingType}) has terminal state with empty resolution_notes`
      );
    }
    if (
      findingType === "delivered_surface_consumption_unclear" &&
      !/(REQ|NFR)-\d+/.test(finding.get("related_requirements") ?? "")
    ) {
      problems.push(
        `finding block ${number} (delivered_surface_consumption_unclear) must reference at least one REQ-* or NFR-* id in related_requirements`
      );
    }
  });
  if (reviewStatus === "complete" && findings.length > 0 && terminalCount !== findings.length)
    problems.push("review_status is complete but non-terminal findings remain");
  return problems;
}

function parseKv(line: string): { key: string; value: string } | undefined {
  const withoutList = line.replace(/^\s*-\s*/, "");
  const colon = withoutList.indexOf(":");
  if (colon < 0) return undefined;
  return {
    key: normalize(withoutList.slice(0, colon)),
    value: normalize(withoutList.slice(colon + 1))
  };
}
function trim(value: string): string {
  return value.trim();
}
function normalize(value: string): string {
  let result = trim(value);
  if (
    (result.startsWith('"') && result.endsWith('"')) ||
    (result.startsWith("'") && result.endsWith("'"))
  )
    result = result.slice(1, -1);
  return trim(result);
}
function isUnfilled(value: string): boolean {
  const normalized = normalize(value);
  return (
    normalized === "" ||
    normalized.toUpperCase() === "[UNFILLED]" ||
    normalized === "<decision and final outcome>"
  );
}
function normalizeState(value: string): string {
  return normalize(value).toLowerCase().replace(/\s+/g, " ");
}
function normalizeBool(value: string): string {
  return normalize(value).toLowerCase().replace(/\s+/g, "");
}
function isFile(file: string): boolean {
  return existsSync(file) && statSync(file).isFile();
}
function gateFailure(problems: string[]): GateResult {
  return {
    exitCode: 1,
    passMessage: "",
    problems: problems.map((problem) => `quality gate failed: ${problem}`)
  };
}
function gateError(message: string): GateResult {
  return { exitCode: 2, passMessage: "", problems: [], errorMessage: message };
}
