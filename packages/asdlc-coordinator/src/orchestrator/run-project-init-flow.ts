import { existsSync } from "node:fs";
import path from "node:path";

import type { PathGitInspection, ProjectGitPort } from "../git/index.js";
import { InteractionClosedError, type InteractionPort } from "../interaction/index.js";
import { readProjectDefinitionMetadata } from "../parse/project-definition.js";
import { evaluate, nextStep, type ProgressReport } from "../sequencing/index.js";
import { STEP_CATALOG, type StepDefinition } from "../sequencing/step-catalog.js";
import type { Diagnostic, GateResult } from "../types/index.js";
import type { SurfaceMapClass } from "../validate/surface-map.js";

import {
  resolveProjectInitOwnership,
  type ProjectInitOwnership
} from "./project-init-ownership.js";

export type ProjectInitFlowOutcome =
  | { kind: "completed"; message: string }
  | { kind: "pausedAfterStep11"; resumeCommand: string }
  | { kind: "manualBaselineCommitRequired"; paths: string[]; resumeCommand: string }
  | { kind: "noPendingWork" }
  | { kind: "changedAfterConfirmation"; resumeCommand: string }
  | { kind: "failed"; diagnostics: Diagnostic[]; exitCode?: number };

export interface ProjectInitFlowDeps {
  workspaceRoot: string;
  projectRoot: string;
  projectPathRel: string;
  overmindCliPath: string;
  modelsPath: string;
  interaction: InteractionPort;
  git: ProjectGitPort;
  evaluateProgress?: (workspaceRoot: string, projectRoot: string) => ProgressReport;
  executeStep: (
    step: StepDefinition,
    bindings: {
      step: StepDefinition;
      runtimeRoot: string;
      featurePath: string;
      overmindCliPath: string;
      modelsPath: string;
      targetClass?: SurfaceMapClass;
      classes?: string[];
    }
  ) => Promise<{ ok: boolean; exitCode: number; diagnostics: Diagnostic[] }>;
  validateCommonContract: (projectRoot: string) => GateResult;
  emit: (line: string) => void;
}

const STACK_COMMIT_MESSAGE = "Finalize project stack baseline";
const INIT_COMMIT_MESSAGE = "Finalize project initialization baseline";
const STACK_BASELINE_LABEL = "project stack baseline";
const INIT_BASELINE_LABEL = "project initialization baseline";

function diagnostic(reason: string, source = "project-init"): Diagnostic {
  return { severity: "error", source, reason };
}

export async function runProjectInitFlow(
  deps: ProjectInitFlowDeps
): Promise<ProjectInitFlowOutcome> {
  const metadata = readProjectDefinitionMetadata(
    path.join(deps.projectRoot, "init_progress_definition.yaml")
  );
  if (!metadata.parsed) return { kind: "failed", diagnostics: metadata.diagnostics };

  const ownership = resolveProjectInitOwnership(metadata);
  const inspectable = inspectBaselinePaths(
    deps,
    ownership.initialBaselinePaths,
    INIT_BASELINE_LABEL
  );
  if (inspectable.kind === "failed") return inspectable;

  const manualBaselineCommit = detectManualBaselineCommitRequired(deps, ownership);
  if (manualBaselineCommit) return manualBaselineCommit;

  const report = (deps.evaluateProgress ?? evaluate)(deps.workspaceRoot, deps.projectRoot);
  const selected = nextStep(report);
  if (!selected || selected.scope !== "project" || !isProjectInitStep(selected.stepId)) {
    return { kind: "noPendingWork" };
  }
  if (selected.stepId === "1") {
    return {
      kind: "failed",
      diagnostics: [
        diagnostic(
          "Project metadata initialization is incomplete; create init_progress_definition.yaml before running project init."
        )
      ]
    };
  }

  const step = STEP_CATALOG.find((candidate) => candidate.id === selected.stepId);
  if (!step) {
    return {
      kind: "failed",
      exitCode: 2,
      diagnostics: [diagnostic(`Unknown project init step selected: ${selected.stepId}`)]
    };
  }

  if (selected.stepId === "1.1") {
    const phase = await dispatchStep11(deps, step, ownership);
    if (phase.kind !== "ok") return phase;

    const baseline = finalizeBaselineCommit(
      deps,
      ownership.step11Paths,
      STACK_COMMIT_MESSAGE,
      STACK_BASELINE_LABEL
    );
    if (baseline.kind === "failed") return baseline;
    if (baseline.kind === "alreadyCommitted") {
      return {
        kind: "completed",
        message: `Completed project init step ${selected.stepId}: ${selected.name}`
      };
    }

    deps.emit("Stack baseline committed.");
    return promptForStep2Continuation(deps, ownership);
  }

  return runStep2(deps, ownership, selected.name);
}

