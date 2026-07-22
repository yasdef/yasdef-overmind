## Why

Not all implementation-plan quality problems are structural. Even with deterministic step-level requirement and evidence refs, a plan can still be semantically weak when one step bundles unrelated behaviors, mixes separate technical gaps into one slice, or links multiple EARS items that should be split into separate work. That judgment is primarily semantic and model-driven, not something shell parsing can enforce reliably. The workflow already has an optional review pattern at Step `4.1`, so Step `8` can use the same approach for semantic plan review.

## What Changes

- Add a new optional feature phase `8.1` after Step `8` named `Implementation Plan Semantic Review`.
- Stage a dedicated command for this optional phase, analogous to other staged feature commands.
- Define the phase as model-driven semantic review of:
  - `implementation_plan.md`
  - `requirements_ears.md`
  - `technical_requirements.md`
- Require the review to focus on cohesion and split recommendations, especially:
  - one step linking multiple unrelated EARS items,
  - one step spanning separate technical-requirements gaps without a real shared slice,
  - ordering or dependency choices that look structurally valid but semantically weak.
- Produce one durable review artifact that records findings and recommended plan splits or acceptances.
- Keep the phase optional by default, like Step `4.1`, so teams can run it when plan complexity or review risk justifies the extra pass.

## Capabilities

### New Capabilities

- `overmind-implementation-plan-semantic-review`: The workflow SHALL support an optional post-Step-8 model review phase that evaluates semantic cohesion and split quality of the shared implementation plan.
- `overmind-optional-feature-phase-8-1`: The feature pipeline SHALL support an optional Step `8.1` after implementation-plan generation, following the same optional-phase pattern used by Step `4.1`.

### Modified Capabilities

- `overmind-bootstrap-progress-checklist`: The progress definition and scanner contract SHALL represent Step `8.1` as optional when this phase is introduced.

## Impact

- Affected scripts:
  - `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`
  - `overmind/scripts/<new optional step-8.1 command>`
- Affected definitions/docs:
  - `overmind/templates/init_progress_definition_TEMPLATE.yaml`
  - `overmind/README.md`
  - `overmind/init_progress_definition_sequence_diagram.md`
- Affected tests:
  - `tests/ai_scripts/project_setup_asdlc_tests.sh`
  - `tests/ai_scripts/init_progress_scanner_tests.sh`
  - `tests/ai_scripts/<new step-8.1 tests>`
- New artifact:
  - one optional implementation-plan semantic-review artifact stored beside other feature-phase outputs
- Process impact:
  - Teams get a model-owned semantic quality pass for implementation-plan cohesion without overloading the deterministic structural helper.
