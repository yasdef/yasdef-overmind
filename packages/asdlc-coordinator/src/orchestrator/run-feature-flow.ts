import path from "node:path";

import type { ScaffoldClock } from "../capture/scaffold-feature.js";
import { CHECKPOINT_LABELS, renderCheckpointNotice, type CheckpointPort } from "../git/index.js";
import { InteractionClosedError, type InteractionPort } from "../interaction/index.js";
import type { StepBindings, StepExecutorDeps, StepResult } from "../runner/index.js";
import { executeStep as defaultExecuteStep } from "../runner/index.js";
import { evaluate, nextStep, resolveStep, STEP_CATALOG } from "../sequencing/index.js";
import type { StepDefinition } from "../sequencing/step-catalog.js";
import type { Diagnostic } from "../types/index.js";
import type { SurfaceMapClass } from "../validate/surface-map.js";

import { persistFeatureState, resolveFeatureTarget } from "./feature-selection.js";
import { detectProjectPendingWork } from "./pending-work.js";

/** Per-phase flow-control value; replaces the shell's numeric rc protocol. */
export type PhaseOutcome =
  | { kind: "completed" }
  | { kind: "skippedOptional" }
  | { kind: "stoppedByOperator" }
  | { kind: "finished" }
  | { kind: "failed"; resumeStep: string; diagnostics: Diagnostic[] };

/** Aggregate result the CLI maps to exit codes and restart guidance. */
export type FeatureFlowOutcome =
  | { kind: "completed" }
  | { kind: "finished" }
  | { kind: "stoppedByOperator" }
  | { kind: "failed"; resumeStep: string; diagnostics: Diagnostic[] }
  | { kind: "refusedPendingWork"; guidance: string[] }
  | { kind: "startupError"; diagnostics: Diagnostic[] };

export interface FeatureFlowDeps {
  workspaceRoot: string;
  projectRoot: string;
  projectPathRel: string;
  resumeInput?: string;
  interaction: InteractionPort;
  executorDeps: StepExecutorDeps;
  checkpoint: CheckpointPort;
  clock: ScaffoldClock;
  overmindCliPath: string;
  modelsPath?: string;
  /** Injected step executor (D1); defaults to the real `executeStep`. */
  executeStep?: (
    step: StepDefinition,
    bindings: StepBindings,
    executorDeps: StepExecutorDeps
  ) => Promise<StepResult>;
  emit: (line: string) => void;
  emitError: (line: string) => void;
}

const CHECKPOINT_BEFORE: Record<string, string> = {
  "5.1": CHECKPOINT_LABELS.before51,
  "7.1": CHECKPOINT_LABELS.before71,
  "8.4": CHECKPOINT_LABELS.before84
};

/**
 * The `overmind run` feature-flow use case (D1): detect pending project work,
 * resolve the feature target, then drive catalog steps through the generic
 * executor with operator confirmations, optional-step semantics, the phase-7
 * per-class loop, and best-effort checkpoints. Returns a typed `FeatureFlowOutcome`;
 * the CLI owns rendering and exit codes.
 */
