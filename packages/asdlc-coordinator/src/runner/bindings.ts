import path from "node:path";

import type { Action, StepDefinition } from "../sequencing/step-catalog.js";
import type { SurfaceMapClass } from "../validate/surface-map.js";

export interface SessionBindings {
  runtimeRoot: string;
  featurePath: string;
  overmindCliPath: string;
  modelsPath?: string;
  targetClass?: SurfaceMapClass;
  /**
   * Ordered class list for a project-level class-list session (D4). Empty/undefined
   * for feature and single-class sessions; the reconciliation catalog step binds the
   * full pending-class list so one generic session covers every class.
   */
  classes?: string[];
}

export interface StepBindings extends SessionBindings {
  step: StepDefinition;
  /**
   * Workspace-relative project path, set for the feature-creating step 3 whose
   * scaffold write primitive runs before any feature exists. Other steps leave
   * it undefined and operate on `featurePath`.
   */
  projectPath?: string;
}

export interface SessionTargetArtifacts {
  runtimeRoot: string;
  featurePath: string;
  targetClass?: SurfaceMapClass;
}

export function resolveModelsPath(bindings: SessionBindings): string {
  return bindings.modelsPath ?? path.join(bindings.runtimeRoot, ".setup", "models.md");
}

export function resolveFeatureAbsolutePath(bindings: SessionBindings): string {
  return path.join(bindings.runtimeRoot, bindings.featurePath);
}

export function resolveProjectAbsolutePath(bindings: SessionBindings): string {
  return path.dirname(resolveFeatureAbsolutePath(bindings));
}

export function resolveActionOutputPaths(
  action: Extract<Action, { kind: "session" }>,
  bindings: SessionTargetArtifacts
): string[] {
  return action.requiredOutputs.map((candidate) => resolveArtifactPath(candidate, bindings));
}

export function resolveGuardPaths(files: string[], bindings: SessionTargetArtifacts): string[] {
  return files.map((candidate) => resolveArtifactPath(candidate, bindings));
}

export function resolveArtifactPath(template: string, bindings: SessionTargetArtifacts): string {
  const rendered = bindings.targetClass
    ? template.replaceAll("<class>", bindings.targetClass)
    : template;
  if (rendered.startsWith(".setup/")) {
    return path.join(bindings.runtimeRoot, rendered);
  }
  return path.join(bindings.runtimeRoot, bindings.featurePath, rendered);
}
