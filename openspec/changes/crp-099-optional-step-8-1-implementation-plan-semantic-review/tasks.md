## 1. Add the Step 8.1 semantic-review scaffold

- [x] 1.1 Add `overmind/rules/implementation_plan_semantic_review_rule.md` defining semantic review scope, allowed finding types, and report-only behavior for `implementation_plan_semantic_review.md`.
- [x] 1.2 Add `overmind/templates/implementation_plan_semantic_review_TEMPLATE.md` and `overmind/golden_examples/implementation_plan_semantic_review_GOLDEN_EXAMPLE.md` for the durable review artifact contract.
- [x] 1.3 Add `overmind/scripts/helper/check_implementation_plan_semantic_review_quality.sh` with deterministic pass/fail/runtime semantics for the semantic-review artifact.

## 2. Implement the optional staged feature phase

- [x] 2.1 Add `overmind/scripts/feature_implementation_plan_semantic_review.sh` as the staged Step `8.1` command using `--feature_path <asdlc/projects/<project-id>/<feature-folder>>`.
- [x] 2.2 Add the `implementation_plan_semantic_review` row to `overmind/setup/models.md`.
- [x] 2.3 Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` so first-init and update staging include the new Step `8.1` command and required support assets.

## 3. Wire Step 8.1 into progress and docs

- [x] 3.1 Update `overmind/templates/init_progress_definition_TEMPLATE.yaml` to declare optional Step `8.1` after Step `8` with `implementation_plan_semantic_review.md` as its completion artifact.
- [x] 3.2 Update `overmind/init_progress_definition_sequence_diagram.md` to show the optional semantic-review pass after implementation-plan generation.
- [x] 3.3 Update `overmind/README.md` and staged quickrun guidance to describe `feature_implementation_plan_semantic_review.sh` and its optional Step `8.1` role.

## 4. Add automated coverage and validate readiness

- [x] 4.1 Add `tests/ai_scripts/init_feature_implementation_plan_semantic_review_tests.sh` for staged-command path validation, required inputs, artifact generation, and helper integration.
- [x] 4.2 Update `tests/ai_scripts/project_setup_asdlc_tests.sh` to verify staging of the Step `8.1` command and its support assets.
- [x] 4.3 Update `tests/ai_scripts/init_progress_scanner_tests.sh` to verify optional Step `8.1` rendering and non-blocking behavior.
- [x] 4.4 Run the relevant `tests/ai_scripts/` suites for the new phase and scanner/staging coverage from the repository root.
- [x] 4.5 Run `openspec status --change crp-099-optional-step-8-1-implementation-plan-semantic-review` and confirm the change is apply-ready.
