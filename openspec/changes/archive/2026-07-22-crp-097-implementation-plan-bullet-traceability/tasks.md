## 1. Define the step-level FR traceability contract

- [x] 1.1 Update `overmind/rules/implementation_plan_rule.md` to define step-heading `REQ-*` / `NFR-*` links as the canonical functional-requirement traceability contract for implementation plans.
- [x] 1.2 Update `overmind/templates/implementation_plan_TEMPLATE.md` and `overmind/golden_examples/implementation_plan_GOLDEN_EXAMPLE.md` so each step heading demonstrates the required FR links while checklist bullets remain plain execution detail.
- [x] 1.3 Document that the implementation-plan stage reuses the authoritative requirement ids from `requirements_ears.md` for FR coverage instead of introducing a separate implementation-plan-only id namespace.

## 2. Implement generation and validation support

- [x] 2.1 Update `overmind/scripts/feature_implementation_plan.sh` so generated or refreshed plans keep one-or-more valid requirement ids on every step heading.
- [x] 2.2 Update `overmind/scripts/helper/check_implementation_plan_quality.sh` to fail when a step heading is missing requirement ids or references ids outside `requirements_ears.md`.
- [x] 2.3 Extend the helper so it fails when any requirement from `requirements_ears.md` is not represented by at least one implementation step heading.
- [x] 2.4 Ensure helper diagnostics identify uncovered requirement ids and the exact step headings with invalid or missing links deterministically.

## 3. Add automated coverage for the enabling contract

- [x] 3.1 Update `tests/ai_scripts/check_implementation_plan_quality_tests.sh` with passing coverage for valid step-level requirement links and failing coverage for missing or unknown heading-level requirement ids.
- [x] 3.2 Add test coverage proving the helper fails when one-or-more requirements from `requirements_ears.md` are left without any related implementation step.
- [x] 3.3 Update `tests/ai_scripts/init_feature_implementation_plan_tests.sh` so generated implementation plans show the expected step-level FR links in headings.

## 4. Validate change readiness

- [x] 4.1 Run the relevant `tests/ai_scripts/` suites for implementation-plan generation and quality validation from the repository root.
- [x] 4.2 Run `openspec status --change crp-097-implementation-plan-bullet-traceability` and confirm the change is apply-ready.
