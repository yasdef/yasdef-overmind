# Slice 4 Responsibility Inventory (rows 18–20)

Records the legacy attach/reconciliation surface and its new TypeScript/skill owner
(design D9). Every row is *kept*, *intentionally changed with rationale*, or *ported to a
named deterministic/test owner*. No row is left without an owner.

## Row 18–20 legacy surface → new owner

| Legacy artifact | Responsibility | New owner | Disposition |
|---|---|---|---|
| `common_libs/persist_class_repo_attach.sh` | Deterministic policy-C class-repo attach write + coherence check | `src/repo/attach.ts` + `src/parse/project-definition.ts` mutation helpers | Ported → deleted (task 7.2) |
| `class_repo_paths.sh::class_repo_paths_validate_coherence` | Post-write class-record coherence | `src/repo/attach.ts` (`validateClassRecordCoherence`) | Ported (helper stays for other callers) |
| `project_mgmt/project_contract_reconciliation.sh` | Model-session launcher + rule/quality loop for reconciliation | project-reconciliation `StepDefinition` (`src/sequencing/project-reconciliation.ts`) executed by the shared generic executor + `runProjectReconciliationFlow` | Ported → deleted (task 7.2) |
| `rules/project_contract_reconciliation_rule.md` | Normative model instructions | `packages/installer/_data/skills/overmind-contract-reconciliation/SKILL.md` (inlined) | Ported → deleted (task 7.2, single normative source) |
| `helper/check_common_contract_definition_quality.sh` | Common-contract quality gate (`0/1/2`) | `src/validate/contract-reconciliation.ts` + `gate contract-reconciliation` | Ported; **shell helper retained** for `init_common_contract_definition.sh`, parity-locked via shared fixtures |
| `templates/common_contract_definition_TEMPLATE.md` | Structural reference | skill `assets/common_contract_definition_TEMPLATE.md` | Copied |
| `golden_examples/common_contract_definition_GOLDEN_EXAMPLE.md` | Style reference | skill `assets/common_contract_definition_GOLDEN_EXAMPLE.md` | Copied |
| `.setup/models.md` phase `project_contract_reconciliation` | Model/runner config | unchanged (consumed by the catalog session) | Kept |
| Attach caller `project_setup_update_project.sh` | Runtime attach invocation | TypeScript attach primitive / `overmind project reconcile` | Migrated (task 7.1) |
| `.contract_reconciled_<class>` markers | Reconciliation completion signal | `meta_info.class_repo_paths.<class>.contract_reconciled` field | Replaced (clean break, D8) |

## Historical behavior families → named TypeScript/test owner

- `deferred_class_*` (ordered prompts, blank-defer, invalid-path retry-once, attach-without-blueprint,
  policy-C write, reattach invalidation) → `test/repo-attach.test.ts`, `test/project-reconciliation-flow.test.ts`.
- `reconciliation_*` (one class-list session, shared-repo dedup, definition immutability guard,
  required-output, config failure, marker-free pending detection, flag lifecycle) →
  `test/project-reconciliation-executor.test.ts`, `test/project-reconciliation-flow.test.ts`,
  `test/contract-reconciliation-gate.test.ts`, `test/contract-reconciliation-context.test.ts`.
- `commit_reconciliation_*` (clean baseline, owned-path verification, rollback, y/N commit,
  commit failure) → `test/project-reconciliation-transaction.test.ts`,
  `test/project-reconciliation-flow.test.ts`.

Architecture-driven divergences: markers replaced by the definition field (D8); the standalone
reconciliation rule is inlined into `SKILL.md` (D9); the quality helper is temporarily duplicated
between shell and TypeScript and parity-locked (D5).
