## 1. Preserve operator-facing surface identity upstream

- [x] 1.1 Update `overmind/rules/prerequisite_gaps_rule.md` so required missing `user_reachable_surface` prerequisites remain explicitly identifiable for downstream preservation and stay distinguishable from transport-only or internal execution gaps.
- [x] 1.2 Update `overmind/templates/prerequisite_gaps_TEMPLATE.md` and `overmind/golden_examples/prerequisite_gaps_GOLDEN_EXAMPLE.md` so the preserved operator-facing surface identity is visible in the artifact shape and examples.
- [x] 1.3 Update `overmind/scripts/feature_prerequisite_gaps.sh` and any related validation logic so generated `prerequisite_gaps.md` output retains stable named operator-facing surface identity when entries move from `unmet` to `scheduled_in_slices`.
- [x] 1.4 Update `overmind/scripts/helper/check_prerequisite_gaps_quality.sh` so it validates that preserved operator-facing surfaces remain distinguishable from transport-only/internal gaps and stay stable enough for downstream preservation checks.
- [x] 1.5 Update `tests/ai_scripts/check_prerequisite_gaps_quality_tests.sh` with passing and failing cases for required missing operator-facing surfaces versus transport-only/internal gaps, including preservation across `unmet` to `scheduled_in_slices` transitions.

## 2. Preserve required surfaces in Step 8.1 slices

- [x] 2.1 Update `overmind/rules/implementation_slices_rule.md` so Step `8.1` must preserve each required missing operator-facing surface in at least one explicit feature-delivery slice.
- [x] 2.2 Update `overmind/templates/implementation_slices_TEMPLATE.md` and `overmind/golden_examples/implementation_slices_GOLDEN_EXAMPLE.md` to show valid preserved-surface slices and invalid supporting-only substitutions.
- [x] 2.3 Update `overmind/scripts/feature_implementation_slices.sh` so generated slices keep required operator-facing surface delivery explicit instead of collapsing the work into auth, API, contract, state, or coordination slices.
- [x] 2.4 Update `overmind/scripts/helper/check_implementation_slices_quality.sh` to fail when a required missing operator-facing surface disappears from `implementation_slices.md` or is represented only by supporting scaffolding work.

## 3. Preserve required surfaces in Step 8.3 plans

- [x] 3.1 Update `overmind/rules/implementation_plan_rule.md` so Step `8.3` must retain explicit plan coverage for each required missing operator-facing surface preserved by upstream artifacts and slices.
- [x] 3.2 Update `overmind/templates/implementation_plan_TEMPLATE.md` and `overmind/golden_examples/implementation_plan_GOLDEN_EXAMPLE.md` to show plan steps that preserve missing login/page/shell/route delivery and to show that supporting-only work is insufficient.
- [x] 3.3 Update `overmind/scripts/feature_implementation_plan.sh` so final plan generation preserves explicit delivery of required operator-facing surfaces even when surrounding supporting work is reordered, split, or merged.
- [x] 3.4 Update `overmind/scripts/helper/check_implementation_plan_quality.sh` to fail when a required missing operator-facing surface disappears from `implementation_plan.md` or is represented only by API, auth, contract, state, or coordination work.

## 4. Add Targeted Regression Coverage

- [x] 4.1 Keep regression coverage limited to small fixture-based cases in the existing helper and generator suites; do not introduce a new end-to-end pipeline regression suite for this change.
- [x] 4.2 Update `tests/ai_scripts/check_implementation_slices_quality_tests.sh` with passing and failing cases for missing login surface, missing protected shell, missing admin entry route, and missing operator-facing lookup page, plus equivalent-surface wording cases that prove the gate is not a hardcoded route-name matcher.
- [x] 4.3 Update `tests/ai_scripts/check_implementation_plan_quality_tests.sh` with the same preserved-surface coverage cases plus failures for supporting-only plan steps that do not deliver the required surface, and equivalent-surface wording cases that prove the gate is not tied to one exact route literal or framework label.
- [x] 4.4 Update `tests/ai_scripts/init_feature_implementation_slices_tests.sh` so generated `implementation_slices.md` output preserves required operator-facing surfaces explicitly, accepts equivalent operator-surface wording, and does not fabricate user-facing slices when no such surface is required.
- [x] 4.5 Update `tests/ai_scripts/init_feature_implementation_plan_tests.sh` so generated `implementation_plan.md` output preserves required operator-facing surfaces explicitly, accepts equivalent operator-surface wording, and still allows supporting work around them.

## 5. Validate change readiness

- [x] 5.1 Run `bash tests/ai_scripts/check_prerequisite_gaps_quality_tests.sh` from the repository root.
- [x] 5.2 Run `bash tests/ai_scripts/check_implementation_slices_quality_tests.sh` from the repository root.
- [x] 5.3 Run `bash tests/ai_scripts/check_implementation_plan_quality_tests.sh` from the repository root.
- [x] 5.4 Run `bash tests/ai_scripts/init_feature_implementation_slices_tests.sh` from the repository root.
- [x] 5.5 Run `bash tests/ai_scripts/init_feature_implementation_plan_tests.sh` from the repository root.
- [x] 5.6 Run `openspec status --change crp-112-operator-facing-surface-preservation-through-slices-and-plan` and confirm the change is apply-ready.
