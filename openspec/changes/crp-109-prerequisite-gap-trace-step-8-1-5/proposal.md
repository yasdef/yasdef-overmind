## Why

Even after `crp-098` enforces unresolved-work coverage and step-level evidence, the implementation-plan helper still cannot detect a missing user-reachable prerequisite. The helper only checks that every unresolved-gap entry from `technical_requirements.md` is touched by a plan step. It does not walk the operator-visible journey behind each EARS requirement and verify that every entry point on that journey is either present in the repo or scheduled in the plan.

Real example from the live project: a frontend implementation step "Add protected workspace route + redirect to `/admin/login` on session-invalid" passed the `crp-098` gate because every gap token resolved, yet `/admin/login` had no working sign-in page in the repo and no plan step was scheduled to add one. The plan was structurally sound by the existing rules and still incorrect.

The fix is structural: derive the prerequisite chain explicitly from EARS journeys, gate the plan on it, and ground "what already exists" on the transport vs user-reachable split introduced by `crp-108`.

## What Changes

- Add a new required Step `8.1.5` between Step `8.1` (slices) and Step `8.2` (plan): "Prerequisite Gap Trace."
- Introduce a dedicated `prerequisite_gaps.md` artifact whose entries each take one EARS requirement, list the operator-visible steps required to satisfy it, and mark each prerequisite as `present_in_repo`, `scheduled_in_slices`, or `unmet`.
- Define presence detection to consume the `crp-108` `user_reachable_surface` subfield as the source of truth; transport-layer presence alone never marks a prerequisite as `present_in_repo`.
- Gate `prerequisite_gaps.md` readiness on having no `unmet` entries: any `unmet` prerequisite must be promoted into `implementation_slices.md` (and therefore into the eventual plan) before Step `8.2` can start.
- Stage a dedicated rule, template, golden example, command, and quality helper for Step `8.1.5`.
- Extend `check_implementation_plan_quality.sh` to fail when `implementation_plan.md` does not cover every prerequisite that `prerequisite_gaps.md` marked `scheduled_in_slices`.
- Update the sequence diagram, the progress-definition template, the e2e orchestrator, and the README to reflect the new step in the pipeline.

## Capabilities

### New Capabilities

- `overmind-prerequisite-gap-trace`: The workflow SHALL derive a deterministic list of user-reachable prerequisites per EARS requirement and SHALL fail planning when any prerequisite is unmet.
- `overmind-feature-phase-8-1-5-prerequisite-gap-trace`: The feature pipeline SHALL include a required Step `8.1.5` that produces `prerequisite_gaps.md` between Step `8.1` and Step `8.2`.
- `overmind-implementation-plan-prerequisite-coverage-gate`: The implementation-plan quality helper SHALL fail when prerequisites scheduled in `prerequisite_gaps.md` are not covered by at least one implementation step in `implementation_plan.md`.

### Modified Capabilities

- `overmind-bootstrap-progress-checklist`: The progress-definition and scanner contract SHALL add a new required Step `8.1.5` and track its artifact completion before Step `8.2`.
- `overmind-process-artifact-ownership`: Coordinator-owned planning assets SHALL include the new Step `8.1.5` rule, template, golden example, and staged command under `overmind/`.

## Impact

- New scripts/helpers:
  - `overmind/scripts/feature_prerequisite_gaps.sh`
  - `overmind/scripts/helper/check_prerequisite_gaps_quality.sh`
- New rule/template/example artifacts:
  - `overmind/rules/prerequisite_gaps_rule.md`
  - `overmind/templates/prerequisite_gaps_TEMPLATE.md`
  - `overmind/golden_examples/prerequisite_gaps_GOLDEN_EXAMPLE.md`
- Affected scripts:
  - `overmind/scripts/feature_implementation_plan.sh` (consume `prerequisite_gaps.md`)
  - `overmind/scripts/helper/check_implementation_plan_quality.sh` (cross-check coverage)
  - `overmind/scripts/project_mgmt/project_add_feature_e2e.sh` (orchestrate Step `8.1.5`)
  - `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`
  - `overmind/scripts/project_mgmt/project_setup_update_project.sh`
  - `overmind/scripts/project_mgmt/init_progress_scanner.sh`
- Affected docs/templates:
  - `overmind/init_progress_definition_sequence_diagram.md`
  - `overmind/templates/init_progress_definition_TEMPLATE.yaml`
  - `overmind/README.md`
- Affected tests:
  - `tests/ai_scripts/init_progress_scanner_tests.sh`
  - `tests/ai_scripts/check_implementation_plan_quality_tests.sh`
  - `tests/ai_scripts/<new step-8-1-5 prerequisite-gap tests>`
- Depends on `crp-108` for the transport vs user-reachable split that grounds prerequisite presence detection.
- Process impact:
  - Step `8.1.5` becomes a hard gate ahead of Step `8.2`. Plans cannot start ordering work until every operator-visible prerequisite for every targeted EARS requirement is either present in the repo (proven via `user_reachable_surface`) or already scheduled in `implementation_slices.md`.
  - Eliminates the failure mode where a plan jumps to protected functionality without scheduling the entry-point work that makes it operator-reachable.
