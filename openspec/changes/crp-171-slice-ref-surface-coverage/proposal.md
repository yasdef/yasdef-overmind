## Why

Step `8.2` records which slice delivers each required missing operator-facing surface, as a `slice_ref` on the prerequisite entry. The step `8.1` `implementation-slices` gate asks the same question and refuses to read that answer: it takes `surface_identity` from the prerequisite entry, drops `slice_ref` from the same block, and instead text-matches the surface name against each slice's `preserved_operator_surface` field. A feature whose two artifacts agree therefore fails, because the agreement is recorded in the field the gate ignores.

The mismatch is guaranteed on a first pass. `prerequisite_gaps.md` is written by step `8.2`, one step after the slices, so when the step `8.1` gate runs there is no required-surface list at all and the rule passes without checking anything. The slices are written with `preserved_operator_surface: none`, because at that moment there is no surface list to name. Step `8.2` then produces the correct `slice_ref` links, and the CRP-166 terminal gate chain re-runs the step `8.1` gate against the finished feature, where the rule finally has input and reports every surface as undelivered. The operator is sent back to step `8.1` to re-run four steps and hand-copy surface names the system already resolved.

## What Changes

- Treat `slice_ref` on a prerequisite entry as the authoritative signal that a required missing operator-facing surface is delivered, resolving it against the slice numbers present in `implementation_slices.md`.
- Reject a `slice_ref` that names no existing slice, and a `slice_ref` that names a slice describing supporting-only scaffolding, so the link carries the delivery guarantee the text match used to carry.
- **BREAKING** Retire `preserved_operator_surface` as the coverage signal: the `implementation-slices` gate stops reading it, and the field leaves the `implementation_slices.md` template, its packaged skill, and its golden example.
- Keep the surface-coverage rule owned by the `implementation-slices` gate and its repair by step `8.1`.

## Capabilities

### New Capabilities

- `slice-ref-surface-coverage`: the authoritative slice link for required missing operator-facing surfaces, its resolution against declared slices, and the retirement of the duplicate coverage field.

### Modified Capabilities

- None. `openspec/specs/` holds no synced capability whose requirements this change alters.

## Impact

- `packages/asdlc-coordinator/src/validate/implementation-slices.ts`: carry `slice_ref` out of `extractRequiredMissingSurfaces(...)`, resolve it against the parsed slice numbers, and drop the `preserved_operator_surface` coverage path.
- `packages/asdlc-coordinator/test/implementation-slices-validator.test.ts`: cover a resolved link, an unresolvable link, a link to a supporting-only slice, and a feature holding no required missing surfaces.
- `packages/asdlc-coordinator/test/prerequisite-gaps-validator.test.ts`: imports `extractRequiredMissingSurfaces(...)`, so its call site follows the widened return shape.
- `packages/installer/_data/skills/overmind-implementation-slices/SKILL.md` and its `implementation_slices.md` template and golden example: remove the `preserved_operator_surface` field and the instruction to fill it.
- `overmind/templates/`: the `implementation_slices.md` template loses the same field.
- Features planned before this change keep a `preserved_operator_surface` line that no gate reads; they are not rewritten.
- `implementation_plan.md` keeps its per-step `#### Preserved Surface` and the `implementation-plan` gate keeps its matching coverage rule: step `8.3` runs after `prerequisite_gaps.md` exists, so that declaration is answerable when it is asked.
- No change to step ordering, the catalog, the terminal gate chain, the `prerequisite-gaps` gate, or the CLI surface.