export async function runFeatureFlow(deps: FeatureFlowDeps): Promise<FeatureFlowOutcome> {
  const pending = detectProjectPendingWork(
    deps.workspaceRoot,
    deps.projectRoot,
    deps.projectPathRel
  );
  if (pending.pending) {
    return { kind: "refusedPendingWork", guidance: pending.pending.guidance };
  }
  if (pending.diagnostics.some((diagnostic) => diagnostic.severity === "error")) {
    return { kind: "startupError", diagnostics: pending.diagnostics };
  }

  let resumeStepId: string | undefined;
  if (deps.resumeInput !== undefined && deps.resumeInput.trim() !== "") {
    const resolved = resolveStep(deps.resumeInput);
    if (!resolved.stepId) return { kind: "startupError", diagnostics: resolved.diagnostics };
    resumeStepId = resolved.stepId;
  }

  const decision = await resolveFeatureTarget({
    workspaceRoot: deps.workspaceRoot,
    projectRoot: deps.projectRoot,
    projectPathRel: deps.projectPathRel,
    resumeStepId,
    interaction: deps.interaction,
    emit: deps.emit
  });

  let featurePath: string;
  if (decision.kind === "stop") {
    return { kind: "stoppedByOperator" };
  } else if (decision.kind === "fail") {
    return { kind: "startupError", diagnostics: decision.diagnostics };
  } else if (decision.kind === "startNew") {
    // Project→feature transition: the project-scoped scaffold boundary that
    // creates the feature before the feature-scoped phase loop runs.
    const scaffolded = await scaffoldNewFeature(deps);
    if (scaffolded.outcome) return finalize(scaffolded.outcome);
    featurePath = scaffolded.featurePath;
    if (resumeStepId === "3") resumeStepId = undefined;
  } else {
    featurePath = decision.featurePath;
  }

  const featureDir = path.join(deps.workspaceRoot, featurePath);

  let startId: string;
  if (resumeStepId) {
    startId = resumeStepId;
  } else {
    const next = nextStep(evaluate(deps.workspaceRoot, deps.projectRoot, featureDir));
    if (!next) {
      deps.emit("Execution finished: scanner reports no remaining required steps.");
      return { kind: "finished" };
    }
    startId = next.stepId;
  }

  // Step 3 is the scaffold step, owned solely by the pre-loop startNew path; the
  // main phase loop never legitimately begins at it. Reaching here with startId 3
  // means an existing selected feature has no scaffold artifact (feature_br_summary.md),
  // so refuse with guidance instead of silently skipping to a step 4.1 that will fail.
  if (startId === "3") {
    return {
      kind: "startupError",
      diagnostics: [
        {
          severity: "error",
          source: "orchestrator",
          reason:
            "Selected feature has no business-requirements scaffold (feature_br_summary.md); start a new feature to scaffold it instead of continuing this one."
        }
      ]
    };
  }

  const startIndex = STEP_CATALOG.findIndex((step) => step.id === startId);
  if (startIndex < 0) {
    return {
      kind: "startupError",
      diagnostics: [
        {
          severity: "error",
          source: "orchestrator",
          reason: `Configured start phase is unknown: ${startId}`
        }
      ]
    };
  }

  for (let index = startIndex; index < STEP_CATALOG.length; index += 1) {
    const step = STEP_CATALOG[index]!;

    const beforeLabel = CHECKPOINT_BEFORE[step.id];
    if (beforeLabel) {
      deps.emit(
        renderCheckpointNotice(
          deps.checkpoint.checkpoint(deps.projectRoot, beforeLabel),
          beforeLabel
        )
      );
    }

    const outcome = await runStep(step, featurePath, index, deps);

    if (step.id === "8.4" && (outcome.kind === "completed" || outcome.kind === "finished")) {
      const label = CHECKPOINT_LABELS.after84;
      deps.emit(renderCheckpointNotice(deps.checkpoint.checkpoint(deps.projectRoot, label), label));
    }

    if (outcome.kind === "stoppedByOperator") return { kind: "stoppedByOperator" };
    if (outcome.kind === "finished") return { kind: "finished" };
    if (outcome.kind === "failed") {
      return { kind: "failed", resumeStep: outcome.resumeStep, diagnostics: outcome.diagnostics };
    }
    // completed / skippedOptional continue.
  }

  deps.emit("Execution finished: reached end of configured phase map.");
  return { kind: "completed" };

  function finalize(outcome: PhaseOutcome): FeatureFlowOutcome {
    if (outcome.kind === "stoppedByOperator") return { kind: "stoppedByOperator" };
    if (outcome.kind === "finished") return { kind: "finished" };
    if (outcome.kind === "failed") {
      return { kind: "failed", resumeStep: outcome.resumeStep, diagnostics: outcome.diagnostics };
    }
    return { kind: "completed" };
  }
}

