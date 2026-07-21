## MODIFIED Requirements

### Requirement: A required missing operator-facing surface is delivered by its linked slice

The `implementation-slices` gate SHALL decide coverage of a required missing operator-facing surface from the `slice_ref` recorded on that surface's prerequisite entry in `prerequisite_gaps.md`, resolved against the slices declared in `implementation_slices.md`. The gate SHALL reach that decision from the resolved link alone.

#### Scenario: Every required surface is linked to a declared slice

- **WHEN** each prerequisite entry with `surface_kind: required_missing_user_reachable_surface` and a slice-scheduled status carries a `slice_ref` naming a slice declared in `implementation_slices.md`
- **THEN** the gate reports the surfaces as covered
- **AND** the gate reaches no conclusion from how any slice is worded

#### Scenario: A link names no declared slice

- **WHEN** a required missing operator-facing surface carries a `slice_ref` that names no slice declared in `implementation_slices.md`
- **THEN** the gate fails, naming the surface and the unresolved reference

#### Scenario: A linked slice is worded as supporting work

- **WHEN** a required missing operator-facing surface carries a `slice_ref` naming a declared slice whose heading, objective, first increment, and checklist bullets describe controllers, services, repositories, adapters, or other supporting structures
- **THEN** the gate reports the surface as covered

#### Scenario: A linked slice names its surface as an HTTP method and path

- **WHEN** a required missing operator-facing surface carries a `slice_ref` naming a declared slice that identifies the delivered surface as an HTTP method followed by a path
- **THEN** the gate reports the surface as covered

#### Scenario: The feature declares no required missing surfaces

- **WHEN** `prerequisite_gaps.md` records no prerequisite entry with `surface_kind: required_missing_user_reachable_surface` in a slice-scheduled status
- **THEN** the gate reports no surface-coverage failure

## ADDED Requirements

### Requirement: An HTTP method and path names an operator-facing surface

The `implementation-plan` gate SHALL treat an HTTP method followed by a path as operator-facing surface wording when it judges whether a plan step declaring `#### Preserved Surface` describes supporting-only work.

#### Scenario: A plan step delivers an endpoint named as a method and path

- **WHEN** a plan step declares a preserved surface and its heading and checklist bullets identify the delivered surface as an HTTP method followed by a path
- **THEN** the gate reports no supporting-only failure for that step

## REMOVED Requirements

### Requirement: A link names a supporting-only slice

**Reason**: The judgement read free slice prose through a fixed vocabulary. Its supporting vocabulary — `api`, `service`, `dto`, `repository`, `schema`, `state`, `mapper`, `payload` — is the vocabulary every backend slice is written in, so coverage turned on whether the prose also happened to contain one of the accepted surface words. A measured run rejected a slice delivering `POST /api/v1/telegram-identities` because it named its surface as an HTTP method and path, returning the operator to step `8.1` to rewrite correct slices.

**Migration**: Coverage resolves from the link alone. The delivery claim stays in the `evidence` field the `prerequisite-gaps` gate requires on every scheduled entry, in the `slice/<ref>` plan-step evidence token the `implementation-plan` gate requires, and in semantic review. Artifacts already planned need no rewrite; the gate reaches fewer conclusions from them.
