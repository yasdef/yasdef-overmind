import { existsSync, readFileSync } from "node:fs";
import path from "node:path";

import { readProjectDefinitionMetadata } from "../parse/project-definition.js";
import type { Diagnostic } from "../types/index.js";
import { parseDeclaredSteps, type ArtifactCheck } from "./definition.js";
import { STEP_CATALOG } from "./step-catalog.js";

export type StepState = "done" | "pending" | "blocked";

export interface PerClassProgress {
  className: string;
  repoState?: "ready" | "deferred";
  state: "done" | "pending";
  missingArtifacts: string[];
}

export interface StepProgress {
  stepId: string;
  name: string;
  scope: "project" | "feature";
  optional: boolean;
  state: StepState;
  perClass?: PerClassProgress[];
  missingArtifacts: string[];
}

export interface ProgressReport {
  workspaceRoot: string;
  projectRoot: string;
  featureRoot?: string;
  featureTitle: string;
  definitionParsed: boolean;
  steps: StepProgress[];
  diagnostics: Diagnostic[];
}

const FALLBACK_FEATURE_TITLE = "<feature not initialized>";

function resolveArtifact(
  projectRoot: string,
  featureRoot: string | undefined,
  stepPhase: "init" | "feature",
  artifact: ArtifactCheck
): string {
  if (stepPhase === "init") return path.join(projectRoot, artifact.file);
  const normalized = artifact.specialFolder?.replace(/^\/+|\/+$/g, "");
  if (normalized === "product" || normalized === "overmind/product") {
    return path.join(featureRoot ?? projectRoot, artifact.file);
  }
  return path.join(normalized ? path.join(projectRoot, normalized) : projectRoot, artifact.file);
}

function scopedValue(content: string, section: string, key: string): string | undefined {
  const lines = content.split(/\r?\n/);
  const start = lines.findIndex((line) => line.trim() === section.trim());
  if (start < 0) return undefined;
  const level = section.trim().match(/^#+/)?.[0].length ?? 0;
  for (const line of lines.slice(start + 1)) {
    const heading = line.trim().match(/^(#+)/)?.[1]?.length;
    if (heading && heading <= level) break;
    const match = line
      .trim()
      .replace(/^-\s*/, "")
      .match(/^([A-Za-z0-9_.-]+):\s*(.*?)\s*(?:#.*)?$/);
    if (match?.[1] === key) {
      const value = match[2]!.trim();
      return (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
        ? value.slice(1, -1)
        : value;
    }
  }
  return undefined;
}

function featureTitle(featureRoot: string | undefined): string {
  if (!featureRoot) return FALLBACK_FEATURE_TITLE;
  try {
    const content = readFileSync(path.join(featureRoot, "feature_br_summary.md"), "utf8");
    return scopedValue(content, "## 1. Document Meta", "feature_title") || FALLBACK_FEATURE_TITLE;
  } catch {
    return FALLBACK_FEATURE_TITLE;
  }
}

function isRequired(
  artifact: ArtifactCheck,
  projectTypeCode: string | undefined,
  classes: string[]
): boolean {
  if (artifact.projectTypeCode && artifact.projectTypeCode !== projectTypeCode) return false;
  if (
    artifact.projectClassesAnyOf &&
    !artifact.projectClassesAnyOf.some((klass) => classes.includes(klass))
  )
    return false;
  return true;
}

export function evaluate(
  workspaceRoot: string,
  projectRoot: string,
  featureRoot?: string
): ProgressReport {
  const definitionPath = path.join(projectRoot, "init_progress_definition.yaml");
  const declared = parseDeclaredSteps(definitionPath);
  const metadata = readProjectDefinitionMetadata(definitionPath);
  const diagnostics = [...declared.diagnostics, ...metadata.diagnostics];
  const definitions = declared.parsed
    ? declared.steps
    : STEP_CATALOG.map((step) => ({
        id: step.id,
        name: step.label,
        phase:
          step.id === "1" || step.id === "1.1" || step.id === "2"
            ? ("init" as const)
            : ("feature" as const),
        optional: step.optional,
        artifacts: []
      }));

  const catalogIds = STEP_CATALOG.map((step) => step.id);
  const declaredIds = definitions.map((step) => step.id);
  const definitionMatchesCatalog =
    !declared.parsed ||
    (catalogIds.length === declaredIds.length &&
      catalogIds.every((id, index) => id === declaredIds[index]));
  if (!definitionMatchesCatalog) {
    diagnostics.push({
      severity: "error",
      source: definitionPath,
      reason: "Declared step ids do not match the sequencing catalog."
    });
  }

  const steps: StepProgress[] = definitions.map((step) => {
    const applicable = step.artifacts.filter((artifact) =>
      isRequired(artifact, metadata.projectTypeCode, metadata.projectClasses)
    );
    const missingArtifacts: string[] = [];
    let unreadable = false;
    let matched = 0;
    for (const artifact of applicable) {
      const artifactPath = resolveArtifact(projectRoot, featureRoot, step.phase, artifact);
      if (!existsSync(artifactPath)) {
        missingArtifacts.push(artifactPath);
        continue;
      }
      if (!artifact.checkKeyValue) {
        matched += 1;
        continue;
      }
      try {
        const content = readFileSync(artifactPath, "utf8");
        if (
          scopedValue(content, artifact.checkKeyValue.section, artifact.checkKeyValue.key) ===
          artifact.checkKeyValue.equals
        )
          matched += 1;
        else missingArtifacts.push(artifactPath);
      } catch (error) {
        unreadable = true;
        missingArtifacts.push(artifactPath);
        diagnostics.push({
          severity: "error",
          source: artifactPath,
          reason: `Unable to evaluate completion artifact: ${error instanceof Error ? error.message : String(error)}`,
          stepId: step.id
        });
      }
    }
    const done =
      declared.parsed &&
      (applicable.length === 0 ||
        (step.id === "7.1" ? matched > 0 : matched === applicable.length));
    const needsMetadata = step.artifacts.some(
      (artifact) => artifact.projectTypeCode || artifact.projectClassesAnyOf
    );
    return {
      stepId: step.id,
      name: step.name,
      scope: step.phase === "init" ? "project" : "feature",
      optional: step.optional,
      state: done
        ? "done"
        : !declared.parsed || unreadable || (needsMetadata && !metadata.parsed)
          ? "blocked"
          : "pending",
      missingArtifacts: [...new Set(missingArtifacts)]
    };
  });

  const projectPrerequisitePending = steps.some(
    (step) => step.scope === "project" && !step.optional && step.state !== "done"
  );
  if (projectPrerequisitePending) {
    for (const step of steps) {
      if (step.scope === "feature" && step.state === "pending") step.state = "blocked";
    }
  }

  const stepSeven = steps.find((step) => step.stepId === "7");
  if (stepSeven) {
    stepSeven.perClass = metadata.projectClasses.map((className) => {
      const artifactPath = path.join(
        featureRoot ?? projectRoot,
        `project_surface_struct_resp_map_${className}.md`
      );
      const done = existsSync(artifactPath);
      return {
        className,
        repoState: metadata.classRepoPaths[className]?.state,
        state: done ? "done" : "pending",
        missingArtifacts: done ? [] : [artifactPath]
      };
    });
  }

  return {
    workspaceRoot,
    projectRoot,
    featureRoot,
    featureTitle: featureTitle(featureRoot),
    definitionParsed: declared.parsed && metadata.parsed && definitionMatchesCatalog,
    steps,
    diagnostics
  };
}
