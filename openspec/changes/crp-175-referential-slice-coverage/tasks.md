> **Dependencies:** CRP-171. This change edits the coverage loop and the `slice-ref-surface-coverage` delta that CRP-171 introduces, so it applies and archives after it.

## 1. Make coverage referential

- [x] 1.1 Remove the supporting-only branch from the required-surface loop in `packages/asdlc-coordinator/src/validate/implementation-slices.ts`, leaving the unusable-reference, unresolved-link, and duplicate-number failures as the only coverage failures
- [x] 1.2 Remove `looksSupportingOnly(...)` and whatever the module no longer uses once the branch is gone

## 2. Keep the plan gate usable for endpoint surfaces

- [x] 2.1 Teach the private `looksSupportingOnly(...)` in `packages/asdlc-coordinator/src/validate/implementation-plan.ts` to read an HTTP method followed by a path as surface wording, keeping the per-step preserved-surface rule otherwise unchanged

## 3. Align the skills

- [x] 3.1 In `packages/installer/_data/skills/overmind-implementation-slices/SKILL.md`, keep naming the delivered surface as quality guidance and stop presenting it as a gate condition
- [x] 3.2 In `packages/installer/_data/skills/overmind-prerequisite-gaps/SKILL.md`, state that `evidence` carries the justification that the linked slice delivers the surface

## 4. Tests

- [x] 4.1 Replace the supporting-only link test in `packages/asdlc-coordinator/test/implementation-slices-validator.test.ts` with one proving a slice worded as supporting work covers a surface whose link resolves
- [x] 4.2 Add a validator test built from the measured artifact: a slice whose first increment names `POST /api/v1/telegram-identities`, linked as `slice-2`, passes
- [x] 4.3 Confirm the unusable-reference, unresolved-link, and duplicate-number tests still hold as the only coverage failures
- [x] 4.4 Add a test in `packages/asdlc-coordinator/test/implementation-plan-validator.test.ts` for a step whose preserved surface is named as an HTTP method and path

## 5. Verification

- [x] 5.1 Run the `implementation-slices` and `implementation-plan` gates against the measured feature at `/Users/aleksandrkalinin/repo/experiment_sdd_user_management_service/asdlc02/projects/umms03-e7cafd12-d837-452c-b8cb-406712651ea8/umss_core_functionality_v5-1784707983` and confirm both pass
- [x] 5.2 Run `npm test`, `npm run verify`, `npm run test --workspace overmind-installer`, and `npm run test --workspace asdlc-coordinator`
