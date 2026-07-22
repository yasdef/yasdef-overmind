## 1. Update canonical step definitions for grouped scanner output

- [x] 1.1 Update `overmind/templates/init_progress_definition_TEMPLATE.yaml` so Step 2 is renamed to `Create Cross-Repository Contract Definition For This Project`.
- [x] 1.2 Ensure the canonical template keeps explicit phase metadata needed to distinguish project-level steps (`init`) from feature-level steps (`feature`).

## 2. Implement grouped scanner rendering

- [x] 2.1 Update `overmind/scripts/project_mgmt/init_progress_scanner.sh` to render `---- PROJECT LEVEL TASKS ----` before init-phase checklist items.
- [x] 2.2 Update the scanner to render `--- FEATURE LEVEL TASKS <name-of-feature> ---` before feature-phase checklist items while preserving step order and `next step` behavior.
- [x] 2.3 Resolve the feature heading name deterministically from the active feature root metadata, including a stable fallback when `feature_title` is unavailable.

## 3. Refresh output references and documentation

- [x] 3.1 Update `overmind/templates/step_state_TEMPLATE.md` to show grouped project-level and feature-level checklist sections.
- [x] 3.2 Update `overmind/golden_examples/step_state_GOLDEN_EXAMPLE.md` to match the new grouped scanner output contract.
- [x] 3.3 Update `overmind/README.md` so scanner examples and step naming reflect the grouped output and revised Step 2 label.

## 4. Extend automated coverage

- [x] 4.1 Extend `tests/ai_scripts/init_progress_scanner_tests.sh` to assert project-level heading rendering, feature-level heading rendering, and the revised Step 2 label behavior.
- [x] 4.2 Add scanner tests for feature-title resolution and deterministic fallback when the active feature title is unavailable.
- [x] 4.3 Update any affected scanner assertions in `tests/ai_scripts/project_setup_asdlc_tests.sh`.

## 5. Validate change readiness

- [x] 5.1 Run `bash tests/ai_scripts/init_progress_scanner_tests.sh` from the repository root.
- [x] 5.2 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh` from the repository root.
- [x] 5.3 Run `openspec status --change crp-094-progress-scanner-task-level-grouping-and-step-rename` to confirm artifacts are complete and apply-ready.
