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
  "## 2. Delta Summary",
  "## 3. Contract Delta Items",
  "## 4. Track Handoff Signals"
] as const;
const REQUIRED_META_KEYS = [
  "feature_id",
  "feature_title",
  "project_type_code",
  "source_requirements_ears",
  "source_common_contract_definition",
  "delta_needed",
  "last_updated"
] as const;
const REQUIRED_DELTA_FIELDS = [
  "delta_kind",
  "related_baseline_contract",
  "change_scope",
  "compatibility_impact",
  "verification_expectation"
] as const;

type Section = "1" | "2" | "3" | "4" | "";

export function validateContractDelta(inputPath: string, cwd = process.cwd()): GateResult {
  if (!inputPath || inputPath.trim() === "") {
    return gateError("Missing target feature contract delta path argument.");
  }

  try {
    const targetPath = resolveContractDeltaPath(inputPath, cwd);
    if (!existsSync(targetPath)) {
      return gateError(`Target feature contract delta artifact not found: ${targetPath}`);
    }
    if (statSync(targetPath).isDirectory()) {
      return gateError(`Target feature contract delta artifact is a directory: ${targetPath}`);
    }

    const content = readRequiredTextFile(targetPath);
    if (!/[^ \t\r\n]/.test(content)) {
      return gateRecoverable([`quality gate failed: target feature contract delta artifact is empty: ${targetPath}`]);
    }

    const problems = validateContractDeltaContent(content);
    return problems.length > 0 ? gateRecoverable(problems) : gatePassed();
  } catch (err) {
    return gateError(err instanceof Error ? err.message : String(err));
  }
}

export function validateContractDeltaContent(content: string): string[] {
  const problems: string[] = [];
  const seenSections = new Set<string>();
  const meta = new Map<string, string>();
  const handoff = new Map<string, string>();
  const deltas: Array<Map<string, string>> = [];
  let section: Section = "";
  let noContractDeltaRequired = "";

  const failQuality = (message: string): void => {
    problems.push(`quality gate failed: ${message}`);
  };

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
      } else if (/^##\s+2\.\s+Delta\s+Summary\s*$/.test(heading)) {
        section = "2";
        seenSections.add(REQUIRED_SECTIONS[1]);
      } else if (/^##\s+3\.\s+Contract\s+Delta\s+Items\s*$/.test(heading)) {
        section = "3";
        seenSections.add(REQUIRED_SECTIONS[2]);
      } else if (/^##\s+4\.\s+Track\s+Handoff\s+Signals\s*$/.test(heading)) {
        section = "4";
        seenSections.add(REQUIRED_SECTIONS[3]);
      }
      continue;
    }

    if (/^###\s+Delta\s+[0-9]+:\s*/.test(heading)) {
      if (section === "3") {
        deltas.push(new Map<string, string>());
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
    } else if (section === "4") {
      handoff.set(key, field.value);
    } else if (section === "3") {
      if (key === "no_contract_delta_required") {
        noContractDeltaRequired = normalizeValue(field.value).toLowerCase();
      } else {
        deltas.at(-1)?.set(key, field.value);
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

  const deltaNeeded = normalizeValue(meta.get("delta_needed") ?? "").toLowerCase();
  if (deltaNeeded !== "true" && deltaNeeded !== "false") {
    failQuality("delta_needed must be true or false");
  }
  if (deltaNeeded === "true") {
    if (deltas.length < 1) {
      failQuality("delta_needed is true but no Delta blocks were found in section 3");
    }
    if (noContractDeltaRequired === "true") {
      failQuality("no_contract_delta_required must not be true when delta_needed is true");
    }
    deltas.forEach((delta, index) => {
      for (const key of REQUIRED_DELTA_FIELDS) {
        if (isUnfilled(delta.get(key))) {
          failQuality(`delta block ${index + 1} missing or unfilled key: ${key}`);
        }
      }
    });
  }
  if (deltaNeeded === "false") {
    if (noContractDeltaRequired !== "true") {
      failQuality("delta_needed is false but section 3 does not declare - no_contract_delta_required: true");
    }
    if (deltas.length > 0) {
      failQuality("delta_needed is false but Delta blocks are still present");
    }
  }

  for (const key of ["backend_handoff", "frontend_mobile_handoff"] as const) {
    if (isUnfilled(handoff.get(key))) {
      failQuality(`missing or unfilled handoff key: ${key}`);
    }
  }
  return problems;
}

function resolveContractDeltaPath(inputPath: string, cwd: string): string {
  const resolved = resolveInputPath(inputPath, cwd);
  if (existsSync(resolved) && statSync(resolved).isFile()) {
    return resolved;
  }
  return path.join(resolved, "feature_contract_delta.md");
}

function gatePassed(): GateResult {
  return { exitCode: 0, passMessage: "quality gate passed: feature contract delta structure is complete", problems: [] };
}

function gateRecoverable(problems: string[]): GateResult {
  return { exitCode: 1, passMessage: "", problems };
}

function gateError(message: string): GateResult {
  return { exitCode: 2, passMessage: "", problems: [], errorMessage: message };
}
