## Why

Project init steps 1.1 (define per-class stack blueprints) and 2 (create the cross-repository common contract) are still owned by pre-TypeScript shell orchestrators (`init_project_stack_blueprints.sh`, `init_common_contract_definition.sh`) plus four helper/common-library scripts (`check_project_stack_blueprint_quality.sh`, `check_common_contract_definition_quality.sh`, `check_cross_class_peer_trigger.sh`, `class_repo_paths.sh`). These are the last model-session shell launchers and the last remaining helper/common libraries. This is Unit C of `design_docs/e2e_orchestrator_migration/06_sh_remove_plan.md`: move init steps 1.1 and 2 onto the same skill + generic-executor architecture the feature steps already use, port the quality gates to deterministic TypeScript validators, and delete the shell. Overmind has never been installed, so the scripts are behavior reference, not a deployed contract to preserve.

## What Changes

- Add `overmind project init --path <project>` — selects the next pending project-init step from `ProgressReport` (no hand-written step branches), applies project-type applicability, and dispatches steps 1.1 and 2 through the existing generic executor. Steps 1.1 and 2 gain non-empty `StepDefinition.actions`: step 1.1 is a per-class `overmind-stack-blueprint` session (once per applicable active backend/frontend/mobile class), step 2 is a project-level `overmind-common-contract` session that writes only `common_contract_definition.md`.
- Package the `overmind-stack-blueprint` skill (per-class template + golden example as assets, concise normative instructions; the model runs `overmind gate stack-blueprint <path>` until `0`) and the `overmind-common-contract` skill (binds ready-repo evidence and applicable blueprints, writes only `common_contract_definition.md`, runs the common-contract gate until `0`). Both are added to the installer's packaged-skill fan-out.
- Port `check_project_stack_blueprint_quality.sh` to a deterministic `validate/stack-blueprint.ts` with stable `0/1/2` gate exit codes, registered as `overmind gate stack-blueprint`.
- Reuse the existing `repo/cross-class-peer-trigger.ts` and `validate/contract-reconciliation.ts`; add only the initial-contract adapter/alias needed to preserve the `check_common_contract_definition_quality.sh` target-path and exit-code contract for initial generation.
- Fold `class_repo_paths.sh` (read/validate class repo paths) into the existing `parse/project-definition.ts`, `repo/collect-ready-paths.ts`, and `repo/attach.ts`; load every model row through `config/runner-config.ts` (phases `project_stack_blueprint`, `common_contract_definition`).
- Preserve the contract behaviors: model prompt bindings, per-class template choice, ready-repo/blueprint evidence, no-peer behavior, read-only blueprint guards during common-contract creation, required outputs, and the project-init baseline commit. Update `overmind run` pending-work guidance to name `overmind project init` instead of the shell commands.
- Update `overmind/init_progress_definition_sequence_diagram.md` and `overmind/templates/init_progress_definition_TEMPLATE.yaml` together; replace the literal `.helper/check_project_stack_blueprint_quality.sh` completion text with the TypeScript gate contract.
- Delete `init_project_stack_blueprints.sh`, `init_common_contract_definition.sh`, `check_project_stack_blueprint_quality.sh`, `check_common_contract_definition_quality.sh`, `check_cross_class_peer_trigger.sh`, `class_repo_paths.sh`, and their six shell suites (`init_project_stack_blueprints_tests.sh`, `init_common_contract_definition_tests.sh`, `check_project_stack_blueprint_quality_tests.sh`, `check_common_contract_definition_quality_tests.sh`, `check_cross_class_peer_trigger_tests.sh`, `class_repo_paths_coherence_tests.sh`); remove their `.commands`/`.helper`/`common_libs` staging in `project_setup_first_init_machine.sh`.

## Capabilities

### New Capabilities

- `project-init`: run project init steps 1.1 and 2 via `overmind project init --path <project>` — next-pending-step selection from `ProgressReport`, project-type applicability, per-class step-1.1 expansion, project-level step-2 orchestration through the generic executor, project-init baseline commit, and updated `overmind run` pending-work guidance. Absorbs the `class_repo_paths.sh` read/validate helpers into existing parse/repo modules.
- `stack-blueprint-generation`: init step 1.1 as a packaged `overmind-stack-blueprint` skill plus a deterministic `validate/stack-blueprint.ts` gate exposed as `overmind gate stack-blueprint` with stable `0/1/2` exit codes; per active applicable class, class-specific template + golden example, model-owned gate loop.
- `common-contract-generation`: init step 2 as a packaged `overmind-common-contract` skill that writes only `common_contract_definition.md`, binds ready-repo evidence and applicable blueprints, enforces read-only blueprint guards, and runs the common-contract gate until `0` via an initial-contract adapter over the existing `validate/contract-reconciliation.ts` (preserving its target-path and exit-code contract).

### Modified Capabilities

<!-- None. Init steps 1.1 and 2 have no prior OpenSpec spec of record; their behavior lived only in shell. All three concerns are captured as new capabilities in this change. -->

## Impact

- Adds `packages/asdlc-coordinator/src/validate/stack-blueprint.ts` (+ export), a `stack-blueprint` entry in the `overmind gate` registry, and an initial-contract adapter/alias over `validate/contract-reconciliation.ts`.
- Extends `packages/asdlc-coordinator/src/sequencing/step-catalog.ts` so steps `1.1` and `2` carry session actions, and `packages/asdlc-coordinator/src/runner/execute-step.ts` (+ context builders) with project-scoped, per-class init sessions loaded through `config/runner-config.ts` (phases `project_stack_blueprint`, `common_contract_definition`).
- Adds `overmind project init` dispatch in `packages/asdlc-coordinator/src/cli/run.ts` (next-pending-step selection, project-type applicability) and updates `orchestrator/pending-work.ts` init guidance to name `overmind project init`.
- Adds packaged skills `packages/installer/_data/skills/overmind-stack-blueprint/` and `.../overmind-common-contract/` (SKILL.md + assets) and lists them in `packages/installer/src/init.ts` `PACKAGED_SKILLS`.
- Folds `class_repo_paths.sh` into `parse/project-definition.ts`, `repo/collect-ready-paths.ts`, `repo/attach.ts`; reuses `repo/cross-class-peer-trigger.ts` for the no-peer behavior.
- Updates `overmind/init_progress_definition_sequence_diagram.md`, `overmind/templates/init_progress_definition_TEMPLATE.yaml`, `overmind/README.md`, and `QUICKRUN.md` to the TypeScript project-init verbs and gate contracts.
- Deletes six shell files and six shell test suites; removes their `.commands`/`.helper`/`common_libs` staging in `project_setup_first_init_machine.sh`. No runtime `dependencies` added to `packages/asdlc-coordinator` (kept `{}`).
