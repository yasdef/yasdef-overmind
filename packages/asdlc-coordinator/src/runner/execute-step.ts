import path from "node:path";

import { scaffoldFeature, type ScaffoldClock } from "../capture/scaffold-feature.js";
import { loadRunnerConfig, resolveRunnerPhase } from "../config/index.js";
import { RepoGitProjectAdapter, type ProjectGitPort } from "../git/index.js";
import type { InteractionPort } from "../interaction/index.js";
import {
  buildBrClarificationContext,
  buildContractDeltaContext,
  buildEarsReviewContext,
  buildAgentsMdContext,
  buildImplementationPlanContext,
  buildImplementationSlicesContext,
  buildPlanSemanticReviewContext,
  buildPrerequisiteGapsContext,
  buildRepoBrScanContext,
  buildRequirementsEarsContext,
  buildCommonContractInitContext,
  buildStackBlueprintContext,
  buildSurfaceMapContext,
  buildSurfaceMapEnrichContext,
  buildTaskToBrContext,
  buildTechnicalRequirementsContext,
  buildContractReconciliationContext
} from "../context/index.js";
import { collectReadyRepoPaths } from "../repo/index.js";
import { runBrClarificationReadiness } from "../readiness/index.js";
import type { Action, StepDefinition } from "../sequencing/step-catalog.js";
import {
  syncContractDeltaStep,
  syncPrerequisiteGapsStep,
  syncRepoBrScanStep,
  syncSurfaceMapStep
} from "../sync/index.js";
import type { ContextResult, Diagnostic, ReadinessResult, SyncStepResult } from "../types/index.js";
import type { SurfaceMapClass } from "../validate/surface-map.js";

import type { AgentRunner } from "./agent-runner.js";
import {
  resolveActionOutputPaths,
  resolveGuardPaths,
  resolveModelsPath,
  resolveProjectAbsolutePath,
  type StepBindings
} from "./bindings.js";
import {
  assertRequiredOutputs,
  snapshotReadOnlyGuards,
  validateReadOnlyGuardsBeforeSession,
  verifyReadOnlyGuards
} from "./guards.js";
import { buildSessionPrompt, buildUnknownPromptRecipeDiagnostic } from "./prompt-builder.js";

type SessionContextBuilder = (
  featurePath: string,
  cwd: string,
  klass?: SurfaceMapClass
) => ContextResult;
type ClassListContextBuilder = (
  projectPath: string,
  classes: string[],
  cwd: string
) => ContextResult;
type SyncFn = (featurePath: string, cwd: string, klass?: SurfaceMapClass) => SyncStepResult;
type ReadinessFn = (featurePath: string, cwd: string) => ReadinessResult;
export interface WriteActionOutcome {
  exitCode: number;
  message?: string;
  errorMessage?: string;
  /** Workspace-relative path a write primitive created (e.g. scaffold-feature). */
  featurePath?: string;
  outputPath?: string;
}
type WriteFn = (
  bindings: StepBindings,
  deps: StepExecutorDeps
) => WriteActionOutcome | Promise<WriteActionOutcome>;

export interface ActionResult {
  action: Action;
  status: "success" | "skipped" | "failed";
  exitCode: number;
  diagnostics: Diagnostic[];
  /** Populated by write primitives that produce a typed path (scaffold-feature). */
  featurePath?: string;
  outputPath?: string;
}

export interface StepResult {
  stepId: string;
  ok: boolean;
  exitCode: number;
  diagnostics: Diagnostic[];
  actionResults: ActionResult[];
}

export interface StepExecutorDeps {
  agentRunner: AgentRunner;
  loadRunnerConfig: typeof loadRunnerConfig;
  resolveRunnerPhase: typeof resolveRunnerPhase;
  buildSessionPrompt: typeof buildSessionPrompt;
  context: Record<string, SessionContextBuilder>;
  /** Class-list context builders for project-level sessions (D4), keyed by skill name. */
  classListContext?: Record<string, ClassListContextBuilder>;
  sync: Record<string, SyncFn>;
  readiness: Record<string, ReadinessFn>;
  write: Record<string, WriteFn>;
  /** Ports consumed by interactive write primitives (scaffold-feature). */
  projectGit: ProjectGitPort;
  interaction?: InteractionPort;
  clock?: ScaffoldClock;
  emit?: (line: string) => void;
}