function detectManualBaselineCommitRequired(
  deps: ProjectInitFlowDeps,
  ownership: ProjectInitOwnership
): ProjectInitFlowOutcome | undefined {
  const commonContract = inspectPathSet(deps, ["common_contract_definition.md"])?.find(
    (entry) => entry.path === "common_contract_definition.md"
  );
  if (!commonContract || commonContract.hasHeadVersion) return undefined;

  if (existsSync(path.join(deps.projectRoot, "common_contract_definition.md"))) {
    const initialBaseline = inspectPathSet(deps, ownership.initialBaselinePaths);
    const paths = initialBaseline ? pendingPathNames(initialBaseline) : [];
    if (paths.length > 0) return manualBaselineCommitRequired(deps.projectPathRel, paths);
  }

  if (
    ownership.step11Paths.length > 0 &&
    ownership.step11Paths.every((candidate) => existsSync(path.join(deps.projectRoot, candidate)))
  ) {
    const step11 = inspectPathSet(deps, ownership.step11Paths);
    const paths = step11 ? pendingPathNames(step11) : [];
    if (paths.length > 0) return manualBaselineCommitRequired(deps.projectPathRel, paths);
  }

  return undefined;
}

async function dispatchStep11(
  deps: ProjectInitFlowDeps,
  step: StepDefinition,
  ownership: ProjectInitOwnership
): Promise<{ kind: "ok" } | Extract<ProjectInitFlowOutcome, { kind: "failed" }>> {
  return dispatchStep11Classes(deps, step, ownership, ownership.applicableStackClasses);
}

async function dispatchStep11Classes(
  deps: ProjectInitFlowDeps,
  step: StepDefinition,
  ownership: ProjectInitOwnership,
  classes: SurfaceMapClass[]
): Promise<{ kind: "ok" } | Extract<ProjectInitFlowOutcome, { kind: "failed" }>> {
  for (const klass of classes) {
    const result = await deps.executeStep(step, {
      step,
      runtimeRoot: deps.workspaceRoot,
      featurePath: deps.projectPathRel,
      overmindCliPath: deps.overmindCliPath,
      modelsPath: deps.modelsPath,
      targetClass: klass,
      classes: ownership.applicableStackClasses
    });
    if (!result.ok)
      return { kind: "failed", diagnostics: result.diagnostics, exitCode: result.exitCode };
  }
  return { kind: "ok" };
}

async function runStep2(
  deps: ProjectInitFlowDeps,
  ownership: ProjectInitOwnership,
  name: string
): Promise<ProjectInitFlowOutcome> {
  const step = STEP_CATALOG.find((candidate) => candidate.id === "2");
  if (!step) {
    return {
      kind: "failed",
      exitCode: 2,
      diagnostics: [diagnostic("Unknown project init step selected: 2")]
    };
  }

  const result = await dispatchStep2(deps, ownership, step);
  if (result.kind !== "ok") return result;

  const baselineGate = deps.validateCommonContract(deps.projectRoot);
  if (baselineGate.exitCode !== 0) {
    return {
      kind: "failed",
      exitCode: baselineGate.exitCode === 2 ? 2 : 1,
      diagnostics: gateDiagnostics(baselineGate)
    };
  }

  const baseline = finalizeBaselineCommit(
    deps,
    ownership.initialBaselinePaths,
    INIT_COMMIT_MESSAGE,
    INIT_BASELINE_LABEL
  );
  if (baseline.kind === "failed") return baseline;
  return {
    kind: "completed",
    message:
      baseline.kind === "committed"
        ? "Committed project initialization baseline."
        : baseline.kind === "alreadyCommitted"
          ? "Project initialization baseline is already committed."
          : `Completed project init step 2: ${name}`
  };
}

