> **Dependencies:** none. CRP-166's terminal gate chain is what surfaces the defect; this change does not alter it.

## 1. Resolve coverage from the slice link

- [x] 1.1 Return `slice_ref` alongside `surface_identity` from `extractRequiredMissingSurfaces(...)` in `packages/asdlc-coordinator/src/validate/implementation-slices.ts`
- [x] 1.2 Capture each slice's declared heading number from `### Slice <N>:`, keeping the existing positional `number` for current problem messages
- [x] 1.3 Resolve a `slice_ref` of the form `slice-<N>` against the declared heading numbers, and fail with the surface and the unusable reference when it has another form
- [x] 1.4 Fail with the surface and the unresolved reference when the link names no declared slice
- [x] 1.5 Fail with the surface and the slice it points to when the linked slice reads as supporting-only through the existing `looksSupportingOnly(...)` judgement
- [x] 1.6 Report no surface-coverage failure when `prerequisite_gaps.md` is absent or declares no slice-scheduled required missing surface
- [x] 1.7 Fail with the duplicated number when two slices declare the same heading number, and reach no coverage conclusion for a link naming it

## 2. Retire the duplicate declaration

- [x] 2.1 Remove the `preserved_operator_surface` coverage path, its operator-facing check, and its supporting-only check from `packages/asdlc-coordinator/src/validate/implementation-slices.ts`, retaining `looksSupportingOnly(...)` for the linked-slice judgement and removing whatever the module no longer uses
- [x] 2.2 Remove `preserved_operator_surface` from `overmind/templates/implementation_slices_TEMPLATE.md` and `packages/installer/_data/skills/overmind-implementation-slices/assets/implementation_slices_TEMPLATE.md`
- [x] 2.3 Remove `preserved_operator_surface` from `overmind/golden_examples/implementation_slices_GOLDEN_EXAMPLE.md` and `packages/installer/_data/skills/overmind-implementation-slices/assets/implementation_slices_GOLDEN_EXAMPLE.md`
- [x] 2.4 Update `packages/installer/_data/skills/overmind-implementation-slices/SKILL.md` so the field is no longer produced, keeping its rule that every required missing operator-facing surface gets an explicit feature-delivery slice

## 3. State the reference convention

- [x] 3.1 State the `slice-<N>` form of `slice_ref` in `overmind/templates/prerequisite_gaps_TEMPLATE.md` and the packaged `overmind-prerequisite-gaps` template
- [x] 3.2 State the same convention in `packages/installer/_data/skills/overmind-prerequisite-gaps/SKILL.md`
- [x] 3.3 Leave the `prerequisite_gaps.md` template and golden example with a single copy under `packages/installer/_data/`, carrying the `## 2. Prerequisite Catalog` / `## 3. Requirement Coverage` structure the `prerequisite-gaps` gate enforces

## 4. Tests

- [x] 4.1 Add validator tests in `packages/asdlc-coordinator/test/implementation-slices-validator.test.ts` for a resolved link, an unresolved link, a non-`slice-<N>` reference, and a link to a supporting-only slice
- [x] 4.2 Add a validator test proving a slice carrying no surface restatement passes when its link resolves
- [x] 4.3 Add a validator test proving headings that are not in ascending order resolve by declared number rather than position
- [x] 4.8 Add a validator test proving duplicate declared slice numbers fail and resolve no coverage
- [x] 4.4 Add validator tests proving no surface-coverage failure when `prerequisite_gaps.md` is absent and when it declares no slice-scheduled required missing surface
- [x] 4.5 Update existing `preserved_operator_surface` assertions in `packages/asdlc-coordinator/test/implementation-slices-validator.test.ts` to the link contract
- [x] 4.6 Update the `extractRequiredMissingSurfaces(...)` call sites in `packages/asdlc-coordinator/test/implementation-slices-validator.test.ts` and `packages/asdlc-coordinator/test/prerequisite-gaps-validator.test.ts` to the widened return shape
- [x] 4.7 Add a regression test reproducing the measured failure: four required surfaces linked to `slice-3`, `slice-4`, `slice-5` and `slice-7` with no surface restatements, asserting the chain passes

## 5. Verification

- [x] 5.1 Confirm the installer's packaged assets stay in sync with `overmind/` for the touched templates and golden examples
- [x] 5.2 Run `npm test`, `npm run verify`, `npm run test --workspace overmind-installer`, and `npm run test --workspace asdlc-coordinator`
