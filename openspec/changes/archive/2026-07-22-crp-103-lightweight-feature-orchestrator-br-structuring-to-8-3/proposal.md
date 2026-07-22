## Why

The feature pipeline from `Initialize and Enrich Business Requirements Structuring` through Step `8.3` currently requires manual script-by-script execution, which makes recovery after partial progress error-prone and inconsistent across runs. A lightweight orchestrator is needed now to provide deterministic, project-scoped startup plus feature-scoped continuation with explicit user control at each step while preserving existing script contracts.

## What Changes

- Add a lightweight feature-phase orchestrator script `overmind/scripts/project_mgmt/project_add_feature_e2e.sh` modeled after `ai/scripts/orchestrator.sh`, but scoped to overmind feature steps only.
- Require `--path <project-folder-path>` as orchestrator input.
- Start orchestration by running `overmind/scripts/feature_br_scaffold.sh --path <project-folder-path>` to create a new feature folder and BR scaffold artifacts.
- Capture and persist the created `feature_path` from scaffold output so downstream and resumed runs can reuse the same feature target.
- Split the long BR-structuring execution segment into two explicit required checkpoints:
  - Step `4.1`: `feature_scan_repo_for_br.sh` then `feature_task_to_br.sh`.
  - Step `4.2`: `feature_user_br_clarification.sh` then `feature_br_check_ears_readiness.sh`.
- Scope orchestrator coverage from Step `3` (BR scaffold initialization) through Step `8.3` (inclusive), including required and optional phases in that range.
- After `feature_path` is known, run `overmind/scripts/project_mgmt/init_progress_scanner.sh --path <feature_path>` and show current checklist status before selecting or resuming execution.
- Make default start behavior resumable: if work was started earlier, continue from the current unfinished point inferred from current progress state.
- Support explicit resume override via `--resume <step>` to start from an operator-selected step anchor.
- Execute scripts sequentially and require explicit user confirmation before each script starts.
- Define decline behavior by step type:
  - optional step declined: skip immediately to the next non-optional remaining step; if none remain, finish successfully;
  - non-optional step declined: stop orchestration immediately and close the run.
- For phases that contain multiple scripts, require deterministic one-by-one execution order and emit a clear pre-run message identifying the phase and script about to run.
- For every script after scaffold, invoke it with the saved `--feature_path` so existing script CLIs do not need modification.
- Keep this orchestrator lightweight by orchestrating existing step scripts rather than replacing their internal logic.

## Capabilities

### New Capabilities

- `overmind-feature-lightweight-step-orchestrator`: The workflow SHALL provide `project_add_feature_e2e.sh` that starts from project input (`--path`) by running Step `3` scaffold (`feature_br_scaffold.sh`), persists the produced `feature_path`, then runs Step `4.1` (`feature_scan_repo_for_br.sh` + `feature_task_to_br.sh`) and Step `4.2` (`feature_user_br_clarification.sh` + `feature_br_check_ears_readiness.sh`) through optional Step `8.3`, with progress-scanner-based resume, explicit `--resume` override, per-script confirmation gating, optional-step skip semantics, deterministic multi-script messaging, and downstream script execution via saved `--feature_path`.

### Modified Capabilities

- `overmind-bootstrap-progress-checklist`: The scanner output contract SHALL be consumable by the new feature orchestrator as the canonical status source shown at orchestrator start and used for default resume routing.

## Impact

- New or updated orchestration script(s):
  - `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`
- Potentially affected project-management glue:
  - `overmind/scripts/project_mgmt/init_progress_scanner.sh`
  - `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`
  - `overmind/scripts/project_mgmt/project_setup_update_project.sh`
- Potentially affected docs/contracts:
  - `overmind/README.md`
  - `overmind/init_progress_definition_sequence_diagram.md`
  - related rule/template references for orchestrated step ordering and optional-step handling
- Potentially affected tests:
  - `tests/ai_scripts/project_setup_asdlc_tests.sh`
  - `tests/ai_scripts/init_progress_scanner_tests.sh`
  - `tests/ai_scripts/project_add_feature_e2e_tests.sh`
- Process impact:
  - Operators gain deterministic, resume-friendly, confirmation-gated execution for feature steps without changing the core behavior of individual feature scripts.
