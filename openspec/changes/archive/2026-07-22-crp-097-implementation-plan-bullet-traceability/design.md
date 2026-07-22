## Context

`implementation_plan.md` already uses step headings such as `### Step 1.2 ... [REQ-6]`, and the current helper already validates that those requirement ids exist in `requirements_ears.md`. What it does not validate is full functional coverage: a requirement can still appear in `requirements_ears.md` without any implementation step being allocated to it.

The user clarified that bullet-level traceability is not the target contract. The required contract is simpler and better aligned with the current artifact shape:

- keep requirement links on step headings,
- use those links as the canonical traceability surface,
- guarantee every step is backed by at least one functional requirement, and
- guarantee every functional requirement is represented by at least one step.

Within this repository, the authoritative functional-requirement artifact for implementation planning is `requirements_ears.md`. Its stable ids are `REQ-*` / `NFR-*`, so step-level FR links should reuse those ids rather than introduce a second `FR-*` namespace just for the implementation plan.

This remains a cross-cutting change because the step-heading contract has to stay aligned across the implementation-plan rule, template, golden example, generation entrypoint, and quality helper.

## Goals / Non-Goals

**Goals:**
- Formalize one canonical step-level FR traceability contract for shared implementation plans.
- Require every implementation step heading to carry one-or-more functional-requirement links sourced from `requirements_ears.md`.
- Add deterministic reverse coverage checking so every functional requirement is represented by at least one implementation step.
- Keep the syntax aligned with the repository’s existing heading format so the change stays shell-parseable and low churn.

**Non-Goals:**
- Do not add bullet-level traceability markers.
- Do not add semantic quality judgments about whether a step is too large or should be split differently.
- Do not redesign repo ownership lines, dependency metadata, or the surrounding step-block structure.
- Do not introduce a second requirement-id namespace just for implementation plans.

## Decisions

1. Keep FR links on step headings and reuse the existing `REQ-*` / `NFR-*` ids
Rationale: the repository already has an established step-heading format and `requirements_ears.md` is already the authoritative requirement source for implementation planning. Reusing the existing ids keeps the change minimal and avoids inventing a parallel traceability namespace.
Alternative considered: introduce new `FR-*` identifiers or a dedicated link syntax for implementation plans. Rejected because it would duplicate the requirement ledger and force extra mapping logic without improving coverage validation.

2. Make step headings the canonical FR/implementation traceability surface
Rationale: the user’s desired questions are step-to-requirement and requirement-to-step coverage, both of which live naturally at step granularity. Checklist bullets remain execution detail inside the step and do not need to carry their own requirement metadata for this contract.
Alternative considered: make bullet-level markers canonical. Rejected because it is unnecessary for the required two-way FR coverage gate and adds noise to the plan.

3. Add explicit reverse coverage validation for requirements with no related step
Rationale: the current helper already proves that referenced ids are valid; the missing contract is the reverse direction. The helper should collect all valid `REQ-*` / `NFR-*` ids from `requirements_ears.md`, collect all ids used by step headings, and fail deterministically when any requirement id is left uncovered.
Alternative considered: rely on human review to spot uncovered requirements. Rejected because this is exactly the kind of deterministic completeness check the helper should own.

4. Keep many-to-many step coverage legal
Rationale: one implementation step can legitimately cover multiple functional requirements, and one functional requirement can require multiple steps across repos. The gate should enforce at-least-one coverage in both directions, not a one-to-one mapping.
Alternative considered: require exactly one requirement per step. Rejected because cross-cutting slices and prerequisite steps would be forced into artificial fragmentation.

## Risks / Trade-offs

- [Risk] The user’s “FR” wording could be misread as requiring a new `FR-*` syntax in implementation plans.
  Mitigation: make the artifacts explicit that, for this stage, functional-requirement links are the existing `REQ-*` / `NFR-*` ids from `requirements_ears.md`.

- [Risk] Full requirement coverage can force steps for requirements whose technical work is already effectively done.
  Mitigation: keep the gate scoped to the current `requirements_ears.md` input and allow implemented or prerequisite steps to satisfy coverage when they truthfully represent the delivered slice.

- [Risk] Existing plans may already pass structure checks while still leaving one or more requirements uncovered.
  Mitigation: update generator, template, golden example, and helper in one change so new and regenerated plans converge on the same explicit coverage rule.

- [Risk] Teams may treat the step-heading links as cosmetic labels rather than enforced coverage metadata.
  Mitigation: make the quality helper fail deterministically for uncovered requirements and for steps missing heading-level requirement links.

## Migration Plan

1. Update the implementation-plan artifact contract:
   - `overmind/rules/implementation_plan_rule.md`
   - `overmind/templates/implementation_plan_TEMPLATE.md`
   - `overmind/golden_examples/implementation_plan_GOLDEN_EXAMPLE.md`
2. Teach `overmind/scripts/feature_implementation_plan.sh` to generate plans whose step headings carry the required `REQ-*` / `NFR-*` coverage links.
3. Update `overmind/scripts/helper/check_implementation_plan_quality.sh` to:
   - require at least one valid `REQ-*` / `NFR-*` id on every step heading,
   - collect requirement coverage across all steps,
   - fail when any requirement from `requirements_ears.md` has no related step.
4. Add and update tests under `tests/ai_scripts/` for valid step-level coverage, missing heading links, and uncovered requirements.

Rollback strategy: remove the reverse coverage requirement from the helper and treat step-heading requirement ids as informative labels only again.

## Open Questions

- None. The main unresolved choice was whether to push traceability down to bullets or keep it at step level, and this change resolves that in favor of step-level FR coverage only.
