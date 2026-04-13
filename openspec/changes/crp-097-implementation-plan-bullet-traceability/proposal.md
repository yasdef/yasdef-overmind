## Why

`implementation_plan.md` already carries requirement references on step headings, but the current contract treats them mostly as lightweight summary labels. The helper validates that referenced requirement ids exist, yet it still cannot prove full functional-requirement coverage across the plan: a requirement from `requirements_ears.md` can be left without any related implementation step and still escape detection.

We do not need bullet-level traceability for this change. What we need is a reliable step-level link between functional requirements and implementation planning so we can answer two questions deterministically:
- is every implementation step backed by at least one functional requirement, and
- does every functional requirement have at least one related implementation step?

## What Changes

- Formalize step-heading requirement links as the canonical functional-requirement traceability contract for shared implementation plans.
- Keep requirement links on `### Step ...` headings rather than on checklist bullets.
- Treat the existing `REQ-*` / `NFR-*` ids from `requirements_ears.md` as the authoritative functional-requirement links for this stage instead of inventing a separate link namespace.
- Require every implementation step to reference at least one valid functional requirement in its heading.
- Add a reverse coverage gate that fails when any functional requirement from `requirements_ears.md` is not represented by at least one implementation step.
- Update the implementation-plan template, golden example, rule file, and quality-helper expectations to reflect step-level FR coverage.
- Add script tests covering valid step-level links, missing requirement links, uncovered functional requirements, and staged feature-path compatibility.

## Capabilities

### New Capabilities

- `overmind-implementation-plan-step-fr-traceability`: Shared implementation plans SHALL support deterministic step-level traceability between functional requirements and implementation steps, including full requirement-to-step coverage.

## Impact

- Affected scripts:
  - `overmind/scripts/feature_implementation_plan.sh`
  - `overmind/scripts/helper/check_implementation_plan_quality.sh`
- Affected rule/template/example artifacts:
  - `overmind/rules/implementation_plan_rule.md`
  - `overmind/templates/implementation_plan_TEMPLATE.md`
  - `overmind/golden_examples/implementation_plan_GOLDEN_EXAMPLE.md`
- Affected tests:
  - `tests/ai_scripts/init_feature_implementation_plan_tests.sh`
  - `tests/ai_scripts/check_implementation_plan_quality_tests.sh`
- Process impact:
  - Implementation-plan quality can reject plans that leave functional requirements without any related implementation step.
