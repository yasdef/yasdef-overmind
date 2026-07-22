## 1. Update scanner persistence naming

- [x] 1.1 Update `overmind/scripts/project_mgmt/init_progress_scanner.sh` to derive the persisted project-root output filename from the selected feature folder basename as `step_state_<feature-folder>.md`.
- [x] 1.2 Keep scanner stdout payload and checklist rendering unchanged while replacing the persisted output path contract.
- [x] 1.3 Ensure the scanner no longer depends on or writes the shared project-root `step_state.md` path for successful feature scans.

## 2. Align consumers and operator guidance

- [x] 2.1 Update any scanner consumer logic in `overmind/scripts/project_mgmt/project_add_feature_e2e.sh` that references persisted checklist filenames so it resolves the feature-specific project-root filename from the selected feature context where needed.
- [x] 2.2 Update `README.md` to document that scanner persistence now writes `projects/<project-id>/step_state_<feature-folder>.md` while stdout remains the canonical machine-consumable scan output.
- [x] 2.3 Update any staged quickrun or setup guidance that still names `step_state.md` as the persisted scanner artifact.

## 3. Extend regression coverage

- [x] 3.1 Update `tests/ai_scripts/init_progress_scanner_tests.sh` to assert the new feature-specific output filename and stdout/file parity.
- [x] 3.2 Add scanner coverage proving two different feature scans under the same project create separate `step_state_<feature-folder>.md` files without overwriting each other.
- [x] 3.3 Update any affected orchestrator or setup tests, including `tests/ai_scripts/project_add_feature_e2e_tests.sh` and `tests/ai_scripts/project_setup_asdlc_tests.sh`, to match the new persisted filename contract.

## 4. Validate change readiness

- [x] 4.1 Run the focused shell test suites for scanner/orchestrator/setup coverage touched by this change.
- [x] 4.2 Run `openspec status --change crp-127-feature-scoped-step-state-filenames` and confirm the change is apply-ready.