async function dispatchStep2(
  deps: ProjectInitFlowDeps,
  ownership: ProjectInitOwnership,
  step: StepDefinition
): Promise<{ kind: "ok" } | Extract<ProjectInitFlowOutcome, { kind: "failed" }>> {
  const result = await deps.executeStep(step, {
    step,
    runtimeRoot: deps.workspaceRoot,
    featurePath: deps.projectPathRel,
    overmindCliPath: deps.overmindCliPath,
    modelsPath: deps.modelsPath,
    classes: ownership.applicableStackClasses
  });
  if (!result.ok)
    return { kind: "failed", diagnostics: result.diagnostics, exitCode: result.exitCode };
  return { kind: "ok" };
}

async function promptForStep2Continuation(
  deps: ProjectInitFlowDeps,
  ownership: ProjectInitOwnership
): Promise<ProjectInitFlowOutcome> {
  let confirmed: boolean;
  try {
    confirmed = await deps.interaction.confirm({
      message: "Continue with common contract definition?",
      defaultValue: true
    });
  } catch (error) {
    if (error instanceof InteractionClosedError) return paused(deps.projectPathRel);
    throw error;
  }
  if (!confirmed) return paused(deps.projectPathRel);

  const fresh = (deps.evaluateProgress ?? evaluate)(deps.workspaceRoot, deps.projectRoot);
  const freshNext = nextStep(fresh);
  if (!freshNext || freshNext.scope !== "project" || !isProjectInitStep(freshNext.stepId)) {
    return {
      kind: "completed",
      message:
        "Project initialization is already complete; common contract definition was not started."
    };
  }
  if (freshNext.stepId !== "2") {
    return {
      kind: "changedAfterConfirmation",
      resumeCommand: resumeCommand(deps.projectPathRel)
    };
  }
  deps.emit("Continuing with common contract definition...");
  return runStep2(deps, ownership, freshNext.name);
}

function finalizeBaselineCommit(
  deps: Pick<ProjectInitFlowDeps, "projectRoot" | "git">,
  paths: string[],
  message: string,
  baselineLabel: string
):
  | { kind: "committed" }
  | { kind: "alreadyCommitted" }
  | Extract<ProjectInitFlowOutcome, { kind: "failed" }> {
  if (paths.length === 0) return { kind: "alreadyCommitted" };
  const inspected = inspectBaselinePaths(deps, paths, baselineLabel);
  if (inspected.kind !== "ok") return inspected;

  const readiness = baselineReadiness(inspected.paths);
  if (!readiness.hasChanges) {
    if (readiness.missingCommitted.length === 0) return { kind: "alreadyCommitted" };
    return {
      kind: "failed",
      diagnostics: [
        diagnostic(
          `${capitalize(baselineLabel)} is not fully committed; missing HEAD versions: ${readiness.missingCommitted.join(", ")}`
        )
      ]
    };
  }

  const commit = deps.git.commitOwnedPaths(deps.projectRoot, paths, message);
  if (commit.kind === "committed") {
    const verified = inspectBaselinePaths(deps, paths, baselineLabel);
    if (verified.kind !== "ok") return verified;
    const postCommit = baselineReadiness(verified.paths);
    if (postCommit.missingCommitted.length > 0) {
      return {
        kind: "failed",
        diagnostics: [
          diagnostic(
            `${capitalize(baselineLabel)} is not fully committed after ${message}; missing HEAD versions: ${postCommit.missingCommitted.join(", ")}`
          )
        ]
      };
    }
    if (postCommit.hasChanges) {
      return {
        kind: "failed",
        diagnostics: [
          diagnostic(
            `${capitalize(baselineLabel)} left unexpected uncommitted changes: ${postCommit.dirtyPaths.join(", ")}`
          )
        ]
      };
    }
    return { kind: "committed" };
  }
  return {
    kind: "failed",
    diagnostics: [diagnostic(describeCommitFailure(commit, deps.projectRoot, baselineLabel))]
  };
}