export const defaultStepExecutorDeps: StepExecutorDeps = {
  agentRunner: { run: async () => ({ exitCode: 0 }) },
  loadRunnerConfig,
  resolveRunnerPhase,
  buildSessionPrompt,
  context: {
    "task-to-br": (featurePath, cwd) => buildTaskToBrContext(featurePath, cwd),
    "repo-br-scan": (featurePath, cwd) => buildRepoBrScanContext(featurePath, cwd),
    "br-clarification": (featurePath, cwd) => buildBrClarificationContext(featurePath, cwd),
    "requirements-ears": (featurePath, cwd) => buildRequirementsEarsContext(featurePath, cwd),
    "ears-review": (featurePath, cwd) => buildEarsReviewContext(featurePath, cwd),
    "contract-delta": (featurePath, cwd) => buildContractDeltaContext(featurePath, cwd),
    "surface-map": (featurePath, cwd, klass) => buildSurfaceMapContext(featurePath, klass!, cwd),
    "agents-md": (projectPath, cwd, klass) => buildAgentsMdContext(projectPath, klass!, cwd),
    "surface-map-enrich": (featurePath, cwd) => buildSurfaceMapEnrichContext(featurePath, cwd),
    "technical-requirements": (featurePath, cwd) =>
      buildTechnicalRequirementsContext(featurePath, cwd),
    "implementation-slices": (featurePath, cwd) =>
      buildImplementationSlicesContext(featurePath, cwd),
    "prerequisite-gaps": (featurePath, cwd) => buildPrerequisiteGapsContext(featurePath, cwd),
    "implementation-plan": (featurePath, cwd) => buildImplementationPlanContext(featurePath, cwd),
    "plan-semantic-review": (featurePath, cwd) => buildPlanSemanticReviewContext(featurePath, cwd),
    "stack-blueprint": (projectPath, cwd, klass) =>
      buildStackBlueprintContext(projectPath, klass!, cwd)
  },
  classListContext: {
    "contract-reconciliation": (projectPath, classes, cwd) =>
      buildContractReconciliationContext(projectPath, classes, cwd),
    "common-contract": (projectPath, classes, cwd) =>
      buildCommonContractInitContext(projectPath, classes, cwd)
  },
  sync: {
    "repo-br-scan": (featurePath, cwd) => syncRepoBrScanStep(featurePath, cwd),
    "contract-delta": (featurePath, cwd) => syncContractDeltaStep(featurePath, cwd),
    "surface-map": (featurePath, cwd, klass) => syncSurfaceMapStep(featurePath, klass!, cwd),
    "prerequisite-gaps": (featurePath, cwd) => syncPrerequisiteGapsStep(featurePath, cwd)
  },
  readiness: {
    "br-clarification-readiness": (featurePath, cwd) =>
      runBrClarificationReadiness(featurePath, cwd)
  },
  projectGit: new RepoGitProjectAdapter(),
  write: {
    "scaffold-feature": async (bindings, deps) => {
      if (!deps.interaction || !deps.clock || !deps.projectGit || !bindings.projectPath) {
        return {
          exitCode: 2,
          errorMessage:
            "scaffold-feature requires interaction, clock, projectGit, and a project binding; wire them before dispatching step 3."
        };
      }
      const result = await scaffoldFeature(bindings.runtimeRoot, bindings.projectPath, {
        interaction: deps.interaction,
        clock: deps.clock,
        projectGit: deps.projectGit,
        ...(deps.emit ? { emit: deps.emit } : {})
      });
      if (!result.featurePath || result.diagnostics.length > 0) {
        return {
          exitCode: 2,
          errorMessage:
            result.diagnostics.map((diagnostic) => diagnostic.reason).join("; ") ||
            "scaffold-feature produced no feature path."
        };
      }
      return {
        exitCode: 0,
        featurePath: result.featurePath,
        ...(result.outputPath ? { outputPath: result.outputPath } : {})
      };
    }
  }
};

/** Reason for a checkpoint boundary is orchestrator policy; the executor only dispatches actions. */

