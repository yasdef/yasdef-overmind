import { existsSync } from "node:fs";

import {
  capturedUserInputHasStoryContent,
  deriveCapturedSourceRefs,
  getScalarField,
  isUnfilled,
  normalizeLedgerLocatorPart,
  parseBulletField,
  parseSourceRefs,
  readFeatureBrSummary,
  readMissingBrData,
  readRequiredTextFile,
  resolveTaskToBrArtifacts
} from "../parse/index.js";

import type { CapturedSourceRefs } from "../parse/index.js";
import type { GateResult, MissingBrData } from "../types/index.js";

const TERMINAL_UNRESOLVED_AFTER_STOP = "none";

/**
 * Business-bearing sections scanned for ambiguity triggers. Document Meta,
 * Existing-System Context, and Linked Artifacts carry metadata, repo-scan
 * evidence, and artifact locators, so their wording is not source business text.
 */
const AMBIGUITY_SCANNED_SECTIONS = new Set([2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15]);

/**
 * Closed lexical backstop for the durable ambiguity rule. Whole-word/phrase
 * matching keeps derived words such as `faster` or `simplified` out of the
 * match; the semantic rule in the skill still covers ambiguity this list cannot
 * recognize.
 */
const AMBIGUITY_TRIGGERS = ["fast", "better", "simple", "as needed", "TBD", "etc."] as const;
const AMBIGUITY_TRIGGER_PATTERNS = AMBIGUITY_TRIGGERS.map((trigger) => ({
  trigger,
  pattern: new RegExp(
    `(?<![A-Za-z0-9_])${trigger.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}(?![A-Za-z0-9_])`,
    "i"
  )
}));

export function validateTaskToBr(inputPath: string, cwd = process.cwd()): GateResult {
  if (!inputPath || inputPath.trim() === "") {
    return gateError("Missing target artifact path.");
  }

  const artifacts = resolveTaskToBrArtifacts(inputPath, cwd);
  if (!existsSync(artifacts.targetBrPath)) {
    return gateError(`Target BR summary not found: ${artifacts.targetBrPath}`);
  }

  if (!existsSync(artifacts.userInputPath)) {
    return gateRecoverable(["user_br_input.md is missing"]);
  }

  const userInputContent = readRequiredTextFile(artifacts.userInputPath);
  if (!capturedUserInputHasStoryContent(userInputContent)) {
    return gateRecoverable([
      "user_br_input.md -> epic_or_story must contain actual source story/request content"
    ]);
  }

  const sourceRefs = deriveCapturedSourceRefs({
    userInputPath: artifacts.userInputPath,
    epicStorySourceFile: getScalarField(userInputContent, "epic_story_source_file"),
    cwd
  });
  if (sourceRefs.originalSourceUnfilled) {
    return gateRecoverable([
      "user_br_input.md -> epic_story_source_file is unfilled; rerun task-to-BR capture so the original story source is recorded"
    ]);
  }

  if (!existsSync(artifacts.missingDataPath)) {
    return gateRecoverable([
      "missing_br_data.md must exist; create it with an empty unresolved ledger when no business gaps remain"
    ]);
  }

  const summary = readFeatureBrSummary(artifacts.targetBrPath);
  const missingData = readMissingBrData(artifacts.missingDataPath);
  const problems = validateSummaryContent(summary.content, missingData, sourceRefs);

  return problems.length > 0 ? gateRecoverable(problems) : gatePassed();
}

