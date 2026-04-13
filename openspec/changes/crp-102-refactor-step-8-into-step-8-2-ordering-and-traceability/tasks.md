## 1. Refactor Step 8.2 implementation-plan contract assets

- [x] 1.1 Update `overmind/scripts/feature_implementation_plan.sh` so Step `8.2` requires `implementation_slices.md` and assembles the final plan from Step `8.1` slices plus `requirements_ears.md`, `technical_requirements.md`, and `feature_contract_delta.md`.
- [x] 1.2 Update `overmind/rules/implementation_plan_rule.md` with Step `8.2` guardrails for default slice preservation, allowed transformations (reorder/split/prerequisite insertion/eligible merge), and forbidden convenience-only merges.
- [x] 1.3 Update `overmind/templates/implementation_plan_TEMPLATE.md` and `overmind/golden_examples/implementation_plan_GOLDEN_EXAMPLE.md` to show dependency-aware ordering, parallelizable slices, explicit dependency rationale, and recorded transformation rationale.

## 2. Enforce ordered-plan traceability quality gates

- [x] 2.1 Update `overmind/scripts/helper/check_implementation_plan_quality.sh` to validate Step `8.2` ordering correctness, dependency-edge justification, and full `REQ-*` / `NFR-*` plus technical-evidence coverage after ordered-plan assembly.
- [x] 2.2 Add deterministic helper diagnostics for missing Step `8.1` input, unsupported merge rationale, invalid dependency edges, and uncovered traceability obligations.

## 3. Align Step numbering, staging, and documentation

- [x] 3.1 Update `overmind/templates/init_progress_definition_TEMPLATE.yaml` so planning phases declare required Step `8.1` (slice planning) followed by required Step `8.2` (ordered-plan assembly and traceability).
- [x] 3.2 Update `overmind/init_progress_definition_sequence_diagram.md` and `overmind/README.md` to describe Step `8.2` responsibilities and input/output expectations.
- [x] 3.3 Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`, `overmind/scripts/project_mgmt/project_setup_update_project.sh`, and related staged setup assets so Step `8.2` command/rule/template/helper wiring is consistent with the new phase contract.

## 4. Add and run regression coverage

- [x] 4.1 Update `tests/ai_scripts/init_feature_implementation_plan_tests.sh` for Step `8.2` input validation, slice-preservation defaults, allowed transformation behavior, and explicit dependency-order output.
- [x] 4.2 Update `tests/ai_scripts/check_implementation_plan_quality_tests.sh` for ordered-plan traceability, dependency-justification validation, and forbidden convenience-merge failures.
- [x] 4.3 Update `tests/ai_scripts/project_setup_asdlc_tests.sh` and `tests/ai_scripts/init_progress_scanner_tests.sh` to verify Step `8.1`/`8.2` numbering and staging alignment.
- [x] 4.4 Run the relevant `tests/ai_scripts/` suites from repository root and confirm `openspec status --change crp-102-refactor-step-8-into-step-8-2-ordering-and-traceability` is apply-ready.
