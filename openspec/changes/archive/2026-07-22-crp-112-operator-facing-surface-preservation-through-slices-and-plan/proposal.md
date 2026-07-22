## Why

`crp-109` closes prerequisite-gap tracing, but the planning pipeline can still lose the actual required operator-facing delivery surface during later transformations. When `requirements_ears.md` and prerequisite analysis both show that a missing login, entry route, workspace shell, page, or screen is required, Step `8.1` and Step `8.3` can still drift toward API, state, security, contract, or coordination work and stop scheduling the surface itself.

This is the most important remaining planning regression to block in the rebuild because it breaks direct alignment to required behavior even when upstream analysis is otherwise correct.

## What Changes

- Extend prerequisite-gap semantics so required missing `user_reachable_surface` items remain explicitly distinguishable from transport-only or internal execution gaps for downstream planning phases.
- Update Step `8.1` slice-planning rules so every required missing operator-facing surface from upstream evidence is preserved by at least one feature-delivery slice until the surface is covered.
- Update Step `8.3` implementation-plan rules so the same required missing operator-facing surface is preserved by at least one implementation-plan step until delivered; surrounding coordination, API, auth, or state work may be added, but it cannot replace the surface-delivery work.
- Add slice-level and plan-level quality checks that fail when unresolved required operator-facing surfaces from upstream artifacts disappear during transformation.
- Add targeted slice-level, plan-level, and prerequisite-gap regression coverage for representative regressions including a missing login surface, missing protected shell, missing admin entry route, and missing operator-facing lookup page.
- Make the preservation rule evidence-driven rather than route-name-driven: it must work from `requirements_ears.md`, technical analysis, and prerequisite-gap meaning instead of brittle string matches tied to one route name or one UI framework.
- Keep the non-goals explicit in the contract:
  - do not fabricate user-facing work when `requirements_ears.md` does not require a user-facing surface;
  - do not count coordination, contract, API, or auth scaffolding as satisfying a missing operator-facing surface;
  - do not force navigation-affordance work from this rule alone;
  - do not let a contract-first transformation hide the actual required operator outcome.

## Capabilities

### New Capabilities

- `overmind-operator-facing-surface-preservation`: The planning pipeline SHALL preserve each required missing operator-facing surface from upstream requirement evidence as explicit delivery work through slice generation and implementation-plan generation until it is delivered.
- `overmind-implementation-slices-operator-facing-surface-preservation-gate`: The implementation-slices quality helper SHALL fail when unresolved required operator-facing surfaces from upstream artifacts are not represented by at least one feature-delivery slice.
- `overmind-implementation-plan-operator-facing-surface-preservation-gate`: The implementation-plan quality helper SHALL fail when unresolved required operator-facing surfaces from upstream artifacts are not represented by at least one implementation-plan step.

### Modified Capabilities

- `overmind-prerequisite-gap-trace`: `prerequisite_gaps.md` SHALL distinguish required missing `user_reachable_surface` items from transport-only or internal execution gaps so downstream preservation logic can consume them deterministically.
- `overmind-implementation-slice-planning`: Step `8.1` SHALL preserve required missing operator-facing surfaces from prerequisite evidence and SHALL not replace them with supporting scaffolding-only slices.
- `overmind-implementation-plan-ordering-and-traceability`: Step `8.3` SHALL preserve the same required missing operator-facing surfaces through ordered-plan generation until delivered and SHALL not treat supporting scaffolding as fulfillment.

## Impact

- Affected rules:
  - `overmind/rules/implementation_slices_rule.md`
  - `overmind/rules/implementation_plan_rule.md`
  - `overmind/rules/prerequisite_gaps_rule.md`
- Affected scripts/helpers:
  - `overmind/scripts/helper/check_prerequisite_gaps_quality.sh`
  - `overmind/scripts/helper/check_implementation_slices_quality.sh`
  - `overmind/scripts/helper/check_implementation_plan_quality.sh`
- Affected tests:
  - `tests/ai_scripts/check_prerequisite_gaps_quality_tests.sh`
  - `tests/ai_scripts/check_implementation_slices_quality_tests.sh`
  - `tests/ai_scripts/check_implementation_plan_quality_tests.sh`
  - `tests/ai_scripts/init_feature_implementation_slices_tests.sh`
  - `tests/ai_scripts/init_feature_implementation_plan_tests.sh`
- Depends on the upstream evidence model introduced by `crp-108` and the prerequisite-gap trace introduced by `crp-109`.
- Process impact:
  - required operator-facing surfaces from `requirements_ears.md` can no longer disappear behind infrastructure, coordination, contract, API, or auth work during Step `8.1` and Step `8.3`;
  - this change preserves required surfaces only and does not, by itself, decide inbound navigation or operator affordance design.
- No new CLI flags or options are required by this change.
