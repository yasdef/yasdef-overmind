import type { GateResult } from "../types/index.js";

import { validateAgentsMd } from "./agents-md.js";
import { validateBrClarification } from "./br-clarification.js";
import { validateContractDelta } from "./contract-delta.js";
import {
  validateContractReconciliation,
  validateInitialCommonContract
} from "./contract-reconciliation.js";
import { validateEarsReview } from "./ears-review.js";
import { validateImplementationPlan } from "./implementation-plan.js";
import { validateImplementationSlices } from "./implementation-slices.js";
import { validatePlanSemanticReview } from "./plan-semantic-review.js";
import { validatePrerequisiteGaps } from "./prerequisite-gaps.js";
import { validateRepoBrScan } from "./repo-br-scan.js";
import { validateRequirementsEars } from "./requirements-ears.js";
import { validateStackBlueprint } from "./stack-blueprint.js";
import { validateSurfaceMap, type SurfaceMapClass } from "./surface-map.js";
import { validateTaskToBr } from "./task-to-br.js";
import { validateTechnicalRequirements } from "./technical-requirements.js";

/**
 * Inputs a registered gate validator receives (CRP-165 D2, generalized by
 * CRP-166 D1). One shape adapts the various validator signatures for standalone
 * CLI dispatch, post-session executor dispatch, and terminal-chain dispatch: the
 * feature path, the runtime root used as the resolution base, an optional
 * progress sink consumed only by the clarification loop, and the optional class
 * argument consumed only by class-scoped gates.
 */
export interface GateInvocation {
  featurePath: string;
  runtimeRoot: string;
  onProgress?: (line: string) => void;
  klass?: SurfaceMapClass;
}

export type GateValidator = (invocation: GateInvocation) => GateResult;

/** Supported surface-map classes, in the stable order the terminal chain fans out. */
export const SURFACE_MAP_CLASSES: readonly SurfaceMapClass[] = ["backend", "frontend", "mobile"];

/** Applicability predicates a terminal gate definition can declare. */
export type TerminalGatePredicate = "hasReadyClassRepo";

/**
 * Terminal-chain metadata carried by a gate definition (CRP-166 D1): which
 * feature artifact triggers it, where it sits in the stable pipeline order,
 * which workflow step owns repairing it, and any pipeline predicate beyond
 * artifact existence. Absent on project-scope gates, which never enter the
 * feature chain.
 */
export interface TerminalGateMetadata {
  /** Stable pipeline position; the chain runs and reports in this order. */
  order: number;
  /**
   * Feature-relative trigger artifact. Class-expanded definitions carry the
   * `<class>` placeholder and are expanded over `SURFACE_MAP_CLASSES`.
   */
  artifact: string;
  /** Catalog step id an operator resumes to repair this gate's artifact. */
  repairStep: string;
  /** Pipeline condition beyond artifact existence. */
  predicate?: TerminalGatePredicate;
  /** True when the definition fans out over the supported surface classes. */
  classExpanded?: boolean;
}

/**
 * One registered gate: its validator plus, when the gate participates in
 * terminal validation, the metadata describing how. Keeping both on the same
 * entry is what makes a dangling terminal reference unrepresentable — the
 * metadata cannot outlive or drift from the validator it belongs to.
 */
export interface GateDefinition {
  validate: GateValidator;
  /** Terminal-chain participation; omitted for project-scope gates. */
  terminal?: TerminalGateMetadata;
  /** True when the gate requires a class argument to resolve its target. */
  classScoped?: boolean;
}

/**
 * The sole authored gate inventory (CRP-165 D2, CRP-166 D1). Standalone
 * `overmind gate` dispatch, the post-session executor, and the terminal chain
 * all derive from this one map, so a validator and its terminal classification
 * cannot diverge.
 */
