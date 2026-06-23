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

const REQUIRED_SECTIONS = [
  "## 1. Document Meta",
  "## 2. Review Guidance",
  "## 3. Findings Ledger"
] as const;

const REQUIRED_META_KEYS = [
  "feature_id",
  "feature_title",
  "source_feature_br_summary",
  "source_requirements_ears",
  "review_status",
  "last_updated"
] as const;

const REQUIRED_FINDING_FIELDS = [
  "severity",
  "state",
  "source_br_summary_reference",
  "related_requirement_targets",
  "gap_summary",
  "recommendation",
  "suggested_ears_change",
  "user_prompt",
  "user_response",
  "resolution_notes"
] as const;

type Section = "1" | "2" | "3" | "";

interface FindingBlock {
  fields: Map<string, string>;
}

export function validateEarsReview(inputPath: string, cwd = process.cwd()): GateResult {
  if (!inputPath || inputPath.trim() === "") {
    return gateError("Missing target requirements ears review path argument.");
  }

  try {
    const targetPath = resolveEarsReviewPath(inputPath, cwd);
    if (!existsSync(targetPath)) {
      return gateError(`Target requirements ears review artifact not found: ${targetPath}`);
    }
    if (statSync(targetPath).isDirectory()) {
      return gateError(`Target requirements ears review artifact is a directory: ${targetPath}`);
    }

    const content = readRequiredTextFile(targetPath);
    if (!/[^ \t\r\n]/.test(content)) {
      return gateRecoverable([`quality gate failed: target requirements ears review artifact is empty: ${targetPath}`]);
    }

    const problems = validateEarsReviewContent(content);
    return problems.length > 0 ? gateRecoverable(problems) : gatePassed();
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return gateError(message);
  }
}

export function validateEarsReviewContent(content: string): string[] {
  const problems: string[] = [];
  const seenSections = new Set<string>();
  const meta = new Map<string, string>();
  const findings: FindingBlock[] = [];
  let section: Section = "";
  let sawNoFindings = false;
  let noFindings = "false";

  function failQuality(message: string): void {
    problems.push(`quality gate failed: ${message}`);
  }

  if (/\[UNFILLED\]/i.test(content)) {
    failQuality("artifact still contains [UNFILLED] placeholders");
  }

  for (const line of content.split(/\r?\n/)) {
    const heading = line.trim();
    if (/^##\s+/.test(heading)) {
      section = "";
      if (/^##\s+1\.\s+Document\s+Meta\s*$/.test(heading)) {
        section = "1";
        seenSections.add(REQUIRED_SECTIONS[0]);
      } else if (/^##\s+2\.\s+Review\s+Guidance\s*$/.test(heading)) {
        section = "2";
        seenSections.add(REQUIRED_SECTIONS[1]);
      } else if (/^##\s+3\.\s+Findings\s+Ledger\s*$/.test(heading)) {
        section = "3";
        seenSections.add(REQUIRED_SECTIONS[2]);
      }
      continue;
    }

    if (/^###\s+Finding\s+[0-9]+\s+[-:]/.test(heading)) {
      if (section === "3") {
        findings.push({ fields: new Map<string, string>() });
      }
      continue;
    }

    if (section === "") {
      continue;
    }

    const field = parseBulletField(line);
    if (!field) {
      continue;
    }

    const key = normalizeValue(field.key);
    if (section === "1") {
      meta.set(key, field.value);
    } else if (section === "3") {
      const currentFinding = findings.at(-1);
      if (currentFinding) {
        currentFinding.fields.set(key, field.value);
      } else if (key === "no_findings") {
        noFindings = field.value.toLowerCase();
        sawNoFindings = true;
      }
    }
  }

  for (const requiredSection of REQUIRED_SECTIONS) {
    if (!seenSections.has(requiredSection)) {
      failQuality(`missing section: ${requiredSection}`);
    }
  }

  for (const key of REQUIRED_META_KEYS) {
    if (isUnfilled(meta.get(key))) {
      failQuality(`missing or unfilled meta key: ${key}`);
    }
  }

  const reviewStatus = (meta.get("review_status") ?? "").toLowerCase();
  if (reviewStatus !== "in_progress" && reviewStatus !== "complete") {
    failQuality("review_status must be in_progress or complete");
  }

  if (findings.length === 0) {
    if (!sawNoFindings || noFindings !== "true") {
      failQuality("findings ledger must declare - no_findings: true when no Finding blocks exist");
    }
    if (reviewStatus !== "complete") {
      failQuality("review_status must be complete when no_findings is true");
    }
  }

  if (findings.length > 0 && noFindings === "true") {
    failQuality("no_findings must not be true when Finding blocks are present");
  }

  let escalatedCount = 0;
  findings.forEach((finding, index) => {
    const findingNumber = index + 1;
    for (const key of REQUIRED_FINDING_FIELDS) {
      if (isUnfilled(finding.fields.get(key))) {
        failQuality(`finding block ${findingNumber} missing or unfilled key: ${key}`);
      }
    }

    const severity = normalizeValue(finding.fields.get("severity") ?? "");
    if (severity !== "High" && severity !== "Medium" && severity !== "Low") {
      failQuality(`finding block ${findingNumber} has invalid severity: ${severity}`);
    }

    const rawState = finding.fields.get("state") ?? "";
    const state = normalizeState(rawState);
    if (state !== "escalated" && state !== "added to ears" && state !== "rejected" && state !== "postponed") {
      failQuality(`finding block ${findingNumber} has invalid state: ${rawState}`);
    }
    if (state === "escalated") {
      escalatedCount += 1;
    }
  });

  if (reviewStatus === "complete" && escalatedCount > 0) {
    failQuality("review_status is complete but escalated findings remain");
  }

  if (reviewStatus === "in_progress" && findings.length > 0 && escalatedCount === 0) {
    failQuality("review_status is in_progress but no escalated findings remain");
  }

  return problems;
}

function resolveEarsReviewPath(inputPath: string, cwd: string): string {
  const resolved = resolveInputPath(inputPath, cwd);
  if (existsSync(resolved) && statSync(resolved).isFile()) {
    return resolved;
  }
  return path.join(resolved, "requirements_ears_review.md");
}

function normalizeState(value: string): string {
  return normalizeValue(value).toLowerCase().replace(/\s+/g, " ");
}

function gatePassed(): GateResult {
  return {
    exitCode: 0,
    passMessage: "quality gate passed: requirements ears review structure is complete",
    problems: []
  };
}

function gateRecoverable(problems: string[]): GateResult {
  return {
    exitCode: 1,
    passMessage: "",
    problems
  };
}

function gateError(message: string): GateResult {
  return {
    exitCode: 2,
    passMessage: "",
    problems: [],
    errorMessage: message
  };
}
