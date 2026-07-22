## 1. Slices Rule

- [x] 1.1 Update `overmind/rules/implementation_slices_rule.md` to allow optional `kind: coordination` slices with emission criteria (real ambiguity, shared-artifact need, drift risk, direct signal evidence)
- [x] 1.2 Add rule text clarifying that coordination slices must carry a `signal_ref` field and that absence of any coordination slice is always a valid outcome
- [x] 1.3 Add rule text that coordination slices are kept separate from feature-delivery slices in intent and must not replace required operator-facing surface delivery
- [x] 1.4 Add rule text listing insufficient-on-their-own triggers: multi-repo scope, `delta_needed: true`, `comp/*` evidence overlap, or signal presence alone

## 2. Slices Template

- [x] 2.1 Update `overmind/templates/implementation_slices_TEMPLATE.md` to document optional `kind` and `signal_ref` fields on slice blocks with inline comments explaining when to use them
- [x] 2.2 Add a golden example section showing a coordination slice with `kind: coordination` and a valid `signal_ref`
- [x] 2.3 Add a golden example section showing a feature with no coordination slice and confirming both paths are valid

## 3. Plan Rule

- [x] 3.1 Update `overmind/rules/implementation_plan_rule.md` to allow optional `#### Coordination: true` marker on plan steps derived from coordination slices
- [x] 3.2 Add rule text that a coordination slice is only lifted into a plan step when downstream work is actually blocked by the unresolved artifact
- [x] 3.3 Add rule text that a coordination step must not be the sole coverage for a required operator-facing surface and must not blanket-block all consumer-repo steps
- [x] 3.4 Add rule text that `#### Depends on:` edges to a coordination step must be per-step justified and must not be applied blanket to every consumer-repo step

## 4. Slices Quality Helper

- [x] 4.1 Update `overmind/scripts/helper/check_implementation_slices_quality.sh` to validate `signal_ref` is non-empty when `kind: coordination` is present on a slice
- [x] 4.2 Confirm the helper does not fail when no coordination slice is present (absence is valid)
- [x] 4.3 Confirm the helper does not apply coordination validation to slices that lack a `kind` field

## 5. Plan Quality Helper

- [x] 5.1 Update `overmind/scripts/helper/check_implementation_plan_quality.sh` to parse `#### Coordination: true` markers on plan steps
- [x] 5.2 Add a check that a step marked `#### Coordination: true` is not the sole coverage for any required operator-facing surface from `prerequisite_gaps.md`
- [x] 5.3 Confirm the helper does not fail when no coordination step is present

## 6. Slices Quality Tests

- [x] 6.1 Add a test fixture and case to `tests/ai_scripts/check_implementation_slices_quality_tests.sh` for a valid slices artifact with a coordination slice (passes)
- [x] 6.2 Add a test case for a coordination slice with missing `signal_ref` (fails with clear message)
- [x] 6.3 Add a test case for a valid slices artifact with no coordination slice (passes)

## 7. Plan Quality Tests

- [x] 7.1 Add a test fixture and case to `tests/ai_scripts/check_implementation_plan_quality_tests.sh` for a valid plan with a coordination step beside a preserved surface step (passes)
- [x] 7.2 Add a test case for a plan where a coordination step is the sole coverage for a required surface (fails)
- [x] 7.3 Add a test case for a valid plan with no coordination step (passes)
