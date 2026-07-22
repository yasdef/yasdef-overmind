## Context

CRP-171 made `slice_ref` the coverage signal for a required missing operator-facing surface, and paired it with a second condition: the linked slice must not read as supporting-only scaffolding. That second condition reuses `looksSupportingOnly(...)`, a word-list heuristic that answers two questions about the linked slice's heading, objective, first increment, and checklist bullets — does the text contain support vocabulary, and does it contain surface vocabulary — and calls the slice scaffolding when the first holds and the second does not.

The support list is `auth|token|api|contract|schema|state|coordination|middleware|service|repository|adapter|dto|mapper|payload`. A backend slice describes controllers, services, repositories, and DTOs because that is what backend slices are; the support condition is therefore satisfied by construction. Coverage then turns entirely on whether the prose happens to contain one of the accepted surface words.

A measured run supplied the counterexample. `prerequisite_gaps.md` recorded `surface_identity: POST /api/v1/telegram-identities` with `slice_ref: slice-2` and an `evidence` paragraph justifying the link. `implementation_slices.md` declared Slice 2 with `first_increment: `POST /api/v1/telegram-identities` accepts valid new users, persists USER identities, and reuses existing identities without profile overwrite`. The gate resolved the link correctly and then rejected the slice, because naming a surface as an HTTP method and path is not in the accepted vocabulary while `dto`, `api`, and `service` are all in the support vocabulary. Repair was reported against step `8.1`, so the operator was returned to rewrite slices that were already right.

Before CRP-171 the same heuristic ran in a narrower position. It judged only slices that had declared `preserved_operator_surface`, and that declaration had first passed `hasSurfaceTerms(...)`, which canonicalized an HTTP method and path into the token `endpoint`. Moving the judgement onto raw slice prose removed that canonicalization from the path.

## Goals / Non-Goals

**Goals:**

- Decide surface coverage from conditions an artifact can satisfy deterministically, so a correct plan cannot fail on word choice.
- Keep the delivery claim reviewable by leaving it in the fields that already record it.
- Leave the gate with no rule that infers meaning from free prose.
- Keep the `implementation-plan` gate's per-step preserved-surface rule usable for surfaces named as an HTTP method and path.

**Non-Goals:**

- Reordering, merging, or splitting steps `8.1`, `8.2`, and `8.3`.
- Changing how `slice_ref` is parsed, resolved, or reported, including the duplicate-number and unresolved-link failures CRP-171 defines.
- Changing the `prerequisite-gaps` gate's own rules, the terminal gate chain, repair-step ownership, or the CLI surface.
- Retiring the `implementation-plan` gate's per-step preserved-surface rule, which CRP-171 decision `D6` keeps.

## Decisions

### D1: Coverage is referential

A required missing operator-facing surface is covered when its `slice_ref` is present, has the form `slice-<N>`, and resolves to exactly one slice declared in `implementation_slices.md`. Every failure the gate reports about coverage is then a statement about the link itself: it is missing, malformed, names no declared slice, or names a duplicated number.

Each of those is objectively checkable and objectively repairable. The operator reads the failure and knows what to change, rather than guessing which words will satisfy a vocabulary.

Alternative considered: extend the accepted surface vocabulary with the HTTP method and path form. Rejected as the primary fix because it closes one hole in a list that must anticipate every way a domain names a surface — GraphQL mutations, gRPC methods, message topics, deep links — and each miss is another false block on a correct plan.

### D2: The delivery claim stays where it is written

Retiring the judgement removes no recorded fact. Three carriers remain, and all three predate this change:

- `prerequisite_gaps.md` requires `evidence` on every scheduled entry, and the `prerequisite-gaps` gate fails without it. In the measured run that field held a full justification of why Slice 2 delivers the endpoint.
- `implementation_plan.md` must carry a step whose evidence includes `slice/<ref>`, which the `implementation-plan` gate enforces. That is structural proof the ordered plan schedules the linked slice.
- Plan semantic review and the operator's own plan checkpoint read the feature as a whole.

What is lost is the automated catch for a link that resolves to a slice genuinely doing only scaffolding. Step `8.2` writes that link with both artifacts in front of it and must justify it in `evidence`; the judgement moves from the least informed reader in the chain to the best informed one, and to review.

### D3: The rule that existed to satisfy the judgement stops being a gate condition

The `overmind-implementation-slices` skill instructs the model to word a surface-delivering slice so its heading, objective, first increment, and bullets name the delivered page, route, command, job, or endpoint. That instruction stays as quality guidance, because a slice that names what it delivers is a better slice. It stops being described as something the gate checks, because the gate no longer checks it.

The skill keeps its rule that every required missing operator-facing surface gets an explicit feature-delivery slice. That rule is about which slices exist, which the model can satisfy from technical requirements and surface maps.

### D4: The plan gate learns the HTTP method and path form

CRP-171 decision `D6` keeps the `implementation-plan` gate's per-step `#### Preserved Surface` rule, on the grounds that the plan's declaration is answerable when it is asked. That rule uses a private copy of the same heuristic and carries the same blind spot, so a plan step declaring `POST /api/v1/telegram-identities` can be rejected the way the slice was.

The plan gate keeps the rule and gains recognition of an HTTP method followed by a path as surface wording. The narrower fix is right here and wrong for the slices gate, because the plan judges a value the step declares about itself, against prose the same step wrote, on a first pass — a claim, not a third artifact's link.

Alternative considered: retire the plan's rule for symmetry. Rejected for the reason `D6` gives, which this change does not disturb.

## Risks / Trade-offs

- [A `slice_ref` can resolve to a slice that builds only scaffolding, and no gate reports it] → The link is written by step `8.2` reading both artifacts, must carry `evidence` justifying it, and must be scheduled by a plan step carrying `slice/<ref>`; semantic review and the plan checkpoint read the result. The retired check had, on the evidence available, blocked one correct plan and caught no incorrect one.
- [Removing a gate condition can look like weakening the surface-delivery guarantee] → The guarantee that a required missing surface has a delivering slice is unchanged: `prerequisite-gaps` still fails an `unmet` entry, and `implementation-slices` still fails a link that resolves to nothing. Only the judgement of a resolved slice's wording is retired.
- [The plan gate keeps a vocabulary-based rule and can still misfire on an unanticipated surface form] → It judges a value the step declares about itself and repairs within the same step, so a miss costs a wording edit rather than a return to an earlier step. `D4` closes the form that has actually been observed.
