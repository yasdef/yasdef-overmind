export type ReadOnlyGuard =
  | { mode: "fromContext" }
  | { mode: "mustExistUnchanged"; files: string[] }
  | { mode: "preserveExistence"; files: string[] };

export type RunPredicate = "hasReadyClassRepo";

export type Action =
  | {
      kind: "session";
      skillName: string;
      modelPhase: string;
      requiresSync?: boolean;
      readOnlyGuards: ReadOnlyGuard[];
      requiredOutputs: string[];
      runIf?: RunPredicate;
    }
  | { kind: "check" | "write"; name: string };

export interface StepDefinition {
  id: string;
  label: string;
  optional: boolean;
  perClass: boolean;
  resumeAliases: string[];
  actions: Action[];
}

const contextGuard: ReadOnlyGuard[] = [{ mode: "fromContext" }];
const brSummaryGuard: ReadOnlyGuard[] = [
  { mode: "mustExistUnchanged", files: ["feature_br_summary.md"] }
];
const session = (
  skillName: string,
  modelPhase: string,
  requiredOutputs: string[],
  options: Partial<
    Pick<Extract<Action, { kind: "session" }>, "requiresSync" | "runIf" | "readOnlyGuards">
  > = {}
): Action => ({
  kind: "session",
  skillName,
  modelPhase,
  readOnlyGuards: options.readOnlyGuards ?? [],
  requiredOutputs,
  ...options
});

