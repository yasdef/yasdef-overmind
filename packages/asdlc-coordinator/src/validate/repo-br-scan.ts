import { existsSync, readFileSync, statSync } from "node:fs";
import path from "node:path";

import { isUnfilled, parseBulletField } from "../parse/index.js";
import type { GateResult } from "../types/index.js";

function resolveTargetPath(inputPath: string, cwd: string): string {
  const resolved = path.isAbsolute(inputPath)
    ? path.normalize(inputPath)
    : path.resolve(cwd, inputPath);
  if (existsSync(resolved) && statSync(resolved).isDirectory()) {
    return path.join(resolved, "feature_br_summary.md");
  }
  return resolved;
}

export function validateRepoBrScan(inputPath: string, cwd = process.cwd()): GateResult {
  if (!inputPath || inputPath.trim() === "") {
    return gateError("Missing target artifact path.");
  }

  const targetPath = resolveTargetPath(inputPath, cwd);
  if (!existsSync(targetPath)) {
    return gateError(`Target BR summary not found: ${targetPath}`);
  }

  const content = readFileSync(targetPath, "utf8");
  const lines = content.split(/\r?\n/);

  let inMeta = false;
  let inExistingContext = false;
  let sawMeta = false;
  let sawExisting = false;
  let sourceTypeFound = false;
  let sourceTypeValue = "";
  let lastUpdatedFound = false;
  let lastUpdatedValue = "";
  const existingEntries: Array<{ key: string; value: string }> = [];

  for (const line of lines) {
    const heading = line.trim();

    if (/^##\s+/.test(heading)) {
      inMeta = /^##\s+1\.\s+Document\s+Meta\s*$/.test(heading);
      inExistingContext = /^##\s+13\.\s+Existing-System\s+Context\s*$/.test(heading);
      if (inMeta) {
        sawMeta = true;
      }
      if (inExistingContext) {
        sawExisting = true;
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

    if (inExistingContext) {
      existingEntries.push({ key: field.key, value: field.value });
    }
  }

  const problems: string[] = [];

  if (!sawMeta) {
    problems.push("section ## 1. Document Meta is missing");
  } else {
    if (!sourceTypeFound) {
      problems.push("## 1. Document Meta -> source_type is missing");
    } else if (isUnfilled(sourceTypeValue)) {
      problems.push("## 1. Document Meta -> source_type is unfilled");
    }

    if (!lastUpdatedFound) {
      problems.push("## 1. Document Meta -> last_updated is missing");
    } else if (isUnfilled(lastUpdatedValue)) {
      problems.push("## 1. Document Meta -> last_updated is unfilled");
    } else if (!/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(lastUpdatedValue)) {
      problems.push("## 1. Document Meta -> last_updated must be YYYY-MM-DD");
    }
  }

  if (!sawExisting) {
    problems.push("section ## 13. Existing-System Context is missing");
  } else if (existingEntries.length === 0) {
    problems.push("## 13. Existing-System Context has no fields");
  } else {
    for (const { key: fieldName, value: fieldValue } of existingEntries) {
      if (isUnfilled(fieldValue)) {
        problems.push(`## 13. Existing-System Context -> ${fieldName} is unfilled`);
      }
    }
  }

  return problems.length > 0 ? gateRecoverable(problems) : gatePassed();
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
