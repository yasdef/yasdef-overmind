import type { ProgressReport, StepProgress } from "./evaluate.js";

export interface NextStep {
  stepId: string;
  name: string;
  scope: "project" | "feature";
  perClassPending?: string[];
}

export interface FeatureSummary {
  readiness: "ready" | "in_progress" | "blocked" | "unknown";
  completedSteps: number;
  totalSteps: number;
  missingArtifacts: string[];
}

export function nextStep(report: ProgressReport): NextStep | undefined {
  const step = report.steps.find((candidate) => !candidate.optional && candidate.state !== "done");
  if (!step) return undefined;
  return {
    stepId: step.stepId,
    name: step.name,
    scope: step.scope,
    ...(step.perClass
      ? {
          perClassPending: step.perClass
            .filter((item) => item.state !== "done")
            .map((item) => item.className)
        }
      : {})
  };
}

export function formatCanonicalNextStep(report: ProgressReport): string {
  const next = nextStep(report);
  return next ? `next step: ${next.stepId} (${next.name})` : "next step: none";
}

function formatStep(step: StepProgress): string {
  return `- [${step.state === "done" ? "x" : " "}] ${step.stepId} ${step.name}`;
}

export function formatChecklist(report: ProgressReport): string {
  const projectSteps = report.steps.filter((step) => step.scope === "project").map(formatStep);
  const featureSteps = report.steps.filter((step) => step.scope === "feature").map(formatStep);
  return [
    "# Overmind Bootstrap Checklist",
    "",
    "---- PROJECT LEVEL TASKS ----",
    ...projectSteps,
    `--- FEATURE LEVEL TASKS ${report.featureTitle} ---`,
    ...featureSteps,
    "",
    formatCanonicalNextStep(report)
  ].join("\n");
}

export function toFeatureSummary(report: ProgressReport): FeatureSummary {
  const completedSteps = report.steps.filter((step) => step.state === "done").length;
  const missingArtifacts = [...new Set(report.steps.flatMap((step) => step.missingArtifacts))];
  let readiness: FeatureSummary["readiness"];
  if (!report.definitionParsed) readiness = "unknown";
  else if (report.steps.some((step) => step.state === "blocked")) readiness = "blocked";
  else if (report.steps.some((step) => step.state === "pending")) readiness = "in_progress";
  else readiness = "ready";
  return { readiness, completedSteps, totalSteps: report.steps.length, missingArtifacts };
}
