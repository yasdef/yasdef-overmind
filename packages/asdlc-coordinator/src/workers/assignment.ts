import { existsSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

import type { InteractionPort } from "../interaction/index.js";
import type { Diagnostic } from "../types/index.js";
import {
  validateWorkerAssignmentPlan,
  type WorkerAssignmentPlanStep,
  type WorkerAssignmentRepoClass
} from "../validate/worker-assignment.js";
import { parseWorkersRegistry, readProjectId, type WorkerEntry } from "./registry.js";

export interface AssignWorkersDeps {
  interaction: InteractionPort;
  cwd?: string;
}

export interface ClassAssignment {
  className: WorkerAssignmentRepoClass;
  value: string;
  status: "assigned" | "missing";
}

export interface StepAssignment {
  stepId: string;
  value: string;
  status: "assigned" | "missing" | "hold";
}

export interface AssignWorkersResult {
  ok: boolean;
  diagnostics: Diagnostic[];
  changedPaths: string[];
  assignments: ClassAssignment[];
  stepAssignments: StepAssignment[];
}

export async function assignWorkers(
  featurePath: string,
  deps: AssignWorkersDeps
): Promise<AssignWorkersResult> {
  const shape = validateWorkerAssignmentPlan(featurePath, deps.cwd ?? process.cwd());
  if (!shape.ok || !shape.featureDir || !shape.projectDir || !shape.planPath) {
    return {
      ok: false,
      diagnostics: shape.diagnostics,
      changedPaths: [],
      assignments: [],
      stepAssignments: []
    };
  }

  const planPath = shape.planPath;
  const projectPath = shape.projectDir;
  const registryPath = path.join(projectPath, "workers.yaml");
  const definitionPath = path.join(projectPath, "init_progress_definition.yaml");
  const planContent = readFileSync(planPath, "utf8");

  const registry = loadRegistry(registryPath, definitionPath);
  if (!registry.ok) return registry.result;

  const diagnostics: Diagnostic[] = [];
  const assignments = await resolveClassAssignments(
    shape.steps,
    registry.workers,
    deps.interaction
  );
  const assignmentByClass = new Map(assignments.map((item) => [item.className, item]));
  const holdsByStep = new Map<string, string>();
  for (const step of shape.steps) {
    const hold = firstDependencyHold(projectPath, step);
    if (hold) holdsByStep.set(step.id, hold);
  }
  diagnostics.push(
    ...classAssignmentDiagnostics(
      assignments,
      registryPath,
      requiredClassesForNonHeldSteps(shape.steps, holdsByStep)
    )
  );

  const stepAssignments = shape.steps.map((step) => {
    const hold = holdsByStep.get(step.id);
    if (hold) {
      diagnostics.push({
        severity: "error",
        source: planPath,
        stepId: step.id,
        reason: `dependency hold: ${hold}`
      });
      return { stepId: step.id, value: `hold: ${hold}`, status: "hold" as const };
    }
    const classAssignment = assignmentByClass.get(step.repo)!;
    return { stepId: step.id, value: classAssignment.value, status: classAssignment.status };
  });

  writeFileSync(planPath, rewriteAssignedLines(planContent, shape.steps, stepAssignments));
  return {
    ok: diagnostics.length === 0,
    diagnostics,
    changedPaths: ["implementation_plan.md"],
    assignments,
    stepAssignments
  };
}

export function rewriteAssignedLines(
  content: string,
  steps: WorkerAssignmentPlanStep[],
  assignments: StepAssignment[]
): string {
  const lines = content.split("\n");
  const assignmentByStep = new Map(assignments.map((item) => [item.stepId, item.value]));
  const chunks: string[] = [];
  let cursor = 0;

  for (const step of steps) {
    chunks.push(...lines.slice(cursor, step.startLine));
    const stepLines = lines
      .slice(step.startLine, step.endLine)
      .filter((line) => !/^####\s+Assigned:\s*/.test(stripCr(line)));
    const insertAt = assignmentInsertIndex(stepLines);
    const assigned = `#### Assigned: ${assignmentByStep.get(step.id) ?? ""}`;
    chunks.push(...stepLines.slice(0, insertAt), assigned, ...stepLines.slice(insertAt));
    cursor = step.endLine;
  }
  chunks.push(...lines.slice(cursor));
  return chunks.join("\n");
}

async function resolveClassAssignments(
  steps: WorkerAssignmentPlanStep[],
  workers: WorkerEntry[],
  interaction: InteractionPort
): Promise<ClassAssignment[]> {
  const classes = [...new Set(steps.map((step) => step.repo))].sort();
  const assignments: ClassAssignment[] = [];
  for (const className of classes) {
    const candidates = workers.filter(
      (worker) => worker.className === className && worker.status.toLowerCase() === "active"
    );
    if (candidates.length === 0) {
      assignments.push({
        className,
        value: `error: no active worker for ${className}`,
        status: "missing"
      });
      continue;
    }
    if (candidates.length === 1) {
      assignments.push({ className, value: candidates[0]!.uuid, status: "assigned" });
      continue;
    }
    const selected = await interaction.select({
      message: `Choose active ${className} worker:`,
      options: candidates.map((worker) => ({
        value: worker.uuid,
        label: `${worker.uuid} (${worker.status})`
      }))
    });
    assignments.push({ className, value: selected, status: "assigned" });
  }
  return assignments;
}

function loadRegistry(
  registryPath: string,
  definitionPath: string
): { ok: true; workers: WorkerEntry[] } | { ok: false; result: AssignWorkersResult } {
  if (!existsSync(registryPath)) {
    return { ok: false, result: failure(registryPath, "workers.yaml not found.") };
  }
  const projectId = readProjectId(definitionPath);
  if (!projectId) {
    return {
      ok: false,
      result: failure(definitionPath, "Project definition is missing meta_info.project_id.")
    };
  }
  const parsed = parseWorkersRegistry(readFileSync(registryPath, "utf8"));
  if (!parsed.projectId)
    return { ok: false, result: failure(registryPath, "workers.yaml is missing project_id.") };
  if (parsed.projectId !== projectId) {
    return {
      ok: false,
      result: failure(
        registryPath,
        `workers.yaml project_id '${parsed.projectId}' does not match project definition '${projectId}'.`
      )
    };
  }
  if (parsed.workersLine < 0)
    return { ok: false, result: failure(registryPath, "workers.yaml is missing workers:.") };
  return { ok: true, workers: parsed.workers };
}

function firstDependencyHold(
  projectPath: string,
  step: WorkerAssignmentPlanStep
): string | undefined {
  for (const dependency of step.dependsOn) {
    if (!dependency.includes("/")) continue;
    const [feature, stepId] = dependency.split("/", 2);
    if (!feature || !stepId) continue;
    if (
      !dependencyStepComplete(path.join(projectPath, feature, "implementation_plan.md"), stepId)
    ) {
      return `depends on ${feature}/${stepId}`;
    }
  }
  return undefined;
}

function dependencyStepComplete(planPath: string, stepId: string): boolean {
  if (!existsSync(planPath)) return false;
  const lines = readFileSync(planPath, "utf8").split(/\r?\n/);
  let inStep = false;
  const checklist: string[] = [];
  for (const line of lines) {
    const heading = line.match(/^###\s+Step\s+([^\s]+)(?:\s+.*)?$/);
    if (heading) {
      if (inStep) break;
      inStep = heading[1] === stepId;
      continue;
    }
    if (!inStep) continue;
    if (/^\s*-\s+\[[ xX]\]\s+/.test(line)) checklist.push(line);
  }
  return checklist.length > 0 && checklist.every((line) => /^\s*-\s+\[[xX]\]\s+/.test(line));
}

function assignmentInsertIndex(stepLines: string[]): number {
  let index = 1;
  while (index < stepLines.length && /^####\s+/.test(stripCr(stepLines[index]!))) {
    index += 1;
  }
  return index;
}

function requiredClassesForNonHeldSteps(
  steps: WorkerAssignmentPlanStep[],
  holdsByStep: Map<string, string>
): Set<WorkerAssignmentRepoClass> {
  return new Set(steps.filter((step) => !holdsByStep.has(step.id)).map((step) => step.repo));
}

function classAssignmentDiagnostics(
  assignments: ClassAssignment[],
  source: string,
  requiredClasses: Set<WorkerAssignmentRepoClass>
): Diagnostic[] {
  return assignments
    .filter(
      (assignment) => assignment.status === "missing" && requiredClasses.has(assignment.className)
    )
    .map((assignment) => ({
      severity: "error" as const,
      source,
      reason: `no active worker for ${assignment.className}`
    }));
}

function stripCr(line: string): string {
  return line.endsWith("\r") ? line.slice(0, -1) : line;
}

function failure(source: string, reason: string): AssignWorkersResult {
  return {
    ok: false,
    diagnostics: [{ severity: "error", source, reason }],
    changedPaths: [],
    assignments: [],
    stepAssignments: []
  };
}