export const STEP_CATALOG: StepDefinition[] = [
  {
    id: "1",
    label: "Initialize Repo ASDLC Metadata",
    optional: false,
    perClass: false,
    resumeAliases: [],
    actions: []
  },
  {
    id: "1.1",
    label: "Define Project Stack Blueprints For Active Classes",
    optional: false,
    perClass: true,
    resumeAliases: [],
    actions: [
      session("stack-blueprint", "project_stack_blueprint", ["project_stack_blueprint_<class>.md"])
    ]
  },
  {
    id: "2",
    label: "Create Cross-Repository Contract Definition For This Project",
    optional: false,
    perClass: false,
    resumeAliases: [],
    actions: [
      session("common-contract", "common_contract_definition", ["common_contract_definition.md"], {
        readOnlyGuards: contextGuard
      })
    ]
  },
  {
    id: "3",
    label: "Initialize and Enrich Business Requirements Structuring",
    optional: false,
    perClass: false,
    resumeAliases: ["scaffold"],
    actions: [{ kind: "write", name: "scaffold-feature" }]
  },
  {
    id: "4.1",
    label: "Scan repo and apply task-to-BR update",
    optional: false,
    perClass: false,
    resumeAliases: ["scan-task", "scan-task-to-br"],
    actions: [
      session("repo-br-scan", "repo_analyse", ["feature_br_summary.md"], {
        requiresSync: true,
        runIf: "hasReadyClassRepo"
      }),
      session("task-to-br", "task_to_br", ["feature_br_summary.md"])
    ]
  },
  {
    id: "4.2",
    label: "Clarify BR and check EARS readiness",
    optional: false,
    perClass: false,
    resumeAliases: ["clarification", "readiness"],
    actions: [
      session("br-clarification", "user_br_clarification", ["feature_br_summary.md"]),
      { kind: "check", name: "br-clarification-readiness" }
    ]
  },
  {
    id: "5",
    label: "Convert Business Requirements Structuring to EARS",
    optional: false,
    perClass: false,
    resumeAliases: ["4", "ears", "br-to-ears"],
    actions: [
      session("requirements-ears", "br_to_ears", ["requirements_ears.md"], {
        readOnlyGuards: brSummaryGuard
      })
    ]
  },
  {
    id: "5.1",
    label: "(optional) requirement_ears extra review",
    optional: true,
    perClass: false,
    resumeAliases: ["ears-review", "4.1-optional"],
    actions: [
      session("ears-review", "requirements_ears_review", ["requirements_ears_review.md"], {
        readOnlyGuards: brSummaryGuard
      })
    ]
  },
  {
    id: "6",
    label: "Define Feature Contract Delta",
    optional: false,
    perClass: false,
    resumeAliases: ["contract-delta"],
    actions: [
      session("contract-delta", "feature_contract_delta", ["feature_contract_delta.md"], {
        requiresSync: true,
        readOnlyGuards: contextGuard
      })
    ]
  },
  {
    id: "7",
    label: "Analyze Repos And Prepare Repo Execution Context",
    optional: false,
    perClass: true,
    resumeAliases: ["repo-surface"],
    actions: [
      session(
        "surface-map",
        "feature_repo_surface_and_exec_context",
        ["project_surface_struct_resp_map_<class>.md"],
        { requiresSync: true, runIf: "hasReadyClassRepo", readOnlyGuards: contextGuard }
      )
    ]
  },
  {
    id: "7.1",
    label: "(optional) MCP placeholder enrichment",
    optional: true,
    perClass: false,
    resumeAliases: ["mcp-placeholder-enrichment"],
    actions: [
      {
        kind: "session",
        skillName: "surface-map-enrich",
        modelPhase: "feature_surface_map_mcp_placeholder_enrichment",
        readOnlyGuards: [
          {
            mode: "preserveExistence",
            files: [".setup/external_sources.yaml", "../init_progress_definition.yaml"]
          }
        ],
        requiredOutputs: []
      }
    ]
  },
  {
    id: "8",
    label: "Create Feature-Scoped Technical Requirements",
    optional: false,
    perClass: false,
    resumeAliases: ["technical-requirements"],
    actions: [
      session(
        "technical-requirements",
        "feature_technical_requirements",
        ["technical_requirements.md"],
        { readOnlyGuards: contextGuard }
      )
    ]
  },
  {
    id: "8.1",
    label: "Create Implementation Slice Planning Artifact",
    optional: false,
    perClass: false,
    resumeAliases: ["implementation-slices"],
    actions: [
      session(
        "implementation-slices",
        "repository_implementation_slices",
        ["implementation_slices.md"],
        { readOnlyGuards: contextGuard }
      )
    ]
  },
  {
    id: "8.2",
    label: "Run Prerequisite Gap Trace",
    optional: false,
    perClass: false,
    resumeAliases: ["prerequisite-gap-trace", "prerequisite-gaps"],
    actions: [
      session("prerequisite-gaps", "prerequisite_gap_trace", ["prerequisite_gaps.md"], {
        requiresSync: true,
        readOnlyGuards: contextGuard
      })
    ]
  },
  {
    id: "8.3",
    label: "Create Shared Repository Implementation Plan",
    optional: false,
    perClass: false,
    resumeAliases: ["implementation-plan"],
    actions: [
      session("implementation-plan", "repository_implementation_plan", ["implementation_plan.md"], {
        readOnlyGuards: contextGuard
      })
    ]
  },
  {
    id: "8.4",
    label: "(optional) implementation plan semantic review",
    optional: true,
    perClass: false,
    resumeAliases: ["semantic-review", "implementation-plan-semantic-review"],
    actions: [
      session(
        "plan-semantic-review",
        "implementation_plan_semantic_review",
        ["implementation_plan_semantic_review.md"],
        { readOnlyGuards: contextGuard }
      )
    ]
  }
];

export function resolveStep(value: string): {
  stepId?: string;
  diagnostics: import("../types/index.js").Diagnostic[];
} {
  const normalized = value.trim().toLowerCase();
  const found = STEP_CATALOG.find(
    (step) => step.id === normalized || step.resumeAliases.includes(normalized)
  );
  if (found) return { stepId: found.id, diagnostics: [] };
  return {
    diagnostics: [
      {
        severity: "error",
        source: "step-catalog",
        reason: `Unknown step or resume alias: ${value}`
      }
    ]
  };
}
