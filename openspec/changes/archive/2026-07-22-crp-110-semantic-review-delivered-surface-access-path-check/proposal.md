## Why

The current planning pipeline can schedule delivery of a new `user_reachable_surface` and still miss the practical operator question: how does someone actually get to it? `crp-109` closes prerequisite-gap tracing for required upstream surfaces, but semantic review still lacks a dedicated check for newly delivered surfaces that are technically added yet remain unreachable because no inbound affordance exists or is planned.

## What Changes

- Extend implementation-plan semantic review so it explicitly checks whether each newly delivered user-reachable surface has an existing or newly planned inbound affordance.
- Add a dedicated semantic-review finding type for cases where delivered-surface access-path consumption is unclear and requires operator/product judgment rather than a hard structural failure.
- Require the semantic review context to include prerequisite-gap output and active repo-class surface maps when they exist, so the reviewer can inspect inbound reachability with grounded evidence.
- Update the semantic-review template and examples to show both valid outcomes: applying the finding when inbound access work is missing, and rejecting it when intentional isolation is confirmed.
- Enforce that this finding type cannot reach a terminal state without non-empty resolution notes explaining the decision.

## Capabilities

### New Capabilities

- `overmind-semantic-review-delivered-surface-access-path-check`: The semantic review workflow SHALL evaluate each newly delivered user-reachable surface for inbound operator reachability and SHALL raise a product-fit finding when access-path coverage is unclear.

### Modified Capabilities

- `overmind-implementation-plan-semantic-review`: The semantic-review artifact contract SHALL support a `delivered_surface_consumption_unclear` finding type, require the four-step delivered-surface heuristic, and consume surface-map and prerequisite-gap evidence when applicable.

## Impact

- Affected scripts:
  - `overmind/scripts/feature_implementation_plan_semantic_review.sh`
  - `overmind/scripts/helper/check_implementation_plan_semantic_review_quality.sh`
- Affected rule/template/example artifacts:
  - `overmind/rules/implementation_plan_semantic_review_rule.md`
  - `overmind/templates/implementation_plan_semantic_review_TEMPLATE.md`
  - `overmind/golden_examples/implementation_plan_semantic_review_GOLDEN_EXAMPLE.md`
- Affected tests:
  - `tests/ai_scripts/init_feature_implementation_plan_semantic_review_tests.sh`
- Process impact:
  - Step `8.3` semantic review becomes capable of flagging plans that technically add a route, page, screen, CLI command, or endpoint without establishing how an operator actually reaches it.
