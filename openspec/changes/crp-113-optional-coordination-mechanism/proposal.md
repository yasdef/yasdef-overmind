## Why

Once typed coordination signals exist in `technical_requirements.md`, the planner needs a way to act on them — but only when a shared contract artifact genuinely must be clarified before downstream implementation can proceed safely. Without this, coordination signals are informative but toothless; with a mandatory regime, every multi-repo feature accumulates management scaffolding that delays required operator-facing delivery.

## What Changes

- Update `overmind/rules/implementation_slices_rule.md` to allow an optional coordination slice kind, emitted only when evidence shows genuine cross-repo contract ambiguity or drift risk.
- Update `overmind/templates/implementation_slices_TEMPLATE.md` and its golden example to show both valid paths: with a coordination slice and without one.
- Update `overmind/rules/implementation_plan_rule.md` to allow a coordination slice to be lifted into a plan step only when downstream implementation work is actually blocked by the unresolved artifact.
- Update `overmind/scripts/helper/check_implementation_slices_quality.sh` and `check_implementation_plan_quality.sh` so coordination artifact absence remains a valid outcome.
- Add tests proving both scenarios pass quality: one feature with coordination work, one without.

## Capabilities

### New Capabilities
- `optional-coordination-slices`: Rules, templates, quality checks, and tests for evidence-gated coordination slices and plan steps in the implementation pipeline.

### Modified Capabilities

(none — no existing specs)

## Impact

- `overmind/rules/implementation_slices_rule.md`
- `overmind/rules/implementation_plan_rule.md`
- `overmind/templates/implementation_slices_TEMPLATE.md`
- `overmind/scripts/helper/check_implementation_slices_quality.sh`
- `overmind/scripts/helper/check_implementation_plan_quality.sh`
- `tests/ai_scripts/check_implementation_slices_quality_tests.sh`
- `tests/ai_scripts/check_implementation_plan_quality_tests.sh`