async function runStep(
  step: StepDefinition,
  featurePath: string,
  index: number,
  deps: FeatureFlowDeps
): Promise<PhaseOutcome> {
  // Every step (including 4.1 and the per-class step 7) confirms before running.
  let confirmed: boolean;
  try {
    deps.emit(`Phase ${step.id} (${step.label})`);
    confirmed = await deps.interaction.confirm({
      message: `Start step ${step.id} (${step.label})?`
    });
  } catch (error) {
    if (error instanceof InteractionClosedError) {
      deps.emit(`Execution stopped: user input stream closed during confirmation at ${step.id}.`);
      return { kind: "stoppedByOperator" };
    }
    throw error;
  }
  if (!confirmed) {
    if (step.optional) {
      if (hasLaterRequiredPhase(index)) {
        deps.emit(`Optional phase declined at ${step.id}; skipping.`);
        return { kind: "skippedOptional" };
      }
      deps.emit(
        `Execution finished: no remaining required phases after declined optional phase ${step.id}.`
      );
      return { kind: "finished" };
    }
    deps.emit(`Execution stopped: user denied phase progression at ${step.id}.`);
    return { kind: "stoppedByOperator" };
  }

  if (step.perClass) {
    return runPhase7Loop(step, featurePath, deps);
  }
  return executeCatalogStep(step, featurePath, deps);
}

async function executeCatalogStep(
  step: StepDefinition,
  featurePath: string,
  deps: FeatureFlowDeps,
  targetClass?: SurfaceMapClass
): Promise<PhaseOutcome> {
  const bindings: StepBindings = {
    step,
    runtimeRoot: deps.workspaceRoot,
    featurePath,
    overmindCliPath: deps.overmindCliPath,
    ...(deps.modelsPath ? { modelsPath: deps.modelsPath } : {}),
    ...(targetClass ? { targetClass } : {})
  };

  const execute = deps.executeStep ?? defaultExecuteStep;
  let result;
  try {
    result = await execute(step, bindings, deps.executorDeps);
  } catch (error) {
    if (error instanceof InteractionClosedError) {
      deps.emit(`Execution stopped: user input stream closed during ${step.id}.`);
      return { kind: "stoppedByOperator" };
    }
    throw error;
  }

  for (const action of result.actionResults) {
    if (action.status === "skipped") {
      for (const diagnostic of action.diagnostics) deps.emit(diagnostic.reason);
    }
  }

  if (!result.ok) {
    return { kind: "failed", resumeStep: step.id, diagnostics: result.diagnostics };
  }
  return { kind: "completed" };
}

async function runPhase7Loop(
  step: StepDefinition,
  featurePath: string,
  deps: FeatureFlowDeps
): Promise<PhaseOutcome> {
  const featureDir = path.join(deps.workspaceRoot, featurePath);

  for (;;) {
    const report = evaluate(deps.workspaceRoot, deps.projectRoot, featureDir);
    const perClass = report.steps.find((candidate) => candidate.stepId === "7")?.perClass ?? [];
    const completed = perClass
      .filter((item) => item.state === "done")
      .map((item) => item.className);
    const pendingItems = perClass.filter((item) => item.state !== "done");
    const pending = pendingItems.map((item) => item.className);
    const analyzable = pendingItems
      .filter((item) => item.analysisAvailability !== "unavailable")
      .map((item) => item.className);
    const unavailable = pendingItems
      .filter((item) => item.analysisAvailability === "unavailable")
      .map((item) => item.className);

    deps.emit(`Phase 7 class loop status for feature: ${featurePath}`);
    deps.emit(`Already picked/completed classes: ${formatClassList(completed)}`);
    deps.emit(`Pending classes: ${formatClassList(pending)}`);
    deps.emit(`Deferred/unavailable classes: ${formatClassList(unavailable)}`);

    const options = [
      ...(analyzable.length > 0 ? [{ value: "analyze", label: "Analyze one class now" }] : []),
      { value: "refresh", label: "Refresh class status" },
      { value: "forward", label: "contract delta finished lets move forward" }
    ];

    let choice: string;
    try {
      choice = await deps.interaction.select({ message: "Phase 7 options:", options });
    } catch (error) {
      if (error instanceof InteractionClosedError) {
        deps.emit("Execution stopped: user input stream closed during phase 7 loop.");
        return { kind: "stoppedByOperator" };
      }
      throw error;
    }

    if (choice === "refresh") continue;
    if (choice === "forward") break;

    // analyze one class
    let selectedClass: string;
    if (analyzable.length === 1) {
      selectedClass = analyzable[0]!;
    } else {
      try {
        selectedClass = await deps.interaction.select({
          message: "Select a class to analyze now:",
          options: analyzable.map((className) => ({ value: className, label: className }))
        });
      } catch (error) {
        if (error instanceof InteractionClosedError) {
          deps.emit("Execution stopped: user input stream closed during class selection.");
          return { kind: "stoppedByOperator" };
        }
        throw error;
      }
    }

    deps.emit(`Starting surface-map session for class ${selectedClass}.`);
    const outcome = await executeCatalogStep(
      step,
      featurePath,
      deps,
      selectedClass as SurfaceMapClass
    );
    if (outcome.kind === "failed" || outcome.kind === "stoppedByOperator") return outcome;
  }

  const report = evaluate(deps.workspaceRoot, deps.projectRoot, featureDir);
  const remaining = (report.steps.find((candidate) => candidate.stepId === "7")?.perClass ?? [])
    .filter((item) => item.state !== "done")
    .map((item) => item.className);
  if (remaining.length > 0) {
    deps.emit(`Proceeding with pending classes: ${formatClassList(remaining)}`);
  }
  return { kind: "completed" };
}

