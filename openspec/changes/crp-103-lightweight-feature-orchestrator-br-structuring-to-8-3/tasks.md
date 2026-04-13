## 1. Build the lightweight feature orchestrator command

- [x] 1.1 Add `overmind/scripts/project_mgmt/project_add_feature_e2e.sh` with mandatory `--path <project-folder-path>` parsing and optional `--resume <step>` support.
- [x] 1.2 Implement startup Step `3` that runs `feature_br_scaffold.sh --path <project-folder-path>`, captures `Created feature folder: <feature_path>`, and persists active `feature_path` state for continuation/resume.
- [x] 1.3 Implement a deterministic phase map that explicitly splits Step `4` as Step `4.1` (`feature_scan_repo_for_br.sh` then `feature_task_to_br.sh`) and Step `4.2` (`feature_user_br_clarification.sh` then `feature_br_check_ears_readiness.sh`), then continues through optional Step `8.3` with multi-script phase grouping metadata and optional flags.
- [x] 1.4 Invoke `overmind/scripts/project_mgmt/init_progress_scanner.sh --path <saved-feature_path>` once `feature_path` is resolved, print scanner status, and derive default start from scanner `next step` output.
- [x] 1.5 Implement downstream command invocation so every script after scaffold receives the saved `--feature_path` without changing existing script CLIs.
- [x] 1.6 Implement per-script confirmation prompts, deterministic invalid-input retry handling, required-step decline stop behavior, and optional-step decline skip/finish behavior.
- [x] 1.7 Add deterministic pre-run messaging for multi-script phases showing phase id, script path, and script index (`n/m`) before each confirmation.

## 2. Wire staged command setup and documentation

- [x] 2.1 Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` to stage `project_add_feature_e2e.sh` into `<asdlc>/.commands/` in bootstrap and update flows.
- [x] 2.2 Update staged quickrun guidance generation so feature orchestration usage is documented with `--path`, scaffold-first behavior, saved `feature_path` continuation, and `--resume` examples.
- [x] 2.3 Update `overmind/README.md` and `overmind/init_progress_definition_sequence_diagram.md` to describe the new orchestrated feature flow and scanner-at-start behavior.

## 3. Add and run regression coverage

- [x] 3.1 Add `tests/ai_scripts/project_add_feature_e2e_tests.sh` covering required `--path`, scaffold-first invocation, captured feature-path persistence, scanner-after-scaffold behavior, explicit Step `4.1`/`4.2` mapping order, default resume, explicit `--resume` override, required-step decline stop, optional-step decline skip, and multi-script messaging/order.
- [x] 3.2 Update `tests/ai_scripts/project_setup_asdlc_tests.sh` to verify staged command availability and quickrun documentation for `project_add_feature_e2e.sh`.
- [x] 3.3 Update scanner-related tests if needed to enforce canonical `next step` behavior for required-step resume consumers when optional steps are incomplete.
- [x] 3.4 Run relevant `tests/ai_scripts/` suites from repository root and confirm they pass.

## 4. Validate OpenSpec readiness

- [x] 4.1 Run `openspec status --change crp-103-lightweight-feature-orchestrator-br-structuring-to-8-3` and confirm the change is apply-ready.
