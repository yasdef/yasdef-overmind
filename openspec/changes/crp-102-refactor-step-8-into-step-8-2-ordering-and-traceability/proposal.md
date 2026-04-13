## Why

Once slice discovery is split into a dedicated Step `8.1`, the current implementation-plan phase should stop acting as the first slicer. Its job should become turning already-good slices into one efficient, correctly ordered, fully traceable shared plan, including parallelism where possible and explicit prerequisites where necessary.

## What Changes

- Refactor the current Step `8` into Step `8.2` focused on ordered-plan assembly rather than initial slice discovery.
- Change the phase inputs so Step `8.2` consumes the Step `8.1` slice-planning artifact together with `requirements_ears.md`, `technical_requirements.md`, and `feature_contract_delta.md`.
- Require Step `8.2` to optimize for efficient dependency ordering, including rules such as:
  - shared contract or common prerequisite work first,
  - backend and frontend work in parallel when no hard dependency blocks parallel execution,
  - explicit dependency edges only where justified by real contract, state, schema, or prerequisite constraints.
- Require Step `8.2` to preserve Step `8.1` slices by default.
- Allow Step `8.2` to reorder slices, split overloaded slices, add prerequisite slices, or merge slices only when merge-eligibility conditions are satisfied and the merge rationale is recorded in the final plan artifact.
- Forbid Step `8.2` from merging slices solely for step-count reduction, requirement-grouping convenience, or component-traceability convenience, including collapsing scaffold-heavy frontend slices back into broad bucket steps without a hard dependency.
- Keep final repo ownership, `REQ-*` / `NFR-*` coverage, technical-evidence coverage, and `implementation_plan.md` output as Step `8.2` responsibilities.
- Update the quality gate so it validates ordered-plan correctness and traceability after slice planning, instead of forcing the initial slicing pass to satisfy everything at once.

## Capabilities

### New Capabilities

- `overmind-implementation-plan-ordering-and-traceability`: The workflow SHALL transform implementation-driven slices into one ordered, dependency-aware, fully traceable shared implementation plan.

### Modified Capabilities

- `overmind-bootstrap-progress-checklist`: The progress-definition and scanner contract SHALL treat ordered shared-plan generation as Step `8.2` following the new Step `8.1`.
- `overmind-process-artifact-ownership`: Coordinator-owned implementation-plan assets SHALL be updated so the existing Step `8` planning command, rule, template, and helper become the Step `8.2` ordering-and-traceability phase contract.

## Impact

- Affected scripts/helpers:
  - `overmind/scripts/feature_implementation_plan.sh`
  - `overmind/scripts/helper/check_implementation_plan_quality.sh`
- Affected rule/template/example artifacts:
  - `overmind/rules/implementation_plan_rule.md`
  - `overmind/templates/implementation_plan_TEMPLATE.md`
  - `overmind/golden_examples/implementation_plan_GOLDEN_EXAMPLE.md`
- Affected bootstrap/docs:
  - `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`
  - `overmind/scripts/project_mgmt/project_setup_update_project.sh`
  - `overmind/templates/init_progress_definition_TEMPLATE.yaml`
  - `overmind/init_progress_definition_sequence_diagram.md`
  - `overmind/README.md`
- Affected tests:
  - `tests/ai_scripts/init_feature_implementation_plan_tests.sh`
  - `tests/ai_scripts/check_implementation_plan_quality_tests.sh`
  - `tests/ai_scripts/project_setup_asdlc_tests.sh`
- Process impact:
  - The final shared plan stays deterministic and traceable, but it is now derived from execution-first slices instead of raw component/gap grouping.
