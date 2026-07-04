import { existsSync } from "node:fs";

import {
  capturedUserInputHasStoryContent,
  isUnfilled,
  parseBulletField,
  readFeatureBrSummary,
  readMissingBrData,
  readRequiredTextFile,
  resolveTaskToBrArtifacts
} from "../parse/index.js";

import type { GateResult } from "../types/index.js";

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

  if (!existsSync(artifacts.missingDataPath)) {
    return gateRecoverable([
      "missing_br_data.md must exist; create it with an empty unresolved ledger when no business gaps remain"
    ]);
  }

  const summary = readFeatureBrSummary(artifacts.targetBrPath);
  const missingData = readMissingBrData(artifacts.missingDataPath);
  const problems = validateSummaryContent(summary.content, missingData);

  return problems.length > 0 ? gateRecoverable(problems) : gatePassed();
}

function validateSummaryContent(
  content: string,
  missingData: ReturnType<typeof readMissingBrData>
): string[] {
  const lines = content.split(/\r?\n/);
  const problems: string[] = [];
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
    if (!missingData.hasFilledUnresolvedAfterStop) {
      problems.push(
        "missing_br_data.md -> unresolved rised items exist but ## 7. Loop Decision -> unresolved_after_stop is [UNFILLED]"
      );
    }
  }

  return problems;
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
