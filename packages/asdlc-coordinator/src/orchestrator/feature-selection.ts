import { readdirSync, statSync } from "node:fs";
import path from "node:path";

import { InteractionClosedError, type InteractionPort } from "../interaction/index.js";
import { evaluate, nextStep } from "../sequencing/index.js";
import { readFeatureState, writeFeatureState } from "../state/index.js";
import type { Diagnostic } from "../types/index.js";
import { TERMINAL_REPAIR_STEPS } from "../validate/gate-registry.js";

export interface DiscoveredFeature {
  /** Workspace-relative feature path. */
  featurePath: string;
  /** Absolute feature directory. */
  featureDir: string;
  /** `next step: <id> (<name>)` style line; only set for unfinished features. */
  nextStepLine?: string;
  unfinished: boolean;
}

export type FeatureTargetDecision =
  | { kind: "startNew" }
  | { kind: "continue"; featurePath: string }
  | { kind: "resumeCompleted"; featurePath: string }
  | { kind: "stop" }
  | { kind: "fail"; diagnostics: Diagnostic[] };

export interface FeatureSelectionDeps {
  workspaceRoot: string;
  projectRoot: string;
  projectPathRel: string;
  /** Resolved catalog step id from `--resume`, or undefined. */
  resumeStepId?: string;
  interaction: InteractionPort;
  emit: (line: string) => void;
}

/**
 * Evaluate every feature child of the project and retain the ones with a typed
 * remaining required step (`nextStep`). Optional-only remainders read as
 * finished, exactly like the shell scanner's `next step: none`.
 */
export function discoverProjectFeatures(
  workspaceRoot: string,
  projectRoot: string
): DiscoveredFeature[] {
  let entries: string[];
  try {
    entries = readdirSync(projectRoot, { withFileTypes: true })
      .filter((entry) => entry.isDirectory() && !entry.name.startsWith("."))
      .map((entry) => path.join(projectRoot, entry.name))
      .sort();
  } catch {
    return [];
  }
  return entries
    .filter((featureDir) => {
      try {
        return statSync(featureDir).isDirectory();
      } catch {
        return false;
      }
    })
    .map((featureDir) => {
      const report = evaluate(workspaceRoot, projectRoot, featureDir);
      const next = nextStep(report);
      const featurePath = path.relative(workspaceRoot, featureDir);
      return next
        ? {
            featurePath,
            featureDir,
            unfinished: true,
            nextStepLine: `next step: ${next.stepId} (${next.name})`
          }
        : { featurePath, featureDir, unfinished: false };
    });
}

/**
 * Resolve the run's feature target: new-vs-continue menus, resume constraints,
 * and completed-cache reopening for an explicit terminal repair resume. Routes
 * every choice through the interaction port and persists a selected unfinished
 * feature.
 */
export async function resolveFeatureTarget(
  deps: FeatureSelectionDeps
): Promise<FeatureTargetDecision> {
  const { workspaceRoot, projectRoot, resumeStepId, emit } = deps;

  const cache = readFeatureState(workspaceRoot, projectRoot);
  for (const notice of cache.notices) emit(notice);
  if (cache.state === "valid" && cache.featurePath) {
    emit(`Loaded saved feature_path cache: ${cache.featurePath}`);
  }

  const features = discoverProjectFeatures(workspaceRoot, projectRoot);
  const unfinished = features.filter((feature) => feature.unfinished);

  // Artifact-presence scanning calls this feature complete, but terminal gate
  // validation can still fail it (CRP-166 D7). An explicit `--resume` naming a
  // step that owns a terminal repair is the operator's authorization to reopen
  // the cached feature at that phase. `readFeatureState` only reports `valid`
  // for a path that still resolves inside this project, so existence is settled.
  const repairableCachedFeature =
    resumeStepId &&
    TERMINAL_REPAIR_STEPS.includes(resumeStepId) &&
    cache.state === "valid" &&
    cache.featurePath &&
    !unfinished.some((feature) => feature.featurePath === cache.featurePath)
      ? cache.featurePath
      : undefined;

  try {
    if (unfinished.length > 0) {
      // Terminal failure is not persisted, so the coordinator cannot tell an
      // intended repair of the completed cached feature from an intended
      // continue of an unfinished one. Offer both and let the operator say.
      return await selectFromUnfinished(unfinished, repairableCachedFeature, deps);
    }

    if (repairableCachedFeature) {
      emit(
        `Reopening completed cached feature at explicit repair step ${resumeStepId}: ${repairableCachedFeature}`
      );
      return { kind: "resumeCompleted", featurePath: repairableCachedFeature };
    }

    if (resumeStepId && resumeStepId !== "3") {
      return {
        kind: "fail",
        diagnostics: [
          {
            severity: "error",
            source: "feature-selection",
            reason:
              "No unfinished feature and no valid completed-feature cache to reopen for this project. Repairing a completed feature requires its cached feature_path; otherwise run without --resume, or use --resume 3 to start a new feature."
          }
        ]
      };
    }

    printNoUnfinishedMessage(features, cache.featurePath, deps);
    return { kind: "startNew" };
  } catch (error) {
    if (error instanceof InteractionClosedError) {
      emit("Execution stopped: user input stream closed during feature selection.");
      return { kind: "stop" };
    }
    throw error;
  }
}

