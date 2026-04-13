## 1. Define the step-level unresolved-work and justification contract

- [x] 1.1 Update `overmind/rules/implementation_plan_rule.md` to keep FR links on step headings and introduce a step-scoped `#### Evidence:` line for technical-requirements links.
- [x] 1.2 Update `overmind/templates/implementation_plan_TEMPLATE.md` and `overmind/golden_examples/implementation_plan_GOLDEN_EXAMPLE.md` so each implementation step demonstrates both heading-level `REQ-*` / `NFR-*` refs and step-level `#### Evidence:` refs.
- [x] 1.3 Document that unresolved-work coverage and justification operate on implementation steps only, not on checklist bullets.

## 2. Implement generation and helper enforcement

- [x] 2.1 Update `overmind/scripts/feature_implementation_plan.sh` so generated or refreshed plans emit `#### Evidence:` lines with valid `gap/TECH_REQ-<n>` and `comp/<component-slug>` tokens.
- [x] 2.2 Update `overmind/scripts/helper/check_implementation_plan_quality.sh` to validate `#### Evidence:` presence, token shape, and token resolution against `technical_requirements.md`.
- [x] 2.3 Extend the helper so it fails when unresolved requirement-gap or impacted-component entries from `technical_requirements.md` are not represented by at least one implementation step.
- [x] 2.4 Ensure helper diagnostics identify uncovered unresolved work and unsupported steps deterministically.

## 3. Add automated coverage for the step-level gates

- [x] 3.1 Update `tests/ai_scripts/check_implementation_plan_quality_tests.sh` with passing coverage for valid step-level evidence refs and failing coverage for missing evidence lines or invalid evidence tokens.
- [x] 3.2 Add test coverage proving the helper fails when unresolved requirement-gap or impacted-component entries are left without any related implementation step.
- [x] 3.3 Update `tests/ai_scripts/init_feature_implementation_plan_tests.sh` so generated implementation plans show the expected step-level `#### Evidence:` metadata alongside heading-level FR refs.

## 4. Validate change readiness

- [x] 4.1 Run the relevant `tests/ai_scripts/` suites for implementation-plan generation and quality validation from the repository root.
- [x] 4.2 Run `openspec status --change crp-098-implementation-plan-gap-coverage-and-justification-gates` and confirm the change is apply-ready.
