## Context

Two artifacts describe the same fact from opposite directions.

`implementation_slices.md` (step `8.1`) carries `preserved_operator_surface` on each slice: a free-text restatement of the operator-facing surface that slice delivers, or `none`.

`prerequisite_gaps.md` (step `8.2`) carries, for each required missing operator-facing surface, a `surface_identity` and the `slice_ref` of the slice that delivers it. Its own gate already enforces the link: `status: unmet` fails with "resolve by adding a slice to implementation_slices.md", and `status: scheduled_in_slices` fails without a `slice_ref`.

The `implementation-slices` gate proves surface coverage from the first artifact while reading the required-surface list out of the second. `extractRequiredMissingSurfaces(...)` parses each prerequisite block, keeps `surface_identity`, and discards `slice_ref`; coverage is then decided by `surfaceMatches(...)` against the collected `preserved_operator_surface` values. The recorded answer is thrown away one line before the question is asked.

Ordering makes the mismatch unavoidable. The gate reads `prerequisite_gaps.md` conditionally — absent means an empty required list and a rule that checks nothing — and at step `8.1` the file does not exist yet. Slices are therefore written with `preserved_operator_surface: none`, step `8.2` records correct `slice_ref` links, and the CRP-166 terminal gate chain re-runs the step `8.1` gate against the finished feature, where the rule finally has input and reports every surface as undelivered. A measured run produced exactly this: four surfaces linked to `slice-3`, `slice-4`, `slice-5` and `slice-7`, three reported as "not preserved by any slice", repair owner step `8.1`.

The dependency cannot be inverted. `prerequisite_gaps.md` is expressed in terms of slices, so step `8.2` cannot precede step `8.1`.

## Goals / Non-Goals

**Goals:**

- Decide surface coverage from the artifact that already resolved it, so two agreeing artifacts pass.
- Keep the delivery guarantee that the text match carried: a link must name a real slice that delivers the surface rather than supporting-only scaffolding.
- Leave one place where "this slice delivers that surface" is recorded.
- Keep the rule reachable only where it has input, so a first pass cannot fail late for want of a file that does not exist yet.

**Non-Goals:**

- Reordering, merging, or splitting steps `8.1` and `8.2`.
- Changing the `prerequisite-gaps` gate's own rules, the `implementation-plan` gate's per-step preserved-surface rule, the terminal gate chain, repair-step ownership, or the CLI surface.
- Rewriting `implementation_slices.md` artifacts planned before this change.
- Deriving the required-surface list inside step `8.1` so it can be checked there.

## Decisions

### D1: `slice_ref` is the coverage signal

A required missing operator-facing surface is delivered when its prerequisite entry names a slice that exists in `implementation_slices.md`. `extractRequiredMissingSurfaces(...)` returns the `slice_ref` alongside the `surface_identity`, and the gate resolves the link instead of text-matching surface names.

This inverts which artifact is trusted. Step `8.2` reads both files and decides the mapping with full information; step `8.1` writes its file before the required-surface list exists. Trusting the later, better-informed artifact is what makes a correct first pass possible.

Treating the link as authoritative is an existing pattern rather than a new one: the `implementation-plan` gate already resolves each scheduled prerequisite's `slice_ref` from `prerequisite_gaps.md` against plan-step evidence tokens, failing when no step carries `slice/<ref>`.

Alternative considered: keep the text match and additionally accept a resolved `slice_ref`. Rejected because it leaves both signals live, so the duplication and its drift remain.

### D2: A link must resolve and must not name scaffolding

Two failures replace the one being removed:

- A `slice_ref` that names no slice present in `implementation_slices.md` fails, owned by step `8.2`'s artifact but repaired through the slices the operator is already returning to.
- A `slice_ref` naming a slice whose heading, objective, first increment, and bullets read as supporting-only scaffolding fails, reusing the existing `looksSupportingOnly(...)` judgement now applied to the referenced slice.

Together these preserve the original intent — a required surface is delivered by a real feature-delivery slice — while sourcing the claim from the artifact that computed it.

### D3: Resolve against the slice's declared heading number

`slice_ref` is written as `slice-<N>` and the slice heading is `### Slice <N>:`, but the parser currently numbers slices by position (`slices.length + 1`) rather than by the digits in the heading. In a well-formed file the two agree; in a file whose headings skip or repeat a number they do not, and resolving by position would silently bind a link to the wrong slice.

Resolution therefore uses the number declared in the heading. The positional `number` stays as-is for every existing problem message, so no current gate output changes wording.

Alternative considered: resolve by position and require headings to be sequential. Rejected because it adds a new structural rule to fix a lookup that can simply read what it is given.

### D4: Retire `preserved_operator_surface`

The field leaves the `implementation_slices.md` template, the packaged `overmind-implementation-slices` skill, and the golden example, and the gate stops reading it. Its two supporting checks — that the value is operator-facing, and that the slice claiming it is not scaffolding-only — move to the resolved link under D2, so no judgement is lost.

The step `8.1` skill keeps its rule that every required missing operator-facing surface gets an explicit feature-delivery slice. That rule is about which slices exist, which the model can satisfy from technical requirements and surface maps; only the declaration field goes away.

Alternative considered: keep the field as an unread hint. Rejected because a field the gate ignores is a field that drifts, and the reason this change exists is one fact recorded in two places.

### D5: A first pass without the gap file checks nothing, and that is now correct

The gate keeps reading `prerequisite_gaps.md` conditionally, so at step `8.1` the required list is still empty and the rule still checks nothing. Under D1 that is no longer a deferred failure: coverage is established by step `8.2` writing the link, and the terminal gate chain validates it once both artifacts exist. The vacuous first pass becomes the honest statement that the question cannot be asked yet.

### D6: The plan's own preserved-surface declaration stays

`implementation_plan.md` carries a per-step `#### Preserved Surface`, and the `implementation-plan` gate runs the same coverage rule against it, failing with "required missing operator-facing surface is not preserved by any implementation plan step". That rule is left exactly as it is.

The measured run is the argument: the identical rule over the identical prerequisite entries **passed** at step `8.3` and failed at step `8.1`. Step `8.3` runs after step `8.2`, so `prerequisite_gaps.md` was on disk when the plan was written and its steps could name the surfaces they deliver on the first pass. The plan's declaration is answerable when it is asked; the slices' declaration is not. Only the unanswerable one is retired.

Alternative considered: retire the plan's declaration for symmetry. Rejected because it changes a working gate to match a broken one, and because the plan already resolves `slice_ref` for its evidence tokens, so the two signals there corroborate rather than duplicate.

### D7: The `slice-<N>` convention becomes explicit

The gate now depends on `slice_ref` being parseable, and the convention lives only in the `prerequisite_gaps.md` golden example. It is stated in the template and the `overmind-prerequisite-gaps` skill so the format the gate resolves is the format the artifact is told to produce.

## Risks / Trade-offs

- [Step `8.2` can link a surface to a slice that does not deliver it] → The link must resolve to an existing slice that does not read as supporting-only scaffolding, which is the same judgement the retired text match applied, and step `8.2` writes the link with both artifacts in front of it.
- [Features planned before this change keep a `preserved_operator_surface` line no gate reads] → The line is inert; the terminal chain judges those features by their `slice_ref` links, which the `prerequisite-gaps` gate has always required.
- [Surface coverage now depends on an artifact from a later step] → It already did: the required-surface list has always come from `prerequisite_gaps.md`, and only the answer was being sought elsewhere.
- [Removing a template field changes an artifact shape operators may have learned] → The field is removed from the template, skill, and golden example together, so the next planned feature is self-consistent.
