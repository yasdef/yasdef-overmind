import { readFileSync } from "node:fs";
import path from "node:path";

import { resolveFeatureWithinWorkspace } from "../parse/index.js";
import type { Diagnostic } from "../types/index.js";

export const WORKER_ASSIGNMENT_REPO_CLASSES = ["backend", "frontend", "mobile"] as const;
export type WorkerAssignmentRepoClass = (typeof WORKER_ASSIGNMENT_REPO_CLASSES)[number];

export interface WorkerAssignmentPlanStep {
  id: string;
  heading: string;
  repo: WorkerAssignmentRepoClass;
  dependsOn: string[];
  startLine: number;
  endLine: number;
}

export interface WorkerAssignmentPlanShapeResult {
  ok: boolean;
  diagnostics: Diagnostic[];
  steps: WorkerAssignmentPlanStep[];
}

export interface WorkerAssignmentPlanFileResult extends WorkerAssignmentPlanShapeResult {
  workspaceRoot?: string;
  featureDir?: string;
  projectDir?: string;
  planPath?: string;
  relativeFeature?: string;
}

interface ParsedStep {
  id: string;
  heading: string;
  repoLines: string[];
  dependsLines: string[];
  startLine: number;
  endLine: number;
}

const SUPPORTED_REPO_SET = new Set<string>(WORKER_ASSIGNMENT_REPO_CLASSES);

export function validateWorkerAssignmentPlanContent(
  content: string,
  source = "implementation_plan.md"
): WorkerAssignmentPlanShapeResult {
  const parsedSteps = parsePlanSteps(content);
  const diagnostics: Diagnostic[] = [];
  const steps: WorkerAssignmentPlanStep[] = [];

  if (parsedSteps.length === 0) {
    diagnostics.push({
      severity: "error",
      source,
      reason: "assignment readiness failed: plan must contain at least one ### Step block"
    });
    return { ok: false, diagnostics, steps };
  }

  for (const step of parsedSteps) {
    if (step.repoLines.length !== 1) {
      diagnostics.push({
        severity: "error",
        source,
        stepId: step.id,
        reason: `assignment readiness failed: step ${step.id} must declare exactly one #### Repo line`
      });
      continue;
    }
    const repo = step.repoLines[0]!.trim().toLowerCase();
    if (!SUPPORTED_REPO_SET.has(repo)) {
      diagnostics.push({
        severity: "error",
        source,
        stepId: step.id,
        reason: `assignment readiness failed: step ${step.id} has unsupported repo class '${repo}'`
      });
      continue;
    }
    steps.push({
      id: step.id,
      heading: step.heading,
      repo: repo as WorkerAssignmentRepoClass,
      dependsOn: step.dependsLines.flatMap(splitDependsOn),
      startLine: step.startLine,
      endLine: step.endLine
    });
  }

  return { ok: diagnostics.length === 0, diagnostics, steps };
}

export function validateWorkerAssignmentPlan(
  featurePath: string,
  cwd = process.cwd()
): WorkerAssignmentPlanFileResult {
  const resolved = resolveFeatureWithinWorkspace(featurePath, cwd);
  if (!resolved.ok) {
    return {
      ok: false,
      diagnostics: [{ severity: "error", source: featurePath, reason: resolved.message }],
      steps: []
    };
  }
  const { workspaceRoot, featureDir, relativeFeature } = resolved.value;
  const parts = relativeFeature.split(path.sep);
  if (parts.length !== 3 || parts[0] !== "projects" || !parts[1] || !parts[2]) {
    return {
      ok: false,
      diagnostics: [
        {
          severity: "error",
          source: featurePath,
          reason: `Feature path must resolve under projects/<project-id>/<feature-folder>: ${relativeFeature}`
        }
      ],
      steps: []
    };
  }
  const targetPath = path.join(featureDir, "implementation_plan.md");
  try {
    const result = validateWorkerAssignmentPlanContent(
      readFileSync(targetPath, "utf8"),
      targetPath
    );
    return {
      ...result,
      workspaceRoot,
      featureDir,
      projectDir: path.dirname(featureDir),
      planPath: targetPath,
      relativeFeature
    };
  } catch (error) {
    return {
      ok: false,
      diagnostics: [
        {
          severity: "error",
          source: targetPath,
          reason: `assignment readiness failed: unable to read implementation_plan.md: ${
            error instanceof Error ? error.message : String(error)
          }`
        }
      ],
      steps: []
    };
  }
}

function parsePlanSteps(content: string): ParsedStep[] {
  const lines = content.split(/\r?\n/);
  const steps: ParsedStep[] = [];
  let current: ParsedStep | undefined;

  const flush = (endLine: number): void => {
    if (!current) return;
    current.endLine = endLine;
    steps.push(current);
    current = undefined;
  };

  lines.forEach((line, index) => {
    const stepHeading = line.match(/^###\s+Step\s+([^\s]+)(?:\s+.*)?$/);
    if (stepHeading) {
      flush(index);
      current = {
        id: stepHeading[1]!,
        heading: line,
        repoLines: [],
        dependsLines: [],
        startLine: index,
        endLine: lines.length
      };
      return;
    }
    if (!current) return;
    const repo = line.match(/^####\s+Repo:\s*(.*)$/);
    if (repo) {
      current.repoLines.push(repo[1] ?? "");
      return;
    }
    const depends = line.match(/^####\s+Depends on:\s*(.*)$/);
    if (depends) current.dependsLines.push(depends[1] ?? "");
  });
  flush(lines.length);
  return steps;
}

function splitDependsOn(value: string): string[] {
  const normalized = value.trim();
  if (!normalized || normalized.toLowerCase() === "none") return [];
  return normalized
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}
