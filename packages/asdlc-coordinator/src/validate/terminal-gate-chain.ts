import { existsSync, realpathSync, statSync } from "node:fs";
import path from "node:path";

import { resolveInputPath } from "../parse/markdown.js";
import { collectReadyRepoPaths } from "../repo/collect-ready-paths.js";
import type { Diagnostic, GateExitCode, GateResult } from "../types/index.js";
import { detectRuntimeRoot } from "../workspace/index.js";

import {
  GATE_REGISTRY,
  SURFACE_MAP_CLASSES,
  TERMINAL_FEATURE_GATES,
  type GateValidator,
  type TerminalGateDefinition
} from "./gate-registry.js";
import type { SurfaceMapClass } from "./surface-map.js";

/** One expanded terminal chain entry and what happened to it. */
export interface TerminalGateEntry {
  order: number;
  gate: string;
  /** Feature-relative trigger artifact, with `<class>` already expanded. */
  artifact: string;
  klass?: SurfaceMapClass;
  repairStep: string;
  status: "passed" | "failed" | "skipped";
  /** Why an inapplicable entry was skipped. */
  skipReason?: string;
  /** Underlying validator result; absent for skipped entries. */
  result?: GateResult;
}

export interface TerminalGateChainResult {
  exitCode: GateExitCode;
  entries: TerminalGateEntry[];
  diagnostics: Diagnostic[];
  /** Earliest failing pipeline entry's owning catalog step, if any failed. */
  repairStep?: string;
  passed: number;
  failed: number;
  skipped: number;
}

/** Injectable chain runner seam for the CLI and the feature flow. */
export type TerminalGateChainRunner = (featurePath: string, cwd: string) => TerminalGateChainResult;

const SOURCE = "terminal-gate-chain";

/**
 * Run every applicable deterministic feature gate for one feature (CRP-166 D2,
 * D3). Applicability comes from trigger-artifact existence plus declared
 * pipeline predicates; the chain never fails fast, makes no writes, and supplies
 * no progress sink, so the aggregate reports complete evidence without the
 * standalone clarification-loop chatter.
 */
export function runTerminalGateChain(
  featurePath: string,
  cwd: string = process.cwd(),
  options: { registry?: Record<string, GateValidator> } = {}
): TerminalGateChainResult {
  const registry = options.registry ?? GATE_REGISTRY;
  const resolved = resolveTerminalFeature(featurePath, cwd);
  if (!resolved.ok) return pathFailure(resolved.message);

  const { workspaceRoot, featureDir, projectRoot } = resolved.value;

  const entries: TerminalGateEntry[] = [];
  for (const definition of TERMINAL_FEATURE_GATES) {
    for (const expanded of expandDefinition(definition)) {
      entries.push(evaluateEntry(expanded, { workspaceRoot, featureDir, projectRoot }, registry));
    }
  }

  const applicable = entries.filter((entry) => entry.status !== "skipped");
  if (applicable.length === 0) {
    return {
      ...counts(entries),
      entries,
      exitCode: 2,
      diagnostics: [
        {
          severity: "error",
          source: SOURCE,
          reason: `No deterministic feature artifact was validated under ${featureDir}.`
        }
      ]
    };
  }

  const failures = entries.filter((entry) => entry.status === "failed");
  const exitCode: GateExitCode =
    failures.length === 0 ? 0 : failures.some((entry) => entry.result?.exitCode === 2) ? 2 : 1;

  return {
    ...counts(entries),
    entries,
    exitCode,
    diagnostics: failures.map(failureDiagnostic),
    // Severity never reorders repair ownership: the earliest failing pipeline
    // phase is where an operator has to start regardless of which failure is
    // blocking versus recoverable.
    ...(failures.length > 0 ? { repairStep: failures[0]!.repairStep } : {})
  };
}

interface TerminalFeature {
  workspaceRoot: string;
  featureDir: string;
  projectRoot: string;
}

/**
 * Resolve the input to `projects/<project-id>/<feature-folder>` inside an ASDLC
 * workspace. The workspace root is detected from the feature itself so gates
 * receive the runtime root their own path rules expect, independent of where the
 * operator invoked the CLI.
 */