function validateSummaryContent(
  content: string,
  missingData: ReturnType<typeof readMissingBrData>,
  sourceRefs: CapturedSourceRefs
): string[] {
  const lines = content.split(/\r?\n/);
  const problems: string[] = [];
  const ambiguityOccurrences: AmbiguityOccurrence[] = [];
  let currentH2Heading = "";
  let currentH3Heading = "";
  let inScannedSection = false;
  let inScannedSubsection = true;
  let inMeta = false;
  let inOriginalSummary = false;
  let inBusinessGoal = false;
  let inNeedsValidation = false;
  let inFunctionalRequirements = false;
  let inBusinessRules = false;
  let inOpenQuestions = false;
  let inOpenScopeBoundaries = false;
  let sawMeta = false;
  let sawOriginalSummary = false;
  let sawBusinessGoal = false;
  let sourceTypeFound = false;
  let sourceTypeValue = "";
  let lastUpdatedFound = false;
  let lastUpdatedValue = "";
  let sourceRefsFound = false;
  let sourceRefsValue = "";
  let originalSummaryFilled = false;
  let businessGoalFilled = false;
  let completeFrCount = 0;
  let completeBrCount = 0;
  let nonRisedAssumptionsNeedingValidationFound = false;
  let nonRisedOpenQuestionsFound = false;
  let nonRisedScopePointsFound = false;

  for (const line of lines) {
    const heading = line.trim();
    if (/^###\s+/.test(heading)) {
      inOriginalSummary = /^###\s+2\.1\s+Original\s+request\s+summary\s*$/.test(heading);
      inBusinessGoal = /^###\s+3\.1\s+Business\s+goal\s*$/.test(heading);
      inNeedsValidation = /^###\s+Needs\s+validation\s*$/.test(heading);
      inOpenScopeBoundaries = /^###\s+5\.3\s+Open\s+scope\s+boundaries\s*$/.test(heading);
      currentH3Heading = heading;
      inScannedSubsection = !/^###\s+2\.2\s+Raw\s+source\s+references\s*$/.test(heading);
      inMeta = false;
      if (inOriginalSummary) {
        sawOriginalSummary = true;
      }
      if (inBusinessGoal) {
        sawBusinessGoal = true;
      }
      continue;
    }

    if (/^##\s+/.test(heading)) {
      inMeta = /^##\s+1\.\s+Document\s+Meta\s*$/.test(heading);
      inFunctionalRequirements = /^##\s+6\.\s+Functional\s+Requirements\s*$/.test(heading);
      inBusinessRules = /^##\s+7\.\s+Business\s+Rules\s+and\s+Decision\s+Logic\s*$/.test(heading);
      inOpenQuestions = /^##\s+15\.\s+Open\s+Questions\s*$/.test(heading);
      inOpenScopeBoundaries = false;
      inOriginalSummary = false;
      inBusinessGoal = false;
      inNeedsValidation = false;
      currentH2Heading = heading;
      currentH3Heading = "";
      inScannedSubsection = true;
      inScannedSection = AMBIGUITY_SCANNED_SECTIONS.has(
        Number.parseInt(heading.match(/^##\s+([0-9]+)\./)?.[1] ?? "", 10)
      );
      if (inMeta) {
        sawMeta = true;
      }
      continue;
    }

    const field = parseBulletField(line);
    if (!field) {
      continue;
    }

    if (inMeta) {
      if (field.key === "source_type") {
        sourceTypeFound = true;
        sourceTypeValue = field.value;
      }
      if (field.key === "last_updated") {
        lastUpdatedFound = true;
        lastUpdatedValue = field.value;
      }
      if (field.key === "source_refs") {
        sourceRefsFound = true;
        sourceRefsValue = field.value;
      }
    }

    if (inOriginalSummary && field.key === "short summary" && !isUnfilled(field.value)) {
      originalSummaryFilled = true;
    }
    if (inBusinessGoal && field.key === "primary_business_goal" && !isUnfilled(field.value)) {
      businessGoalFilled = true;
    }
    if (
      inNeedsValidation &&
      field.key === "assumptions_needing_validation" &&
      !isUnfilled(field.value) &&
      !field.value.toLowerCase().includes("rised")
    ) {
      nonRisedAssumptionsNeedingValidationFound = true;
    }
    if (inFunctionalRequirements && /^FR-[0-9]+$/.test(field.key) && !isUnfilled(field.value)) {
      completeFrCount += 1;
    }
    if (inBusinessRules && /^BR-[0-9]+$/.test(field.key) && !isUnfilled(field.value)) {
      completeBrCount += 1;
    }
    if (
      inOpenQuestions &&
      !isUnfilled(field.value) &&
      !field.value.toLowerCase().includes("rised")
    ) {
      nonRisedOpenQuestionsFound = true;
    }
    if (
      inOpenScopeBoundaries &&
      field.key === "unclear_scope_points" &&
      !isUnfilled(field.value) &&
      !field.value.toLowerCase().includes("rised")
    ) {
      nonRisedScopePointsFound = true;
    }

    if (inScannedSection && inScannedSubsection && !isUnfilled(field.value)) {
      const triggers = findAmbiguityTriggers(field.value);
      if (triggers.length > 0) {
        const location = currentH3Heading === "" ? currentH2Heading : currentH3Heading;
        const confirmed = isConfirmedByLedger(
          missingData,
          field.key,
          currentH2Heading,
          currentH3Heading
        );
        for (const trigger of triggers) {
          ambiguityOccurrences.push({
            trigger,
            field: `${location} -> ${field.key}`,
            confirmed
          });
        }
      }
    }
  }

  if (!sawMeta) {
    problems.push("section ## 1. Document Meta is missing");
  } else {
    if (!sourceTypeFound || isUnfilled(sourceTypeValue)) {
      problems.push("## 1. Document Meta -> source_type is unfilled");
    } else {
      const normalizedSourceType = sourceTypeValue.toLowerCase().replace(/[-_]+/g, " ");
      if (!/user\s*input/.test(normalizedSourceType)) {
        problems.push("## 1. Document Meta -> source_type must include User input");
      }
    }

    if (!lastUpdatedFound || isUnfilled(lastUpdatedValue)) {
      problems.push("## 1. Document Meta -> last_updated is unfilled");
    } else if (!/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(lastUpdatedValue)) {
      problems.push("## 1. Document Meta -> last_updated must be YYYY-MM-DD");
    }

    // Only populated elements can satisfy the binding: the template ships
    // `source_refs: [UNFILLED]`, so a repair that appends around the placeholder
    // instead of replacing it must not count as a complete source record.
    const declaredRefs = sourceRefsFound ? parseSourceRefs(sourceRefsValue) : [];
    const populatedRefs = declaredRefs.filter((element) => !isUnfilled(element));
    if (populatedRefs.length === 0) {
      problems.push("## 1. Document Meta -> source_refs is unfilled");
    } else {
      for (const required of sourceRefs.required) {
        if (!populatedRefs.includes(required)) {
          problems.push(
            `## 1. Document Meta -> source_refs must include the captured source reference: ${required}`
          );
        }
      }
      if (populatedRefs.length < declaredRefs.length) {
        problems.push(
          "## 1. Document Meta -> source_refs must not keep [UNFILLED] placeholder elements alongside real source references"
        );
      }
    }
  }

  if (!sawOriginalSummary || !originalSummaryFilled) {
    problems.push("### 2.1 Original request summary -> short summary is unfilled");
  }
  if (!sawBusinessGoal || !businessGoalFilled) {
    problems.push("### 3.1 Business goal -> primary_business_goal is unfilled");
  }
  if (completeFrCount < 1) {
    problems.push(
      "## 6. Functional Requirements -> at least one meaningful one-line FR item (`- FR-N: ...`) is required"
    );
  }
  if (completeBrCount < 1) {
    problems.push(
      "## 7. Business Rules and Decision Logic -> at least one meaningful one-line BR item (`- BR-N: ...`) is required"
    );
  }
  if (nonRisedOpenQuestionsFound) {
    problems.push(
      "## 15. Open Questions -> unresolved items must be moved to missing_br_data.md as rised_item_N with rised=false"
    );
  }
  if (nonRisedAssumptionsNeedingValidationFound) {
    problems.push(
      "### Needs validation -> unresolved assumptions_needing_validation must be moved to missing_br_data.md as rised_item_N with rised=false"
    );
  }
  if (nonRisedScopePointsFound) {
    problems.push(
      "### 5.3 Open scope boundaries -> unresolved unclear_scope_points must be moved to missing_br_data.md as rised_item_N with rised=false"
    );
  }
  problems.push(...describeAmbiguity(ambiguityOccurrences));

  // The ledger is terminal when it raised nothing, or when every raised item is
  // answered. An item without a valid rised state is reported separately and
  // never counts as terminal. `gate_result` is historical evidence of an earlier
  // round and takes no part in this check.
  const isTerminalLedger =
    missingData.risedItems.length === 0 ||
    missingData.risedItems.every((item) => item.risedState === "true");

  if (missingData.risedItems.length > 0) {
    if (missingData.risedItems.some((item) => item.risedState === "missing")) {
      problems.push(
        "missing_br_data.md -> every unresolved ledger item must include rised=false or rised=true"
      );
    }
    if (
      missingData.risedItems.some((item) => item.risedState === "true") &&
      !missingData.hasFilledAnswer
    ) {
      problems.push(
        "missing_br_data.md -> unresolved rised items exist but ## 6. Latest User Answers -> answers is [UNFILLED]"
      );
    }
    // A pending ledger only needs a filled summary; a terminal one is covered by
    // the stricter literal check below, so it must not report both diagnostics.
    if (!missingData.hasFilledUnresolvedAfterStop && !isTerminalLedger) {
      problems.push(
        "missing_br_data.md -> unresolved rised items exist but ## 7. Loop Decision -> unresolved_after_stop is [UNFILLED]"
      );
    }
  }

  // Both terminal states must read as the same literal token so a completed
  // ledger cannot keep a stale pending summary.
  if (isTerminalLedger && missingData.unresolvedAfterStop !== TERMINAL_UNRESOLVED_AFTER_STOP) {
    problems.push(
      "missing_br_data.md -> ## 7. Loop Decision -> unresolved_after_stop must be exactly `none` when the unresolved ledger is empty or every rised_item_N is rised=true"
    );
  }

  return problems;
}

interface AmbiguityOccurrence {
  trigger: string;
  /** `<section or subsection heading> -> <field key>`, as reported to the model. */
  field: string;
  confirmed: boolean;
}

/**
 * Reporting groups by trigger; confirmation stays per field. A BR routinely
 * restates one business fact as a constraint, a functional requirement, and a
 * business rule, so per-field reporting turns one open question into several
 * near-duplicate diagnostics. Evidence still has to name the field it clears:
 * one answered item may list every field its answer covers, and fields it does
 * not name remain reported, because the same trigger word can carry unrelated
 * questions in different fields.
 */
function describeAmbiguity(occurrences: AmbiguityOccurrence[]): string[] {
  const byTrigger = new Map<string, AmbiguityOccurrence[]>();
  for (const occurrence of occurrences) {
    if (occurrence.confirmed) {
      continue;
    }
    const group = byTrigger.get(occurrence.trigger);
    if (group) {
      group.push(occurrence);
    } else {
      byTrigger.set(occurrence.trigger, [occurrence]);
    }
  }

  const problems: string[] = [];
  for (const [trigger, group] of byTrigger) {
    const fields = group.map((occurrence) => occurrence.field).join(", ");
    const target = group.length === 1 ? "that field" : "those fields";
    problems.push(
      `ambiguity trigger \`${trigger}\` remains in ${fields}; move the unresolved wording to missing_br_data.md as rised_item_N with rised=false and set ${target} to [UNFILLED], or record an answered rised=true item naming ${target} to confirm the wording`
    );
  }
  return problems;
}

/**
 * Every trigger the value carries, not just the first. A field reading
 * `fast and simple response as needed` holds three separate questions, and
 * confirmation is per field: reporting one trigger would let the operator
 * confirm wording whose other ambiguities were never shown to them.
 */
function findAmbiguityTriggers(value: string): string[] {
  return AMBIGUITY_TRIGGER_PATTERNS.filter(({ pattern }) => pattern.test(value)).map(
    ({ trigger }) => trigger
  );
}

/**
 * An answered ledger item is the durable evidence that the operator confirmed the
 * original wording of the fields it names. The locator section may name either
 * the enclosing `##` section or the `###` subsection that holds the field, so
 * both are accepted.
 */
function isConfirmedByLedger(
  missingData: MissingBrData,
  fieldKey: string,
  h2Heading: string,
  h3Heading: string
): boolean {
  const field = normalizeLedgerLocatorPart(fieldKey);
  const sections = [normalizeLedgerLocatorPart(h2Heading), normalizeLedgerLocatorPart(h3Heading)];
  return missingData.risedItems.some(
    (item) =>
      item.risedState === "true" &&
      item.sources.some((source) => source.field === field && sections.includes(source.section))
  );
}

function gatePassed(): GateResult {
  return {
    exitCode: 0,
    passMessage: "business-context gate passed",
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