export async function executeStep(
  stepDef: StepDefinition,
  bindings: StepBindings,
  deps: StepExecutorDeps
): Promise<StepResult> {
  const actionResults: ActionResult[] = [];
  const diagnostics: Diagnostic[] = [];

  for (const action of stepDef.actions) {
    const result =
      action.kind === "session"
        ? await executeSessionAction(action, bindings, deps)
        : await executeDeterministicAction(action, bindings, deps);
    actionResults.push(result);
    diagnostics.push(...result.diagnostics);
    if (result.status === "failed") {
      return {
        stepId: stepDef.id,
        ok: false,
        exitCode: result.exitCode,
        diagnostics,
        actionResults
      };
    }
  }

  return {
    stepId: stepDef.id,
    ok: true,
    exitCode: 0,
    diagnostics,
    actionResults
  };
}

async function executeSessionAction(
  action: Extract<Action, { kind: "session" }>,
  bindings: StepBindings,
  deps: StepExecutorDeps
): Promise<ActionResult> {
  const diagnostics: Diagnostic[] = [];

  if (action.runIf === "hasReadyClassRepo" && !hasReadyClassRepo(bindings)) {
    diagnostics.push({
      severity: "warning",
      source: "step-executor",
      reason: `Skipped ${action.skillName}: runIf predicate 'hasReadyClassRepo' evaluated false.`
    });
    return { action, status: "skipped", exitCode: 0, diagnostics };
  }

  if (action.requiresSync) {
    const syncFn = deps.sync[action.skillName];
    if (!syncFn) {
      diagnostics.push(unknownActionDiagnostic("sync", action.skillName));
      return { action, status: "failed", exitCode: 2, diagnostics };
    }
    const syncResult = syncFn(bindings.featurePath, bindings.runtimeRoot, bindings.targetClass);
    if (syncResult.exitCode !== 0) {
      diagnostics.push(resultDiagnostic("sync", action.skillName, syncResult));
      return { action, status: "failed", exitCode: syncResult.exitCode, diagnostics };
    }
  }

  // The context result is consumed only by from-context read-only guards, so build it before the
  // session only when the action declares such a guard; otherwise the pre-call is dead work and,
  // for skills that own their own capture loop (task-to-br), a circular precondition. Project-level
  // class-list sessions (D4) are the exception: their builder validates the class->repo bindings
  // before launch, so keep the pre-call whenever a class-list builder is registered for the skill.
  const needsContext =
    action.readOnlyGuards.some((guard) => guard.mode === "fromContext") ||
    deps.classListContext?.[action.skillName] !== undefined;
  let resolvedFromContext: string[] = [];
  if (needsContext) {
    const classListFn = deps.classListContext?.[action.skillName];
    let contextResult: ContextResult;
    if (classListFn) {
      const projectAbs = path.join(bindings.runtimeRoot, bindings.featurePath);
      contextResult = classListFn(projectAbs, bindings.classes ?? [], bindings.runtimeRoot);
    } else {
      const contextFn = deps.context[action.skillName];
      if (!contextFn) {
        diagnostics.push(unknownActionDiagnostic("context", action.skillName));
        return { action, status: "failed", exitCode: 2, diagnostics };
      }
      contextResult = contextFn(bindings.featurePath, bindings.runtimeRoot, bindings.targetClass);
    }
    if (contextResult.exitCode !== 0) {
      diagnostics.push(resultDiagnostic("context", action.skillName, contextResult));
      return { action, status: "failed", exitCode: contextResult.exitCode, diagnostics };
    }
    resolvedFromContext = resolveContextReadOnlyInputs(contextResult, bindings);
  }

  const loadedConfig = deps.loadRunnerConfig(resolveModelsPath(bindings));
  const resolvedConfig = deps.resolveRunnerPhase(loadedConfig, action.modelPhase);
  if (!resolvedConfig.config) {
    diagnostics.push(...resolvedConfig.diagnostics);
    return { action, status: "failed", exitCode: 2, diagnostics };
  }

  let prompt: string;
  try {
    prompt = deps.buildSessionPrompt(action, bindings);
  } catch {
    diagnostics.push(buildUnknownPromptRecipeDiagnostic(action.skillName));
    return { action, status: "failed", exitCode: 2, diagnostics };
  }

  diagnostics.push(
    ...validateReadOnlyGuardsBeforeSession(action.readOnlyGuards, resolvedFromContext)
  );
  if (diagnostics.some((item) => item.severity === "error")) {
    return { action, status: "failed", exitCode: 2, diagnostics };
  }

  const snapshot = snapshotReadOnlyGuards(action.readOnlyGuards, resolvedFromContext, (files) =>
    resolveGuardPaths(files, {
      runtimeRoot: bindings.runtimeRoot,
      featurePath: bindings.featurePath,
      targetClass: bindings.targetClass
    })
  );

  const agentResult = await deps.agentRunner.run({
    command: resolvedConfig.config.command,
    model: resolvedConfig.config.model,
    args: resolvedConfig.config.args,
    prompt,
    cwd: bindings.runtimeRoot
  });

  diagnostics.push(...verifyReadOnlyGuards(snapshot));

  if (agentResult.exitCode === 0) {
    diagnostics.push(
      ...assertRequiredOutputs(
        resolveActionOutputPaths(action, {
          runtimeRoot: bindings.runtimeRoot,
          featurePath: bindings.featurePath,
          targetClass: bindings.targetClass
        })
      )
    );
  } else {
    diagnostics.push({
      severity: "error",
      source: "agent-runner",
      reason: agentResult.errorMessage
        ? `Agent failed for skill '${action.skillName}': ${agentResult.errorMessage}`
        : `Agent exited with code ${agentResult.exitCode} for skill '${action.skillName}'.`
    });
  }

  const failed =
    agentResult.exitCode !== 0 || diagnostics.some((item) => item.severity === "error");
  return {
    action,
    status: failed ? "failed" : "success",
    exitCode: failed ? (agentResult.exitCode === 0 ? 2 : agentResult.exitCode) : 0,
    diagnostics
  };
}