const GATE_DEFINITIONS: Record<string, GateDefinition> = {
  "plan-semantic-review": {
    validate: ({ featurePath, runtimeRoot }) =>
      validatePlanSemanticReview(featurePath, runtimeRoot),
    terminal: {
      order: 12,
      artifact: "implementation_plan_semantic_review.md",
      repairStep: "8.4"
    }
  },
  "implementation-plan": {
    validate: ({ featurePath, runtimeRoot }) =>
      validateImplementationPlan(featurePath, runtimeRoot),
    terminal: { order: 11, artifact: "implementation_plan.md", repairStep: "8.3" }
  },
  "common-contract": {
    validate: ({ featurePath, runtimeRoot }) =>
      validateInitialCommonContract(featurePath, runtimeRoot)
  },
  "contract-delta": {
    validate: ({ featurePath, runtimeRoot }) => validateContractDelta(featurePath, runtimeRoot),
    terminal: { order: 6, artifact: "feature_contract_delta.md", repairStep: "6" }
  },
  "contract-reconciliation": {
    validate: ({ featurePath, runtimeRoot }) =>
      validateContractReconciliation(featurePath, runtimeRoot)
  },
  "agents-md": {
    validate: ({ featurePath, runtimeRoot }) => validateAgentsMd(featurePath, runtimeRoot)
  },
  "stack-blueprint": {
    validate: ({ featurePath, runtimeRoot }) => validateStackBlueprint(featurePath, runtimeRoot)
  },
  "br-clarification": {
    validate: ({ featurePath, runtimeRoot, onProgress }) =>
      validateBrClarification(featurePath, runtimeRoot, onProgress ? { onProgress } : {}),
    terminal: { order: 3, artifact: "feature_br_summary.md", repairStep: "4.2" }
  },
  "ears-review": {
    validate: ({ featurePath, runtimeRoot }) => validateEarsReview(featurePath, runtimeRoot),
    terminal: { order: 5, artifact: "requirements_ears_review.md", repairStep: "5.1" }
  },
  "requirements-ears": {
    validate: ({ featurePath, runtimeRoot }) => validateRequirementsEars(featurePath, runtimeRoot),
    terminal: { order: 4, artifact: "requirements_ears.md", repairStep: "5" }
  },
  "task-to-br": {
    validate: ({ featurePath, runtimeRoot }) => validateTaskToBr(featurePath, runtimeRoot),
    terminal: { order: 2, artifact: "feature_br_summary.md", repairStep: "4.1" }
  },
  "repo-br-scan": {
    validate: ({ featurePath, runtimeRoot }) => validateRepoBrScan(featurePath, runtimeRoot),
    terminal: {
      order: 1,
      artifact: "feature_br_summary.md",
      repairStep: "4.1",
      predicate: "hasReadyClassRepo"
    }
  },
  "technical-requirements": {
    validate: ({ featurePath, runtimeRoot }) =>
      validateTechnicalRequirements(featurePath, runtimeRoot),
    terminal: { order: 8, artifact: "technical_requirements.md", repairStep: "8" }
  },
  "implementation-slices": {
    validate: ({ featurePath, runtimeRoot }) =>
      validateImplementationSlices(featurePath, runtimeRoot),
    terminal: { order: 9, artifact: "implementation_slices.md", repairStep: "8.1" }
  },
  "prerequisite-gaps": {
    validate: ({ featurePath, runtimeRoot }) => validatePrerequisiteGaps(featurePath, runtimeRoot),
    terminal: { order: 10, artifact: "prerequisite_gaps.md", repairStep: "8.2" }
  },
  "surface-map": {
    classScoped: true,
    validate: ({ featurePath, runtimeRoot, klass }) =>
      klass
        ? validateSurfaceMap(featurePath, klass, runtimeRoot)
        : {
            exitCode: 2,
            passMessage: "",
            problems: [],
            errorMessage: "Gate 'surface-map' requires a class argument."
          },
    terminal: {
      order: 7,
      artifact: "project_surface_struct_resp_map_<class>.md",
      repairStep: "7",
      classExpanded: true
    }
  }
};

function validatorsOf(
  predicate: (definition: GateDefinition) => boolean = () => true
): Record<string, GateValidator> {
  return Object.fromEntries(
    Object.entries(GATE_DEFINITIONS)
      .filter(([, definition]) => predicate(definition))
      .map(([name, definition]) => [name, definition.validate])
  );
}

/** Every registered gate validator, class-scoped ones included. */
export const GATE_REGISTRY: Record<string, GateValidator> = validatorsOf();

/**
 * Gate validators that need no class argument. The post-session executor and the
 * non-class CLI path resolve names here; both are views of `GATE_DEFINITIONS`.
 */
export const NON_CLASS_GATE_REGISTRY: Record<string, GateValidator> = validatorsOf(
  (definition) => definition.classScoped !== true
);

/** Gate names that require a class argument to resolve their target artifact. */
export const CLASS_GATE_NAMES: readonly string[] = Object.entries(GATE_DEFINITIONS)
  .filter(([, definition]) => definition.classScoped === true)
  .map(([name]) => name);

/** A terminal chain entry: the gate name joined to its declared metadata. */
export type TerminalGateDefinition = TerminalGateMetadata & { gate: string };

/**
 * The terminal feature chain, derived from the gates that declare terminal
 * metadata and ordered by their declared pipeline position. Every deterministic
 * feature gate whose artifact can still be edited after its own step appears
 * here, so a completed feature is revalidated end to end before plan completion
 * is reported.
 */
export const TERMINAL_FEATURE_GATES: readonly TerminalGateDefinition[] = Object.entries(
  GATE_DEFINITIONS
)
  .flatMap(([gate, definition]) => (definition.terminal ? [{ gate, ...definition.terminal }] : []))
  .sort((left, right) => left.order - right.order);

/** Catalog step ids that own repairing a terminal gate failure. */
export const TERMINAL_REPAIR_STEPS: readonly string[] = [
  ...new Set(TERMINAL_FEATURE_GATES.map((definition) => definition.repairStep))
];