function inspectBaselinePaths(
  deps: Pick<ProjectInitFlowDeps, "projectRoot" | "git">,
  paths: string[],
  baselineLabel: string
):
  { kind: "ok"; paths: PathGitInspection[] } | Extract<ProjectInitFlowOutcome, { kind: "failed" }> {
  if (!deps.git.inspectPaths) {
    return {
      kind: "failed",
      diagnostics: [
        diagnostic(
          `Failed to inspect ${baselineLabel} paths for ${deps.projectRoot}: project Git adapter does not support path-scoped inspection.`
        )
      ]
    };
  }

  const inspected = deps.git.inspectPaths(deps.projectRoot, paths);
  if (inspected.kind === "ok") return inspected;
  if (inspected.kind === "unavailable" || inspected.kind === "notWorktree") {
    return {
      kind: "failed",
      diagnostics: [diagnostic(describeCommitFailure(inspected, deps.projectRoot, baselineLabel))]
    };
  }
  return {
    kind: "failed",
    diagnostics: [
      diagnostic(
        `Failed to inspect ${baselineLabel} paths for ${deps.projectRoot} (git exited ${inspected.exitCode}): ${inspected.stderr.trim()}`
      )
    ]
  };
}

function baselineReadiness(paths: PathGitInspection[]): {
  hasChanges: boolean;
  dirtyPaths: string[];
  missingCommitted: string[];
} {
  const dirtyPaths = paths
    .filter((entry) => entry.staged || entry.unstaged || entry.untracked)
    .map((entry) => entry.path);
  return {
    hasChanges: dirtyPaths.length > 0,
    dirtyPaths,
    missingCommitted: paths.filter((entry) => !entry.hasHeadVersion).map((entry) => entry.path)
  };
}

function inspectPathSet(
  deps: Pick<ProjectInitFlowDeps, "projectRoot" | "git">,
  paths: string[]
): PathGitInspection[] | undefined {
  const inspected = deps.git.inspectPaths?.(deps.projectRoot, paths);
  return inspected?.kind === "ok" ? inspected.paths : undefined;
}

function pendingPathNames(paths: PathGitInspection[]): string[] {
  return paths
    .filter((entry) => !entry.hasHeadVersion || entry.staged || entry.unstaged || entry.untracked)
    .map((entry) => entry.path);
}

function manualBaselineCommitRequired(
  projectPathRel: string,
  paths: string[]
): ProjectInitFlowOutcome {
  return {
    kind: "manualBaselineCommitRequired",
    paths,
    resumeCommand: resumeCommand(projectPathRel)
  };
}

function paused(projectPathRel: string): ProjectInitFlowOutcome {
  return { kind: "pausedAfterStep11", resumeCommand: resumeCommand(projectPathRel) };
}

function resumeCommand(projectPathRel: string): string {
  return `overmind project init --path ${projectPathRel}`;
}

function gateDiagnostics(result: GateResult): Diagnostic[] {
  if (result.exitCode === 1) {
    return [
      diagnostic("common-contract baseline validation failed before initialization commit."),
      ...result.problems.map((problem) => diagnostic(problem, "common-contract"))
    ];
  }
  return [
    diagnostic(
      `common-contract baseline validation could not run before initialization commit: ${result.errorMessage ?? "Validation cannot run."}`
    )
  ];
}

function isProjectInitStep(stepId: string): boolean {
  return stepId === "1" || stepId === "1.1" || stepId === "2";
}

function describeCommitFailure(
  commit: Exclude<ReturnType<ProjectGitPort["commitOwnedPaths"]>, { kind: "committed" }>,
  projectRoot: string,
  baselineLabel: string
): string {
  switch (commit.kind) {
    case "unavailable":
      return `Project path must be a git repository to finalize ${baselineLabel}: git not found in PATH.`;
    case "notWorktree":
      return `Project path must be a git repository to finalize ${baselineLabel}: ${projectRoot}`;
    case "stageFailed":
      return `Failed to stage ${baselineLabel} for ${projectRoot}: git add exited ${commit.exitCode}: ${commit.stderr.trim()}`;
    case "commitFailed":
      return `Failed to commit ${baselineLabel} for ${projectRoot}: git commit exited ${commit.exitCode}: ${commit.stderr.trim()}`;
    case "dirtyAfterCommit":
      return `${capitalize(baselineLabel)} left unexpected uncommitted changes: ${commit.paths.join(", ")}`;
    case "inspectionFailed":
      return `Failed to verify ${baselineLabel} for ${projectRoot} (git exited ${commit.exitCode}): ${commit.stderr.trim()}`;
  }
}

function capitalize(value: string): string {
  return value.charAt(0).toUpperCase() + value.slice(1);
}
