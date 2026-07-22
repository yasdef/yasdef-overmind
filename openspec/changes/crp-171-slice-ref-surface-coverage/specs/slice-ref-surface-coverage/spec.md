## ADDED Requirements

### Requirement: A required missing operator-facing surface is delivered by its linked slice

The `implementation-slices` gate SHALL decide coverage of a required missing operator-facing surface from the `slice_ref` recorded on that surface's prerequisite entry in `prerequisite_gaps.md`, resolved against the slices declared in `implementation_slices.md`.

#### Scenario: Every required surface is linked to a declared slice

- **WHEN** each prerequisite entry with `surface_kind: required_missing_user_reachable_surface` and a slice-scheduled status carries a `slice_ref` naming a slice declared in `implementation_slices.md`
- **THEN** the gate reports the surfaces as covered
- **AND** the gate reaches no conclusion from any slice's restatement of the surface name

#### Scenario: A link names no declared slice

- **WHEN** a required missing operator-facing surface carries a `slice_ref` that names no slice declared in `implementation_slices.md`
- **THEN** the gate fails, naming the surface and the unresolved reference

#### Scenario: A link names a supporting-only slice

- **WHEN** a required missing operator-facing surface carries a `slice_ref` naming a declared slice whose heading, objective, first increment, and checklist bullets describe supporting-only scaffolding
- **THEN** the gate fails, naming the surface and the slice it points to

#### Scenario: The feature declares no required missing surfaces

- **WHEN** `prerequisite_gaps.md` records no prerequisite entry with `surface_kind: required_missing_user_reachable_surface` in a slice-scheduled status
- **THEN** the gate reports no surface-coverage failure

### Requirement: A link resolves against the slice's declared heading number

The gate SHALL resolve a `slice_ref` of the form `slice-<N>` against the number declared in a slice heading `### Slice <N>:`, independent of that slice's position in the document, and SHALL require each declared slice number to be unique.

#### Scenario: Slice headings are not in ascending order

- **WHEN** `slice_ref: slice-4` is recorded and `implementation_slices.md` declares `### Slice 4:` at any position
- **THEN** the link resolves to the slice whose heading declares `4`

#### Scenario: A reference does not name a slice number

- **WHEN** a `slice_ref` for a required missing operator-facing surface does not have the form `slice-<N>`
- **THEN** the gate fails, naming the surface and the unusable reference

#### Scenario: Two slices declare the same number

- **WHEN** `implementation_slices.md` declares more than one slice heading carrying the same `<N>`
- **THEN** the gate fails, naming the duplicated slice number
- **AND** the gate reaches no coverage conclusion for a `slice_ref` naming that number

### Requirement: Surface coverage is recorded once

`implementation_slices.md` SHALL carry no per-slice restatement of the operator-facing surface a slice delivers, and the `implementation-slices` gate SHALL derive no conclusion from such a value.

#### Scenario: A slice omits any surface restatement

- **WHEN** a slice that delivers a required missing operator-facing surface declares only its heading, ownership, evidence, objective, first increment, and checklist bullets
- **THEN** the gate reports no failure for the absent restatement, and the surface is covered through its `slice_ref`

#### Scenario: An artifact planned before this change is validated

- **WHEN** an existing `implementation_slices.md` still carries a per-slice surface restatement
- **THEN** the gate ignores the value and decides coverage from `slice_ref` alone

### Requirement: Coverage is judged only where both artifacts exist

The gate SHALL report no surface-coverage failure when `prerequisite_gaps.md` is absent.

#### Scenario: The slices gate runs before the gap trace

- **WHEN** the gate validates `implementation_slices.md` at step `8.1`, before `prerequisite_gaps.md` exists
- **THEN** no surface-coverage failure is reported
- **AND** the terminal gate chain reaches the same rule once both artifacts exist

## REMOVED Requirements

### Requirement: A slice declares the operator-facing surface it preserves

**Reason**: The declaration duplicated a fact `prerequisite_gaps.md` already records as `slice_ref`, and it could not be written on a first pass because the required-surface list does not exist when `implementation_slices.md` is written. Coverage now resolves from the link, and the delivery judgement it carried moves to the linked slice.

**Migration**: `preserved_operator_surface` is removed from the `implementation_slices.md` template, the `overmind-implementation-slices` skill, and its golden example. Artifacts planned before this change keep the line; no gate reads it and no rewrite is required.
