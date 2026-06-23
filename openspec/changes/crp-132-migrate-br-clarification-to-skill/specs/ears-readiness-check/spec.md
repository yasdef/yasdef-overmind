## ADDED Requirements

### Requirement: readiness CLI verb

The shared `overmind` CLI SHALL provide a deterministic `readiness <step> <feature-path>` verb dispatched via a `readinessRegistry`, alongside the existing `capture|context|gate|sync` verbs. Unknown readiness steps SHALL exit with an error naming the unknown step. The `readiness` verb performs deterministic state transitions and is invoked by the orchestrator, not by the model. A `readiness` handler MAY reuse shared validator/parser **functions** from `validate/` and `parse/` for its precondition checks, but SHALL NOT invoke the `overmind gate` CLI verb (which remains exclusively model-invoked).

#### Scenario: Unknown readiness step errors

- **WHEN** `node .overmind/overmind.js readiness <unknown-step> <path>` runs
- **THEN** the CLI writes an error naming the unknown readiness step and exits non-zero

#### Scenario: Usage error on missing arguments

- **WHEN** `readiness` is invoked without a step or feature path
- **THEN** the CLI writes a usage error listing `capture|context|gate|sync|readiness`

### Requirement: EARS readiness transition

The `readiness br-clarification` handler SHALL port `feature_br_check_ears_readiness.sh`. It SHALL perform its precondition checks by calling shared validator functions in-process (`validateBrClarification`, `validateRepoBrScan`) and inspecting the returned result, NOT by shelling out to the `overmind gate` CLI verb. It carries one documented superset deviation from the old script: where the old script invoked the bare `task-to-br` gate, the handler SHALL evaluate the `br-clarification` validator (which runs the `task-to-br` base check **plus** the unresolved-ledger check) as the business-context precondition, so any unanswered or `skip for now`-deferred clarification item blocks readiness — preserving the old end-to-end invariant that the clarification phase could not complete with unresolved items. For a feature path it SHALL: resolve the feature path and fail if it does not resolve inside the ASDLC workspace root; require `feature_br_summary.md`; resolve the project's `init_progress_definition.yaml` from the feature's parent project folder and fail if absent before running business-context gates; evaluate the `br-clarification` validator against `feature_br_summary.md` and fail (non-zero, surfacing the validator's problem output) if it does not pass; determine whether any `meta_info.class_repo_paths` entry has `state: ready` using the shared ready-path module; when a ready class exists, evaluate the `repo-br-scan` validator and fail if it does not pass, otherwise print a skip notice naming that no class is ready; and finally flip `ready_to_ears` from `false` to `true` in `## 1. Document Meta` of `feature_br_summary.md`. The handler SHALL validate the precondition that `ready_to_ears` is present and currently `false`, failing otherwise, and SHALL exit `0` with a pass message once the flip succeeds.

#### Scenario: Readiness passes with no ready class

- **WHEN** `readiness br-clarification <feature-path>` runs, the `br-clarification` validator passes, no `class_repo_paths` entry is `ready`, and `ready_to_ears` is `false`
- **THEN** the handler prints the repo-scan skip notice, flips `ready_to_ears` to `true`, prints the readiness pass message, and exits `0`

#### Scenario: Readiness evaluates the repo validator when a class is ready

- **WHEN** a `class_repo_paths` entry is `ready` and both the `br-clarification` and `repo-br-scan` validators pass
- **THEN** the handler flips `ready_to_ears` to `true` and exits `0`

#### Scenario: Readiness does not shell out to the gate CLI

- **WHEN** the `readiness br-clarification` handler runs its precondition checks
- **THEN** it calls the shared validator functions in-process and does not spawn `node .overmind/overmind.js gate <step>`

#### Scenario: Feature path must stay inside workspace

- **WHEN** `readiness br-clarification <feature-path>` is invoked with a path that resolves outside the ASDLC workspace root
- **THEN** the handler exits `2` with an error naming that the feature path must resolve inside the ASDLC workspace and does not run business-context gates

#### Scenario: Project definition is required before business gates

- **WHEN** the feature path is valid but the parent project has no `init_progress_definition.yaml`
- **THEN** the handler exits `2` with an error naming the missing project definition before surfacing any `br-clarification` validator failure

#### Scenario: Unresolved or skipped clarification item blocks readiness

- **WHEN** the `br-clarification` validator does not pass — including when a `rised_item_N` remains `rised=false` because the user replied `skip for now`
- **THEN** the handler fails non-zero, surfacing the validator's problem output, and does not flip `ready_to_ears`

#### Scenario: repo-br-scan validator failure blocks readiness

- **WHEN** a class is ready but the `repo-br-scan` validator does not pass
- **THEN** the handler fails non-zero, surfacing the validator's problem output, and does not flip `ready_to_ears`

#### Scenario: Precondition requires ready_to_ears false

- **WHEN** `ready_to_ears` is missing from `## 1. Document Meta`, or is already a value other than `false`
- **THEN** the handler fails with a message naming the unexpected `ready_to_ears` state and does not modify the artifact

### Requirement: Feature e2e orchestrator runs the readiness step

The `project_add_feature_e2e.sh` phase 4.2 SHALL run `node .overmind/overmind.js readiness br-clarification <feature-path>` as a deterministic step after the `overmind-br-clarification` skill session, replacing the deleted `feature_br_check_ears_readiness.sh`. The readiness step SHALL run without a Codex/model session.

#### Scenario: Readiness step is deterministic in phase 4.2

- **WHEN** the e2e orchestrator reaches the readiness step in phase 4.2
- **THEN** it invokes the `readiness br-clarification` CLI directly with no Codex session
- **AND** a non-zero readiness exit stops the phase with restart guidance resuming at step 4.2