/**
 * Project→feature transition. Step 3 is project-scoped — it consumes the project
 * path and produces the feature — so it runs through this thin scoped entry ahead
 * of the feature-scoped phase loop, dispatching the registered scaffold primitive
 * through `executeStep` (not a bespoke launcher) and adopting its typed featurePath.
 */
async function scaffoldNewFeature(
  deps: FeatureFlowDeps
): Promise<
  { featurePath: string; outcome?: undefined } | { featurePath?: undefined; outcome: PhaseOutcome }
> {
  const step3 = STEP_CATALOG.find((step) => step.id === "3")!;

  try {
    deps.emit(`Phase ${step3.id} (${step3.label})`);
    const confirmed = await deps.interaction.confirm({
      message: `Start step ${step3.id} (${step3.label})?`
    });
    if (!confirmed) {
      deps.emit("Execution stopped: user denied phase progression at 3.");
      return { outcome: { kind: "stoppedByOperator" } };
    }
  } catch (error) {
    if (error instanceof InteractionClosedError) {
      deps.emit("Execution stopped: user input stream closed during confirmation at 3.");
      return { outcome: { kind: "stoppedByOperator" } };
    }
    throw error;
  }

  // The scaffold primitive is registered in the executor's action registry; the
  // orchestrator only supplies the ports it needs (interaction/clock/emit) and a
  // project binding — it does not swap the registered action.
  const scaffoldDeps: StepExecutorDeps = {
    ...deps.executorDeps,
    interaction: deps.interaction,
    clock: deps.clock,
    emit: deps.emit
  };

  const bindings: StepBindings = {
    step: step3,
    runtimeRoot: deps.workspaceRoot,
    featurePath: deps.projectPathRel,
    projectPath: deps.projectPathRel,
    overmindCliPath: deps.overmindCliPath,
    ...(deps.modelsPath ? { modelsPath: deps.modelsPath } : {})
  };

  const execute = deps.executeStep ?? defaultExecuteStep;
  let result;
  try {
    result = await execute(step3, bindings, scaffoldDeps);
  } catch (error) {
    if (error instanceof InteractionClosedError) {
      deps.emit("Execution stopped: user input stream closed during scaffold input.");
      return { outcome: { kind: "stoppedByOperator" } };
    }
    throw error;
  }

  if (!result.ok) {
    return { outcome: { kind: "failed", resumeStep: "3", diagnostics: result.diagnostics } };
  }

  const created = result.actionResults.find((action) => action.featurePath)?.featurePath;
  if (!created) {
    return {
      outcome: {
        kind: "failed",
        resumeStep: "3",
        diagnostics: [
          {
            severity: "error",
            source: "scaffold-feature",
            reason: "Scaffold produced no feature path."
          }
        ]
      }
    };
  }

  persistFeatureState(deps.projectRoot, created, deps.emit);
  return { featurePath: created };
}

function hasLaterRequiredPhase(index: number): boolean {
  return STEP_CATALOG.slice(index + 1).some((step) => !step.optional);
}

function formatClassList(classes: string[]): string {
  return classes.length > 0 ? classes.join(", ") : "none";
}
