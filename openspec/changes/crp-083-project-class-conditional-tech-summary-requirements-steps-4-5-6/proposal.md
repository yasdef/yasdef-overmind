## Why

Steps 4, 5, and 6 currently treat both `project_tech_summary_be.md` and `project_tech_summary_fe.md` as unconditional requirements. This creates false blocking for backend-only or frontend/mobile-only repositories, and also for repositories where `meta_info.project_classes` is still empty.

We need declarative, metadata-driven conditional requirements so these tech-summary artifacts are required only when the declared project classes make them applicable.

## What Changes

- Extend the step-definition contract in `overmind/init_progress_definition.yaml` so entries under both:
  - `finished_only_if_artefacts_present`
  - `input_required`
  can declare a conditional requirement guard (for example `required_if`).
- Define structured predicate semantics for `meta_info.project_classes` (for example `any_of`) instead of free-form string conditions.
- Apply conditional guards to tech-summary entries in Steps 4, 5, and 6:
  - `project_tech_summary_be.md` required only when `project_classes` contains `backend`.
  - `project_tech_summary_fe.md` required only when `project_classes` contains `frontend` or `mobile`.
- Keep baseline behavior deterministic:
  - entries without `required_if` remain always required;
  - when `project_classes` is empty or has no matching class, guarded entries are non-mandatory;
  - when both backend and frontend/mobile are present, both guarded entries are mandatory.
- Update scanner evaluation to honor conditional guards for `finished_only_if_artefacts_present` in Step 4.
- Update scripts that consume `input_required` contracts to honor the same conditional guard semantics for Steps 5 and 6.
- Add regression tests for backend-only, frontend/mobile-only, fullstack, and empty-`project_classes` cases across Step 4 completion and Step 5/6 input requirement evaluation.

## Capabilities

### New Capabilities
- `overmind-conditional-step-requirements`: Overmind step contracts SHALL support declarative `meta_info.project_classes`-based conditional requirement guards for required artifacts and required inputs.

### Modified Capabilities
- `overmind-bootstrap-progress-checklist`: Step completion evaluation SHALL support conditional artifact requirements in `finished_only_if_artefacts_present` so Step 4 no longer requires non-applicable tech-summary files.

## Impact

- Affected config:
  - `overmind/init_progress_definition.yaml`
- Affected scripts:
  - `overmind/scripts/init_progress_scanner.sh`
  - scripts that evaluate `input_required` contracts for readiness gating in Steps 5 and 6
- Affected tests:
  - `tests/ai_scripts/init_progress_scanner_tests.sh`
  - tests covering input-required contract evaluation for Steps 5 and 6
- No new CLI flags/options are required by this change.
