import path from "node:path";

import { readProjectDefinitionMetadata } from "../parse/project-definition.js";
import { evaluate, nextStep } from "../sequencing/index.js";
import type { Diagnostic } from "../types/index.js";

/** First feature step `overmind run` owns; earlier steps are project-level prerequisites. */
export const FIRST_SUPPORTED_STEP = "3";

export type ProjectPendingWork =
  | { kind: "init"; stepId: string; stepName: string; guidance: string[] }
  | { kind: "attach"; classes: string[]; guidance: string[] }
  | { kind: "reconcile"; classes: string[]; guidance: string[] };

export interface PendingWorkResult {
  pending?: ProjectPendingWork;
  diagnostics: Diagnostic[];
}

/**
 * Detect — never execute — project-level work that must be resolved before a
 * feature run (D2/D8). Pending initialization, deferred existing-repo binding, and
 * ready-but-unreconciled classes refuse the run with specific guidance. Deferred
 * policy A classes are intentionally repo-less and do not block feature work.
 * `contract_reconciled: true` is the sole completion source; legacy markers are
 * ignored and never read or written.
 */
export function detectProjectPendingWork(
  workspaceRoot: string,
  projectRoot: string,
  projectPathRel: string
): PendingWorkResult {
  const definitionPath = path.join(projectRoot, "init_progress_definition.yaml");
  const metadata = readProjectDefinitionMetadata(definitionPath);
  if (!metadata.parsed) {
    return { diagnostics: metadata.diagnostics };
  }

  // 1) Project initialization prerequisites (steps before step 3).
  const report = evaluate(workspaceRoot, projectRoot);
  const next = nextStep(report);
  if (next && next.scope === "project" && isBeforeFirstSupported(next.stepId)) {
    return {
      diagnostics: report.diagnostics,
      pending: {
        kind: "init",
        stepId: next.stepId,
        stepName: next.name,
        guidance: initGuidance(next.stepId, next.name, projectPathRel)
      }
    };
  }

  // 2) Existing-repo binding: policy B/C classes, or malformed rows without an
  // intentional policy A decision, need repo binding before feature work.
  const bindingPending = Object.entries(metadata.classRepoPaths)
    .filter(([, entry]) => entry.state !== "ready" && entry.policy !== "A")
    .map(([className]) => className);
  if (bindingPending.length > 0) {
    return {
      diagnostics: report.diagnostics,
      pending: {
        kind: "attach",
        classes: bindingPending,
        guidance: attachGuidance(bindingPending, projectPathRel)
      }
    };
  }

  // 3) Ready but unreconciled classes (definition field is the sole completion source).
  const unreconciled = Object.entries(metadata.classRepoPaths)
    .filter(([, entry]) => entry.state === "ready" && entry.contractReconciled !== true)
    .map(([className]) => className);
  if (unreconciled.length > 0) {
    return {
      diagnostics: report.diagnostics,
      pending: {
        kind: "reconcile",
        classes: unreconciled,
        guidance: reconcileGuidance(unreconciled, projectPathRel)
      }
    };
  }

  return { diagnostics: report.diagnostics };
}

function isBeforeFirstSupported(stepId: string): boolean {
  return compareDottedSteps(stepId, FIRST_SUPPORTED_STEP) < 0;
}

function compareDottedSteps(left: string, right: string): number {
  const leftParts = left.split(".").map((part) => Number.parseInt(part, 10));
  const rightParts = right.split(".").map((part) => Number.parseInt(part, 10));
  const length = Math.max(leftParts.length, rightParts.length);
  for (let index = 0; index < length; index += 1) {
    const leftValue = leftParts[index] ?? 0;
    const rightValue = rightParts[index] ?? 0;
    if (leftValue < rightValue) return -1;
    if (leftValue > rightValue) return 1;
  }
  return 0;
}

function initGuidance(stepId: string, stepName: string, projectPathRel: string): string[] {
  const lines = [
    `Project init is incomplete: next required project step is ${stepId} (${stepName}).`,
    "overmind run starts at feature step 3 and cannot continue until earlier project steps are complete."
  ];
  if (stepId === "1.1" || stepId === "2") {
    lines.push("Run:", `  overmind project init --path ${projectPathRel}`);
  } else {
    lines.push(`Complete project step ${stepId} before rerunning overmind run.`);
  }
  return lines;
}

function attachGuidance(classes: string[], projectPathRel: string): string[] {
  return [
    `Class repository binding records are incomplete: ${classes.join(", ")}.`,
    "Resolve class repo binding before feature work with:",
    `  overmind project reconcile --path ${projectPathRel}`
  ];
}

function reconcileGuidance(classes: string[], projectPathRel: string): string[] {
  return [
    `Ready class repositories need contract reconciliation before feature work: ${classes.join(", ")}.`,
    "Reconcile the common contract with:",
    `  overmind project reconcile --path ${projectPathRel}`
  ];
}
