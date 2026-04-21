## 1. Extend the semantic-review contract

- [x] 1.1 Update `overmind/rules/implementation_plan_semantic_review_rule.md` to add the `delivered_surface_consumption_unclear` finding type and the required four-step delivered-surface access-path heuristic.
- [x] 1.2 Update `overmind/templates/implementation_plan_semantic_review_TEMPLATE.md` so the new finding type is documented as a semantic product-fit finding and terminal entries require `resolution_notes`.
- [x] 1.3 Update `overmind/golden_examples/implementation_plan_semantic_review_GOLDEN_EXAMPLE.md` to show both valid outcomes: `applied` when inbound affordance work is missing and `rejected` when intentional isolation is confirmed.

## 2. Bind the new review inputs

- [x] 2.1 Update `overmind/scripts/feature_implementation_plan_semantic_review.sh` so it always provides `implementation_plan.md`, `requirements_ears.md`, and `technical_requirements.md`, and additionally binds `prerequisite_gaps.md` plus the applicable repo-class surface-map artifacts when present.
- [x] 2.2 Update `overmind/scripts/helper/check_implementation_plan_semantic_review_quality.sh` so terminal `delivered_surface_consumption_unclear` findings with empty `resolution_notes` are rejected.

## 3. Add automated coverage

- [x] 3.1 Update `tests/ai_scripts/init_feature_implementation_plan_semantic_review_tests.sh` to prove a newly delivered route/page/screen/endpoint with no inbound affordance emits `delivered_surface_consumption_unclear`.
- [x] 3.2 Add a test proving the finding is not emitted when a sibling implementation-plan step adds the inbound affordance for the delivered surface.
- [x] 3.3 Add a validation test proving terminal `delivered_surface_consumption_unclear` entries fail when `resolution_notes` is empty.

## 4. Validate the change

- [x] 4.1 Run `bash tests/ai_scripts/init_feature_implementation_plan_semantic_review_tests.sh` from the repository root.
- [x] 4.2 Run `openspec status --change crp-110-semantic-review-delivered-surface-access-path-check` and confirm the change is apply-ready.
