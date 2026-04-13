## Why

The current Step `8` tries to discover execution slices, enforce ordering, and satisfy full traceability in one pass. In practice that pulls planning toward the shape of `technical_requirements.md` and its component/gap coverage, which makes the output traceability-driven instead of implementation-driven, especially for scaffold-level frontend work.

## What Changes

- Add a new required Step `8.1` before ordered implementation-plan generation.
- Introduce a dedicated slice-planning artifact, tentatively `implementation_slices.md`, that captures implementation-driven work slices before final step numbering and full traceability enforcement.
- Define Step `8.1` to prioritize thin executable slices, first usable product increments, scaffold-aware frontend decomposition, and minimal local prerequisite capture.
- Allow Step `8.1` to use `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, and the relevant surface-map artifacts so slice discovery can recover execution context that is flattened during technical-requirements consolidation.
- Explicitly forbid Step `8.1` from forcing total step ordering or full traceability coverage across every requirement and evidence token; those concerns move to the next phase.
- Stage a dedicated command, rule, template, golden example, and quality helper for Step `8.1`.

## Capabilities

### New Capabilities

- `overmind-implementation-slice-planning`: The workflow SHALL generate implementation-driven feature slices before ordered shared-plan generation.
- `overmind-feature-phase-8-1-implementation-slice-planning`: The feature pipeline SHALL include a required Step `8.1` that produces a slice-planning artifact grounded in current repo state but optimized for execution slicing rather than final ordering.

### Modified Capabilities

- `overmind-bootstrap-progress-checklist`: The progress-definition and scanner contract SHALL add a new required Step `8.1` and track its artifact completion before Step `8.2`.
- `overmind-process-artifact-ownership`: Coordinator-owned planning assets SHALL include the new Step `8.1` rule, template, golden example, and staged command under `overmind/`.

## Impact

- New scripts/helpers:
  - `overmind/scripts/feature_implementation_slices.sh`
  - `overmind/scripts/helper/check_implementation_slices_quality.sh`
- New rule/template/example artifacts:
  - `overmind/rules/implementation_slices_rule.md`
  - `overmind/templates/implementation_slices_TEMPLATE.md`
  - `overmind/golden_examples/implementation_slices_GOLDEN_EXAMPLE.md`
- Affected bootstrap/docs:
  - `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`
  - `overmind/scripts/project_mgmt/project_setup_update_project.sh`
  - `overmind/templates/init_progress_definition_TEMPLATE.yaml`
  - `overmind/init_progress_definition_sequence_diagram.md`
  - `overmind/README.md`
- Affected tests:
  - `tests/ai_scripts/project_setup_asdlc_tests.sh`
  - `tests/ai_scripts/init_progress_scanner_tests.sh`
  - `tests/ai_scripts/<new step-8-1 slice-planning tests>`
- Process impact:
  - Step `8.1` becomes the place where the workflow discovers the actual execution slices before any later phase optimizes ordering or restores full traceability.