async function executeDeterministicAction(
  action: Extract<Action, { kind: "check" | "write" }>,
  bindings: StepBindings,
  deps: StepExecutorDeps
): Promise<ActionResult> {
  if (action.kind === "check") {
    const readinessFn = deps.readiness[action.name];
    if (!readinessFn) {
      return {
        action,
        status: "failed",
        exitCode: 2,
        diagnostics: [unknownActionDiagnostic("check", action.name)]
      };
    }
    const result = readinessFn(bindings.featurePath, bindings.runtimeRoot);
    if (result.exitCode !== 0) {
      return {
        action,
        status: "failed",
        exitCode: result.exitCode,
        diagnostics: [resultDiagnostic("check", action.name, result)]
      };
    }
    return { action, status: "success", exitCode: 0, diagnostics: [] };
  }

  const writeFn = deps.write[action.name];
  if (!writeFn) {
    return {
      action,
      status: "failed",
      exitCode: 2,
      diagnostics: [unknownActionDiagnostic("write", action.name)]
    };
  }
  const result = await writeFn(bindings, deps);
  if (result.exitCode !== 0) {
    return {
      action,
      status: "failed",
      exitCode: result.exitCode,
      diagnostics: [resultDiagnostic("write", action.name, result)]
    };
  }
  return {
    action,
    status: "success",
    exitCode: 0,
    diagnostics: [],
    ...(result.featurePath ? { featurePath: result.featurePath } : {}),
    ...(result.outputPath ? { outputPath: result.outputPath } : {})
  };
}

function resolveContextReadOnlyInputs(
  contextResult: ContextResult,
  bindings: StepBindings
): string[] {
  return (contextResult.readOnlyInputs ?? []).map((candidate) =>
    path.isAbsolute(candidate) ? candidate : path.join(bindings.runtimeRoot, candidate)
  );
}

function hasReadyClassRepo(bindings: StepBindings): boolean {
  const definitionPath = path.join(
    resolveProjectAbsolutePath(bindings),
    "init_progress_definition.yaml"
  );
  const readyRepos = collectReadyRepoPaths(definitionPath);
  return bindings.targetClass
    ? readyRepos.some((repo) => repo.class === bindings.targetClass)
    : readyRepos.length > 0;
}

function unknownActionDiagnostic(kind: string, name: string): Diagnostic {
  return {
    severity: "error",
    source: "step-executor",
    reason: `Unknown ${kind} action '${name}'.`
  };
}

function resultDiagnostic(
  source: string,
  name: string,
  result: { errorMessage?: string; problems?: string[]; blockedMessages?: string[] }
): Diagnostic {
  const detail =
    result.errorMessage ??
    result.problems?.join("; ") ??
    result.blockedMessages?.join("; ") ??
    "Action failed.";
  return {
    severity: "error",
    source: `step-executor:${source}`,
    reason: `${name}: ${detail}`
  };
}
