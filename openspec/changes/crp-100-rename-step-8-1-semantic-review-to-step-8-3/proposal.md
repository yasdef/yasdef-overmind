## Why

If the workflow introduces a new Step `8.1` for implementation-driven slicing and moves the current shared-plan generation into Step `8.2`, the existing optional semantic-review phase can no longer stay numbered as `8.1`. Keeping the old numbering would make prompts, scanner output, docs, and handoff discussions misleading even if the semantic-review behavior itself remains unchanged.

## What Changes

- Renumber the optional `Implementation Plan Semantic Review` phase from Step `8.1` to Step `8.3`.
- Keep the semantic-review behavior optional and model-driven, but move its position so it runs only after the new Step `8.1` slice-planning phase and the revised Step `8.2` ordering-and-traceability phase.
- Update the progress-definition artifacts, bootstrap/setup flows, diagrams, README guidance, and staged command references so they consistently describe semantic review as Step `8.3`.
- Update scanner and checklist expectations so optional-phase reporting no longer treats semantic review as the immediate successor to Step `8`.
- Preserve the existing semantic-review artifact contract and decision ledger behavior unless a later change explicitly revises them.

## Capabilities

### New Capabilities

- `overmind-optional-feature-phase-8-3`: The feature workflow SHALL support `Implementation Plan Semantic Review` as an optional Step `8.3` that runs after slice planning and ordered-plan generation are complete.

### Modified Capabilities

- `overmind-bootstrap-progress-checklist`: The progress-definition and scanner contract SHALL represent semantic review as optional Step `8.3` instead of optional Step `8.1`.

## Impact

- Affected scripts:
  - `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`
  - `overmind/scripts/project_mgmt/project_setup_update_project.sh`
  - `overmind/scripts/feature_implementation_plan_semantic_review.sh`
- Affected definitions/docs:
  - `overmind/templates/init_progress_definition_TEMPLATE.yaml`
  - `overmind/init_progress_definition_sequence_diagram.md`
  - `overmind/README.md`
- Affected tests:
  - `tests/ai_scripts/project_setup_asdlc_tests.sh`
  - `tests/ai_scripts/init_progress_scanner_tests.sh`
  - `tests/ai_scripts/init_feature_implementation_plan_semantic_review_tests.sh`
- Process impact:
  - The semantic-review phase keeps its current purpose, but all workflow references, optional-phase sequencing, and operator expectations move from `8.1` to `8.3`.
