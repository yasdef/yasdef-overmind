# AGENTS

## Project Context
- This repository is the standalone Overmind project extracted from `yasdef`.
- Core project usage and workflow documentation live in `overmind/README.md`.
- This file defines repository-specific operating constraints only.

## Working Rules
- Keep changes minimal, scoped, and consistent with the current `overmind/` structure.
- Prefer updating existing docs/scripts over introducing parallel variants.
- Do not add new script CLI flags/options unless explicitly requested by the user or requirement artifacts.
- For `.sh` scripts, use plain shell implementations only; do not wrap logic with other runtimes unless explicitly requested by the user.

## Test Location And Commands
- Canonical script test location is `tests/ai_scripts/`.
- Keep Overmind shell tests in `tests/ai_scripts/`; do not create duplicate active suites elsewhere.
- Run script test suites from the repository root, for example:
  - `bash tests/ai_scripts/project_setup_asdlc_tests.sh`
  - `bash tests/ai_scripts/project_add_feature_e2e_tests.sh`
  - `bash tests/ai_scripts/register_worker_tests.sh`
  - `bash tests/ai_scripts/feature_assign_workers_to_implementation_plan_tests.sh`
  - `bash tests/ai_scripts/init_progress_scanner_tests.sh`
  - `bash tests/ai_scripts/init_common_contract_definition_tests.sh`
  - `bash tests/ai_scripts/init_br_scaffold_tests.sh`
  - `bash tests/ai_scripts/init_task_to_br_tests.sh`
  - `bash tests/ai_scripts/init_scan_repo_for_br_tests.sh`
  - `bash tests/ai_scripts/init_user_br_clarification_tests.sh`
  - `bash tests/ai_scripts/init_br_check_ears_readiness_tests.sh`
  - `bash tests/ai_scripts/init_br_to_ears_tests.sh`
  - `bash tests/ai_scripts/init_feature_requirements_ears_review_tests.sh`
  - `bash tests/ai_scripts/init_feature_contract_delta_tests.sh`
  - `bash tests/ai_scripts/init_feature_technical_requirements_tests.sh`
  - `bash tests/ai_scripts/init_feature_implementation_slices_tests.sh`
  - `bash tests/ai_scripts/init_feature_implementation_plan_tests.sh`
  - `bash tests/ai_scripts/init_feature_implementation_plan_semantic_review_tests.sh`
  - `bash tests/ai_scripts/feature_repo_surface_and_exec_context_be_tests.sh`
  - `bash tests/ai_scripts/feature_repo_surface_and_exec_context_fe_tests.sh`
  - `bash tests/ai_scripts/check_task_to_br_quality_tests.sh`
  - `bash tests/ai_scripts/check_requirements_ears_quality_tests.sh`
  - `bash tests/ai_scripts/check_requirements_ears_review_quality_tests.sh`
  - `bash tests/ai_scripts/check_common_contract_definition_quality_tests.sh`
  - `bash tests/ai_scripts/check_feature_contract_delta_quality_tests.sh`
  - `bash tests/ai_scripts/check_feature_technical_requirements_quality_tests.sh`
  - `bash tests/ai_scripts/check_implementation_slices_quality_tests.sh`
  - `bash tests/ai_scripts/check_implementation_plan_quality_tests.sh`
  - `bash tests/ai_scripts/check_cross_class_peer_trigger_tests.sh`

## Safety And Change Constraints
- Do not run destructive git commands unless explicitly requested.
- Do not bypass user decisions for blocking or unclear requirements.
- Preserve unrelated local changes; do not revert files outside the scoped task.
- Keep scripts concise and keep durable operational guidance in `overmind/README.md`.

## Maintenance Expectations
- When paths, commands, or conventions change, update this file in the same change.
- Keep guidance short, actionable, and aligned with `overmind/README.md`.
