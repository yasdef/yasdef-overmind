## Why

Once `crp-097` moves functional-requirement traceability to implementation-plan steps, the next quality gap becomes visible: the current plan gate still cannot prove that all unresolved feature work from `technical_requirements.md` is represented in the plan, and it cannot reject implementation steps that are not grounded in current-state technical evidence. That leaves room for both omissions and invented work.

This change should stay at step scope. We do not want plan-bullet links; we want the helper to reason over implementation steps as the planning unit.

## What Changes

- Add an unresolved-work coverage gate for implementation plans.
- Keep functional-requirement links on implementation step headings, not on checklist bullets.
- Add deterministic step-level technical-evidence links so each implementation step can point to unresolved requirement-gap or impacted-component evidence from `technical_requirements.md`.
- Require every unresolved requirement or impacted component in `technical_requirements.md` with remaining feature work to be covered by at least one implementation step in `implementation_plan.md`.
- Add a complementary justification gate that fails when an implementation step cannot be tied back to both:
  - behavior from `requirements_ears.md`, and
  - evidence or gap data from `technical_requirements.md`.
- Define deterministic helper output that reports uncovered unresolved work and unsupported implementation steps with actionable identifiers.
- Keep already completed technical-requirements items outside the mandatory-coverage set unless the plan includes them deliberately as prerequisite-state context.
- Add tests covering uncovered gaps, unsupported steps, and valid plans with complete unresolved-work coverage.

## Capabilities

### New Capabilities

- `overmind-implementation-plan-unresolved-work-coverage-gate`: The implementation-plan quality helper SHALL fail when unresolved feature work from `technical_requirements.md` is not represented in implementation-plan steps.
- `overmind-implementation-plan-step-justification-gate`: The implementation-plan quality helper SHALL fail when a plan step is not justified by both step-level requirement links and step-level technical-requirements evidence.

### Modified Capabilities

- `overmind-implementation-plan-step-fr-traceability`: Step-level FR refs SHALL remain the canonical requirement links and SHALL compose with step-level technical-evidence refs for helper-enforced coverage and justification checks.

## Impact

- Affected scripts:
  - `overmind/scripts/helper/check_implementation_plan_quality.sh`
  - `overmind/scripts/feature_implementation_plan.sh`
- Affected rule/template/example artifacts:
  - `overmind/rules/implementation_plan_rule.md`
  - `overmind/templates/implementation_plan_TEMPLATE.md`
  - `overmind/golden_examples/implementation_plan_GOLDEN_EXAMPLE.md`
- Affected tests:
  - `tests/ai_scripts/check_implementation_plan_quality_tests.sh`
  - `tests/ai_scripts/init_feature_implementation_plan_tests.sh`
- Process impact:
  - Shared implementation plans can be rejected for both missing unresolved work and unsupported implementation steps.
