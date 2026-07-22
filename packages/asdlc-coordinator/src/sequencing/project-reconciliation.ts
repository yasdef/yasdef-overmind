import type { StepDefinition } from "./step-catalog.js";

/**
 * Project reconciliation catalog step (D4). Catalog data, but intentionally NOT part of
 * the numbered feature `STEP_CATALOG` — it is a project lifecycle action rather than an
 * `init_progress_definition.yaml` numbered phase. Executed once with the full pending
 * class-list binding by the shared generic executor: one `overmind-contract-reconciliation`
 * session at model phase `project_contract_reconciliation`, a `mustExistUnchanged` guard on
 * the project definition, and required output `common_contract_definition.md`. No gate is
 * invoked by the executor; the model owns the gate loop.
 */
export const PROJECT_RECONCILIATION_STEP: StepDefinition = {
  id: "project-reconcile",
  label: "Reconcile Common Contract Against Attached Repositories",
  optional: false,
  perClass: false,
  resumeAliases: [],
  actions: [
    {
      kind: "session",
      skillName: "contract-reconciliation",
      modelPhase: "project_contract_reconciliation",
      readOnlyGuards: [{ mode: "mustExistUnchanged", files: ["init_progress_definition.yaml"] }],
      requiredOutputs: ["common_contract_definition.md"]
    }
  ]
};
