## Why

Slice 3 deliberately leaves repo attachment and common-contract reconciliation outside `overmind run`, so projects with deferred or unreconciled classes still depend on the last legacy model-session shell flow. Slice 4 completes that boundary by introducing the separate TypeScript project lifecycle command specified by `design_docs/e2e_orchestrator_migration/04_migration_plan.md ## Slice 4 — Project-level flow (`overmind project reconcile`)` and closing responsibility-map rows 18–20.

## What Changes

- Add `overmind project reconcile [--path <project>]` as the project-level flow for deferred-class attachment, pending-class reconciliation, and the optional project-worktree commit unit.
- Port class repo attachment to a deterministic TypeScript primitive with the existing policy-C write contract, class/path validation, coherent definition update, retry-once interaction, and `contract_reconciled` invalidation when an attachment changes.
- Run all ready classes whose `contract_reconciled` field is not true through one catalog model session using a class-list binding and the shared generic executor; set every covered class flag only after that session succeeds.
- Migrate the reconciliation rule and quality loop into the installed `overmind-contract-reconciliation` skill plus TypeScript context and gate handlers, preserving its operator-approval, in-scope/out-of-scope, read-only, and gate-exit semantics.
- Enforce a clean project worktree before the first mutation, restrict the reconciliation unit to `init_progress_definition.yaml` and `common_contract_definition.md`, roll back reconciliation-owned edits when unexpected paths change, and offer a y/N commit through `InteractionPort`.
- Switch feature-flow pending-work guidance to `overmind project reconcile` and remove the transitional legacy-marker bridge.
- **BREAKING:** delete `persist_class_repo_attach.sh`, `project_contract_reconciliation.sh`, the standalone reconciliation rule and their active shell tests/staging after equivalent TypeScript and installer/setup coverage is in place. Retain `check_common_contract_definition_quality.sh` and its staging/tests for the still-live `init_common_contract_definition.sh` consumer while keeping its checks parity-locked with the new TypeScript gate. Legacy `.contract_reconciled_<class>` files no longer satisfy reconciliation state.

## Capabilities

### New Capabilities

- `project-reconciliation-flow`: Project selection, deferred-class attachment, pending-class batching, clean-worktree and owned-path transaction behavior, reconciliation state lifecycle, commit interaction, diagnostics, CLI outcomes, and feature-flow handoff.
- `contract-reconciliation-skill`: Installed skill, deterministic context and quality gate, generic-executor catalog session, class-list bindings, instruction/guard parity, and runtime installation for common-contract reconciliation.

### Modified Capabilities

<!-- None — openspec/specs/ contains no published capability specs. Slice 3 capability files remain change-local, so the project-flow handoff is specified here as part of the new project-reconciliation-flow capability. -->

## Impact

- **Coordinator:** `packages/asdlc-coordinator/src/orchestrator/`, `repo/`, `parse/`, `sequencing/`, `runner/`, `context/`, `validate/`, `git/`, and `cli/run.ts`, with focused TypeScript tests for responsibility-map rows 18–20.
- **Skill and installer:** new `packages/installer/_data/skills/overmind-contract-reconciliation/` payload, installer registration, both `.codex` and `.claude` targets, and setup/update staging tests.
- **Project state:** `meta_info.class_repo_paths.<class>.contract_reconciled` becomes the sole reconciliation status; reattachment clears it and a successful batch reconciliation sets it.
- **Git scope:** the project folder worktree, distinct from Slice 3 runtime-root checkpoints; non-git projects pass through while dirty git projects fail before mutation.
- **Removed shell surface:** legacy attach/reconciliation scripts, standalone reconciliation-rule staging, and `tests/ai_scripts/persist_class_repo_attach_tests.sh` plus `tests/ai_scripts/project_contract_reconciliation_tests.sh` once parity is covered. The common-contract shell quality helper remains staged for initialization until that separate consumer migrates.
- **Documentation and verification:** operator guidance in `overmind/README.md`, `QUICKRUN.md`, setup output, and feature-flow diagnostics; `npm run verify`, strict OpenSpec validation, and `git diff --check` remain completion gates.