function resolveTerminalFeature(
  featurePath: string,
  cwd: string
): { ok: true; value: TerminalFeature } | { ok: false; message: string } {
  if (!featurePath || featurePath.trim() === "") {
    return { ok: false, message: "Missing feature path." };
  }
  const candidate = resolveInputPath(featurePath, cwd);
  let featureDir: string;
  try {
    if (!statSync(candidate).isDirectory()) throw new Error("not a directory");
    featureDir = realpathSync(candidate);
  } catch {
    return { ok: false, message: `Feature path directory not found: ${featurePath}` };
  }
  const workspace = detectRuntimeRoot(featureDir);
  if (!workspace.path) {
    return {
      ok: false,
      message: `Feature path is not inside an ASDLC workspace: ${featurePath}`
    };
  }
  const workspaceRoot = workspace.path;
  const relativeFeature = path.relative(workspaceRoot, featureDir);
  const parts = relativeFeature.split(path.sep);
  if (parts.length !== 3 || parts[0] !== "projects" || !parts[1] || !parts[2]) {
    return {
      ok: false,
      message: `Feature path must resolve under projects/<project-id>/<feature-folder>: ${relativeFeature}`
    };
  }
  return {
    ok: true,
    value: {
      workspaceRoot,
      featureDir,
      projectRoot: path.join(workspaceRoot, "projects", parts[1])
    }
  };
}

/** Expand a definition into its concrete entries (one, or one per class). */
function expandDefinition(
  definition: TerminalGateDefinition
): Array<TerminalGateDefinition & { klass?: SurfaceMapClass }> {
  if (!definition.classExpanded) return [definition];
  return SURFACE_MAP_CLASSES.map((klass) => ({
    ...definition,
    klass,
    artifact: definition.artifact.replace("<class>", klass)
  }));
}

function evaluateEntry(
  definition: TerminalGateDefinition & { klass?: SurfaceMapClass },
  feature: TerminalFeature,
  registry: Record<string, GateValidator>
): TerminalGateEntry {
  const base: TerminalGateEntry = {
    order: definition.order,
    gate: definition.gate,
    artifact: definition.artifact,
    repairStep: definition.repairStep,
    status: "skipped",
    ...(definition.klass ? { klass: definition.klass } : {})
  };

  // Existence alone decides applicability. A path that exists as a directory or
  // another invalid entry type is applicable and its owning validator classifies
  // it, so a malformed artifact is never reported as absent.
  if (!existsSync(path.join(feature.featureDir, definition.artifact))) {
    return { ...base, skipReason: `${definition.artifact} not found` };
  }

  if (definition.predicate === "hasReadyClassRepo") {
    const ready = hasReadyClassRepo(feature.projectRoot);
    if (ready.error) return { ...base, status: "failed", result: gateError(ready.error) };
    if (!ready.value) {
      return { ...base, skipReason: "no project class repository is in state ready" };
    }
  }

  const validator: GateValidator | undefined = registry[definition.gate];
  if (!validator) {
    return {
      ...base,
      status: "failed",
      result: gateError(`Gate '${definition.gate}' is not registered.`)
    };
  }

  let result: GateResult;
  try {
    result = validator({
      featurePath: feature.featureDir,
      runtimeRoot: feature.workspaceRoot,
      ...(definition.klass ? { klass: definition.klass } : {})
    });
  } catch (error) {
    return {
      ...base,
      status: "failed",
      result: gateError(
        `Gate '${definition.gate}' could not run: ${
          error instanceof Error ? error.message : String(error)
        }`
      )
    };
  }

  return { ...base, status: result.exitCode === 0 ? "passed" : "failed", result };
}

/**
 * Evaluate the catalog's step 4.1 execution condition from the current project
 * definition. A repository attached after BR scanning therefore makes
 * `repo-br-scan` applicable again, which is the point: the newly available
 * repository evidence has to reach `feature_br_summary.md` before completion.
 */
function hasReadyClassRepo(projectRoot: string): { value: boolean; error?: string } {
  const definitionPath = path.join(projectRoot, "init_progress_definition.yaml");
  try {
    return { value: collectReadyRepoPaths(definitionPath).length > 0 };
  } catch (error) {
    return { value: false, error: error instanceof Error ? error.message : String(error) };
  }
}

function failureDiagnostic(entry: TerminalGateEntry): Diagnostic {
  const scope = entry.klass ? `${entry.gate} (${entry.klass})` : entry.gate;
  const detail =
    entry.result?.exitCode === 2
      ? (entry.result.errorMessage ?? "gate runtime error")
      : (entry.result?.problems.join("; ") ?? "gate failed");
  return {
    severity: "error",
    source: `${SOURCE}:${scope}`,
    reason: `${entry.artifact}: ${detail}`,
    stepId: entry.repairStep
  };
}

function counts(entries: TerminalGateEntry[]): {
  passed: number;
  failed: number;
  skipped: number;
} {
  return {
    passed: entries.filter((entry) => entry.status === "passed").length,
    failed: entries.filter((entry) => entry.status === "failed").length,
    skipped: entries.filter((entry) => entry.status === "skipped").length
  };
}

function pathFailure(message: string): TerminalGateChainResult {
  return {
    exitCode: 2,
    entries: [],
    diagnostics: [{ severity: "error", source: SOURCE, reason: message }],
    passed: 0,
    failed: 0,
    skipped: 0
  };
}

function gateError(errorMessage: string): GateResult {
  return { exitCode: 2, passMessage: "", problems: [], errorMessage };
}
