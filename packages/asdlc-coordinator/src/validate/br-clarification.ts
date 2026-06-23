import { existsSync } from "node:fs";

import {
  findUnresolvedRisedItems,
  readRequiredTextFile,
  resolveTaskToBrArtifacts
} from "../parse/index.js";
import { validateTaskToBr } from "./task-to-br.js";

import type { GateResult } from "../types/index.js";

export interface BrClarificationValidationOptions {
  onProgress?: (line: string) => void;
}

export function validateBrClarification(
  inputPath: string,
  cwd = process.cwd(),
  options: BrClarificationValidationOptions = {}
): GateResult {
  try {
    const baseResult = validateTaskToBr(inputPath, cwd);
    if (baseResult.exitCode !== 0) {
      options.onProgress?.("rule 1: task-to-br base business-context validation ... FAIL");
      return baseResult;
    }
    options.onProgress?.("rule 1: task-to-br base business-context validation ... PASS");

    const artifacts = resolveTaskToBrArtifacts(inputPath, cwd);
    if (!existsSync(artifacts.missingDataPath)) {
      options.onProgress?.("rule 2: missing_br_data unresolved BR clarification ledger ... FAIL");
      return gateError(`Missing data artifact not found: ${artifacts.missingDataPath}`);
    }

    const missingDataContent = readRequiredTextFile(artifacts.missingDataPath);
    const unresolved = findUnresolvedRisedItems(missingDataContent);
    if (unresolved.length > 0) {
      options.onProgress?.("rule 2: missing_br_data unresolved BR clarification ledger ... FAIL");
      return gateRecoverable([
        "missing_br_data.md -> unresolved user BR clarification items remain; continue until every rised_item_N is rised=true"
      ]);
    }
    options.onProgress?.("rule 2: missing_br_data unresolved BR clarification ledger ... PASS");
    options.onProgress?.("rule 3: BR clarification is complete for EARS readiness ... PASS");

    return gatePassed();
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return gateError(message);
  }
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