async function selectFromUnfinished(
  unfinished: DiscoveredFeature[],
  repairableCachedFeature: string | undefined,
  deps: FeatureSelectionDeps
): Promise<FeatureTargetDecision> {
  const { projectRoot, projectPathRel, resumeStepId, interaction, emit } = deps;

  emit(`Project feature selection for: ${projectPathRel}`);
  emit(`Found unfinished features: ${unfinished.length}`);
  if (repairableCachedFeature) {
    emit(`Completed cached feature available for repair: ${repairableCachedFeature}`);
  }

  for (;;) {
    const mode = await interaction.select({
      message: "Project feature options:",
      options: [
        { value: "new", label: "Start a new feature" },
        { value: "continue", label: "Continue an existing unfinished feature" }
      ]
    });

    if (mode === "new") {
      if (resumeStepId && resumeStepId !== "3") {
        emit(
          `Cannot start a new feature with --resume resolving to ${resumeStepId}. Choose continue or rerun without --resume.`
        );
        continue;
      }
      emit(`Starting a new feature under project: ${projectPathRel}`);
      return { kind: "startNew" };
    }

    // mode === "continue"
    if (resumeStepId === "3") {
      emit(
        "Cannot continue an existing feature with --resume 3. Choose start new or rerun without --resume."
      );
      continue;
    }

    const selected = await interaction.select({
      message: repairableCachedFeature ? "Choose feature:" : "Choose unfinished feature:",
      options: [
        ...unfinished.map((feature) => ({
          value: feature.featurePath,
          label: `${feature.featurePath} [${feature.nextStepLine}]`
        })),
        ...(repairableCachedFeature
          ? [
              {
                value: repairableCachedFeature,
                label: `${repairableCachedFeature} [completed; reopen for repair at step ${resumeStepId}]`
              }
            ]
          : [])
      ]
    });

    // The cache already points at the completed feature, so reopening it needs
    // no write; only an unfinished selection changes the remembered target.
    if (selected === repairableCachedFeature) {
      emit(
        `Reopening completed cached feature at explicit repair step ${resumeStepId}: ${selected}`
      );
      return { kind: "resumeCompleted", featurePath: selected };
    }
    persistFeatureState(projectRoot, selected, emit);
    return { kind: "continue", featurePath: selected };
  }
}

function printNoUnfinishedMessage(
  features: DiscoveredFeature[],
  cachedFeaturePath: string | undefined,
  deps: FeatureSelectionDeps
): void {
  const { emit, projectPathRel } = deps;
  emit(`Examined project features for: ${projectPathRel}`);
  if (
    cachedFeaturePath &&
    !features.some((feature) => feature.unfinished && feature.featurePath === cachedFeaturePath)
  ) {
    emit(`Last selected feature is already complete: ${cachedFeaturePath}`);
  } else if (features.length > 0) {
    emit(`Examined ${features.length} existing feature folder(s); all are already complete.`);
  } else {
    emit("No existing feature folders were found for this project.");
  }
  emit("No unfinished features are available to continue.");
  emit("Would you like to start a new feature? Confirm the scaffold step below.");
}

/**
 * Persist the feature-state cache and report honestly: emit "Saved feature_path"
 * only on a successful write; on failure emit the diagnostics and a continuing
 * notice. The cache is a convenience (D4), so the run proceeds either way — but it
 * must never claim a save that did not happen.
 */
export function persistFeatureState(
  projectRoot: string,
  featurePath: string,
  emit: (line: string) => void
): void {
  const write = writeFeatureState(projectRoot, featurePath);
  if (write.ok) {
    emit(`Saved feature_path: ${featurePath}`);
    return;
  }
  for (const diagnostic of write.diagnostics) emit(diagnostic.reason);
  emit(`Continuing without a persisted feature-state cache: ${featurePath}`);
}
