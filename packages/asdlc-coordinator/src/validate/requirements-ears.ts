import { existsSync, statSync } from "node:fs";
import path from "node:path";

import { readRequiredTextFile, resolveInputPath } from "../parse/index.js";

import type { GateResult } from "../types/index.js";

interface BlockState {
  heading: string;
  hasUserStory: boolean;
  hasAcceptanceCriteria: boolean;
  hasVerification: boolean;
  acceptanceBulletCount: number;
  validEarsBulletCount: number;
}

export function validateRequirementsEars(inputPath: string, cwd = process.cwd()): GateResult {
  if (!inputPath || inputPath.trim() === "") {
    return gateError("Missing target artifact path.");
  }

  try {
    const targetPath = resolveRequirementsEarsPath(inputPath, cwd);
    if (!existsSync(targetPath)) {
      return gateError(`Target EARS requirements not found: ${targetPath}`);
    }
    if (statSync(targetPath).isDirectory()) {
      return gateError(`Target EARS requirements is a directory: ${targetPath}`);
    }

    const content = readRequiredTextFile(targetPath);
    if (!/[^ \t\r\n]/.test(content)) {
      return gateRecoverable([
        `quality gate failed: target EARS requirements is empty: ${targetPath}`
      ]);
    }

    const problems = validateRequirementsEarsContent(content);
    return problems.length > 0 ? gateRecoverable(problems) : gatePassed();
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return gateError(message);
  }
}

export function validateRequirementsEarsContent(content: string): string[] {
  const problems: string[] = [];
  const seenRequirementNumbers = new Set<number>();
  const seenNfrNumbers = new Set<number>();
  let lastRequirementNumber = 0;
  let lastNfrNumber = 0;
  let blockCount = 0;
  let currentBlock: BlockState | undefined;
  let inAcceptanceCriteria = false;

  function failQuality(message: string): void {
    problems.push(`quality gate failed: ${message}`);
  }

  function finishBlock(): void {
    if (!currentBlock) {
      return;
    }

    if (!currentBlock.hasUserStory) {
      failQuality(`missing User Story in block: ${currentBlock.heading}`);
    }
    if (!currentBlock.hasAcceptanceCriteria) {
      failQuality(`missing Acceptance Criteria (EARS) in block: ${currentBlock.heading}`);
    } else {
      if (currentBlock.acceptanceBulletCount === 0) {
        failQuality(`no acceptance-criteria bullets in block: ${currentBlock.heading}`);
      }
      if (currentBlock.validEarsBulletCount === 0) {
        failQuality(`no valid EARS-pattern bullets in block: ${currentBlock.heading}`);
      }
    }
    if (!currentBlock.hasVerification) {
      failQuality(`missing Verification in block: ${currentBlock.heading}`);
    }

    inAcceptanceCriteria = false;
  }

  for (const line of content.split(/\r?\n/)) {
    const blockMatch = line.match(/^### (Requirement|NFR) ([0-9]+)([ \t]|$)/);
    if (blockMatch) {
      finishBlock();
      blockCount += 1;
      inAcceptanceCriteria = false;
      const headingType = blockMatch[1];
      const headingNumber = Number(blockMatch[2]);

      if (headingType === "Requirement") {
        if (seenRequirementNumbers.has(headingNumber)) {
          failQuality(`duplicate Requirement numbering: ${headingNumber}`);
        }
        seenRequirementNumbers.add(headingNumber);
        if (lastRequirementNumber === 0 && headingNumber !== 1) {
          failQuality(`Requirement numbering must start at 1; found ${headingNumber}`);
        }
        if (lastRequirementNumber > 0 && headingNumber !== lastRequirementNumber + 1) {
          failQuality(
            `Requirement numbering must be sequential; expected ${lastRequirementNumber + 1}, found ${headingNumber}`
          );
        }
        lastRequirementNumber = headingNumber;
      } else {
        if (seenNfrNumbers.has(headingNumber)) {
          failQuality(`duplicate NFR numbering: ${headingNumber}`);
        }
        seenNfrNumbers.add(headingNumber);
        if (lastNfrNumber === 0 && headingNumber !== 1) {
          failQuality(`NFR numbering must start at 1; found ${headingNumber}`);
        }
        if (lastNfrNumber > 0 && headingNumber !== lastNfrNumber + 1) {
          failQuality(
            `NFR numbering must be sequential; expected ${lastNfrNumber + 1}, found ${headingNumber}`
          );
        }
        lastNfrNumber = headingNumber;
      }

      currentBlock = {
        heading: line,
        hasUserStory: false,
        hasAcceptanceCriteria: false,
        hasVerification: false,
        acceptanceBulletCount: 0,
        validEarsBulletCount: 0
      };
      continue;
    }

    if (!currentBlock) {
      continue;
    }

    if (/^\*\*User Story:\*\*/.test(line)) {
      currentBlock.hasUserStory = true;
      continue;
    }
    if (/^\*\*Acceptance Criteria \(EARS\):\*\*/.test(line)) {
      currentBlock.hasAcceptanceCriteria = true;
      inAcceptanceCriteria = true;
      continue;
    }
    if (/^\*\*Verification:\*\*/.test(line)) {
      currentBlock.hasVerification = true;
      inAcceptanceCriteria = false;
      continue;
    }

    if (inAcceptanceCriteria && /^[ \t]*-[ \t]+/.test(line)) {
      const bullet = line.replace(/^[ \t]*-[ \t]+/, "");
      currentBlock.acceptanceBulletCount += 1;
      if (!isAllowedEarsPattern(bullet)) {
        failQuality(`invalid EARS bullet pattern in block ${currentBlock.heading}: ${bullet}`);
        continue;
      }
      currentBlock.validEarsBulletCount += 1;
    }
  }

  finishBlock();

  if (blockCount === 0) {
    failQuality("no Requirement/NFR blocks found");
  }

  return problems;
}

function resolveRequirementsEarsPath(inputPath: string, cwd: string): string {
  const resolved = resolveInputPath(inputPath, cwd);
  if (existsSync(resolved) && statSync(resolved).isFile()) {
    return resolved;
  }
  return path.join(resolved, "requirements_ears.md");
}

function isAllowedEarsPattern(bullet: string): boolean {
  return [
    /^THE .+ SHALL .+/i,
    /^WHEN .+ AND WHILE .+, THE .+ SHALL .+/i,
    /^WHEN .+, THE .+ SHALL .+/i,
    /^IF .+, THEN THE .+ SHALL .+/i,
    /^WHILE .+, THE .+ SHALL .+/i,
    /^WHERE .+, THE .+ SHALL .+/i
  ].some((pattern) => pattern.test(bullet));
}

function gatePassed(): GateResult {
  return {
    exitCode: 0,
    passMessage: "quality gate passed: EARS requirements structure is complete",
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
