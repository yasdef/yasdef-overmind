## 1. Add project-level feature discovery and selection

- [x] 1.1 Update `overmind/scripts/project_mgmt/project_add_feature_e2e.sh` to enumerate project child feature-folder candidates before Step `3` scaffold and ignore invalid or stale cached feature paths.
- [x] 1.2 Classify discovered feature folders by invoking `init_progress_scanner.sh --path <feature-path>` and parsing the canonical `next step` line into unfinished versus complete status.
- [x] 1.3 Add a project-scope operator decision flow that offers `start new feature` versus `continue existing unfinished feature` whenever unfinished features are present.
- [x] 1.4 Add deterministic continue-selection rendering that lists only unfinished features together with their scanner-reported `next step` status and activates the selected feature as `FEATURE_PATH`.
- [x] 1.5 Keep `.project_add_feature_e2e_state.env` as a last-selected-feature cache only, updating it after explicit selection or new scaffold without bypassing future discovery.

## 2. Preserve downstream orchestration behavior and operator guidance

- [x] 2.1 Ensure `--resume <step>` handling remains unchanged after project-level feature selection resolves the active feature target.
- [x] 2.2 Update orchestrator terminal messaging for no-unfinished-feature, stale-cache, and selected-feature cases so multi-feature behavior is explicit.
- [x] 2.3 Update `overmind/README.md` and `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` quickrun guidance to explain project-level feature discovery, new-versus-continue prompts, and cache semantics.

## 3. Extend regression coverage

- [x] 3.1 Extend `tests/ai_scripts/project_add_feature_e2e_tests.sh` to cover projects with multiple feature folders, continue-list filtering that excludes completed features, explicit new-versus-continue selection, and stale cached feature paths.
- [x] 3.2 Add tests proving that selected continue targets drive downstream `--feature_path` execution and that choosing new feature flow still runs Step `3` scaffold first.
- [x] 3.3 Update scanner-related tests as needed to preserve the machine-consumable canonical `next step` line expected by project-level feature selection.

## 4. Validate change readiness

- [x] 4.1 Run `openspec status --change crp-106-project-feature-selection-for-feature-orchestrator` and confirm the change is apply-ready.
