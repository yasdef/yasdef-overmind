## Context

`crp-097` establishes step headings as the canonical functional-requirement traceability surface for `implementation_plan.md`. That solves requirement-to-step coverage, but it still leaves a second completeness problem unresolved: the plan can omit concrete unresolved technical work from `technical_requirements.md`, and the quality helper still has no deterministic way to reject a step that is behavior-linked yet unsupported by current-state repo evidence.

The next gate therefore needs to stay at the same planning unit as `crp-097`: implementation steps, not checklist bullets. A step already owns repo allocation, dependency ordering, and behavioral scope through its heading refs. This change extends that step contract so helpers can also reason about unresolved technical evidence and verify that all remaining feature work is represented somewhere in the plan.

This is cross-cutting because it affects the implementation-plan rule, template, golden example, generator entrypoint, and quality helper together. The coverage and justification rules also need to compose cleanly with the `crp-097` step-level FR traceability contract instead of redefining it.

## Goals / Non-Goals

**Goals:**
- Keep unresolved-work coverage and justification at implementation-step scope.
- Require each implementation step to carry both functional-requirement links and step-scoped technical-evidence links.
- Derive a deterministic mandatory-coverage set from unresolved requirement-gap and impacted-component entries in `technical_requirements.md`.
- Fail the helper when unresolved technical work is not represented by any plan step.
- Fail the helper when a plan step lacks either valid requirement links or valid technical-evidence links.

**Non-Goals:**
- Do not add bullet-level traceability markers.
- Do not redesign checklist bullets or make bullets the unit of helper coverage.
- Do not introduce a non-shell parser or a sidecar traceability file.
- Do not force already completed technical-requirements items into the mandatory coverage set when they have no remaining gap.

## Decisions

1. Keep implementation steps as the atomic unit for coverage and justification
Rationale: step scope already matches repo ownership, dependency management, and the FR-link contract introduced by `crp-097`. The helper should reason over the same atomic unit instead of introducing a second traceability level on bullets.
Alternative considered: attach unresolved-work and justification refs to checklist bullets. Rejected because the user explicitly wants links only on plan steps, and bullet-level structure adds noise without improving the intended gate.

2. Add a step-scoped `#### Evidence:` metadata line for technical-requirements links
Rationale: `crp-097` keeps FR links in the step heading, but unresolved-work coverage against `technical_requirements.md` still needs a deterministic technical reference surface. A step metadata line fits the existing plan structure alongside `#### Repo:` and `#### Depends on:` while staying at step scope.
Alternative considered: infer technical justification indirectly from bullet wording or step titles. Rejected because it is too ambiguous for a shell helper to enforce deterministically.

3. Reuse typed evidence tokens derived from `technical_requirements.md`
Rationale: the helper needs stable tokens that can point to both unresolved requirement-gap blocks and impacted-component blocks. The compact token forms below are deterministic and shell-parseable:
- `gap/TECH_REQ-<n>` for unresolved `### Requirement: REQ-<n>` entries in `technical_requirements.md`
- `comp/<component-slug>` for unresolved `### Component:` entries in `technical_requirements.md`
Alternative considered: free-text component names or prose references. Rejected because the helper would be forced into fuzzy matching and error output would be less actionable.

4. Build the mandatory coverage set from unresolved technical-requirements items only
Rationale: the helper should enforce coverage where feature work still remains, not where the repo evidence already says the slice is complete. Requirement-gap blocks with `gap_status: fully_implemented` or component blocks with `gap_to_close: no remaining gap` should remain outside the mandatory set unless a step deliberately includes them as prerequisite context.
Alternative considered: require every requirement and every component from `technical_requirements.md` to appear in step evidence refs. Rejected because it would over-constrain plans with already-complete evidence and encourage noisy placeholder steps.

5. Require both behavioral and technical evidence for step justification
Rationale: a plan step is justified only when it has both:
- valid FR links on the step heading from `requirements_ears.md`, and
- valid `#### Evidence:` tokens that point to unresolved technical evidence in `technical_requirements.md`.
This preserves the behavioral contract from `crp-097` while adding the missing current-state proof.
Alternative considered: let technical evidence alone justify a step. Rejected because steps still need to stay anchored to intended behavior, not just repo internals.

## Risks / Trade-offs

- [Risk] Adding `#### Evidence:` increases step metadata and makes headings slightly heavier.
  Mitigation: keep the line compact, tokenized, and adjacent to existing per-step metadata instead of spreading refs across bullets.

- [Risk] Component slugs can drift if `technical_requirements.md` component headings are renamed casually.
  Mitigation: define `comp/<component-slug>` as the slugified form of the exact `### Component:` heading and make helper failures report the missing token directly.

- [Risk] Some valid prerequisite steps may reference already completed technical slices.
  Mitigation: keep completed items outside the mandatory coverage set but still allow them in `#### Evidence:` when they truthfully explain prerequisite-state context.

- [Risk] Plans generated before this change may satisfy FR coverage while still lacking technical-evidence refs.
  Mitigation: update generator, template, golden example, and helper together so regenerated plans converge immediately on the full step-level contract.

## Migration Plan

1. Update the implementation-plan artifact contract:
   - `overmind/rules/implementation_plan_rule.md`
   - `overmind/templates/implementation_plan_TEMPLATE.md`
   - `overmind/golden_examples/implementation_plan_GOLDEN_EXAMPLE.md`
2. Teach `overmind/scripts/feature_implementation_plan.sh` to generate:
   - step-heading FR links using `REQ-*` / `NFR-*`, and
   - `#### Evidence:` lines with `gap/TECH_REQ-<n>` and `comp/<component-slug>` tokens.
3. Update `overmind/scripts/helper/check_implementation_plan_quality.sh` to:
   - validate `#### Evidence:` presence and token shapes,
   - derive unresolved requirement/component coverage sets from `technical_requirements.md`,
   - fail on uncovered unresolved work,
   - fail on steps missing either behavioral or technical justification.
4. Add and update tests under `tests/ai_scripts/` for valid step evidence, missing evidence lines, uncovered unresolved work, and unsupported steps.

Rollback strategy: remove the step-level technical-evidence requirement and unresolved-work coverage gate together, leaving only the `crp-097` FR coverage rules in place.

## Open Questions

- None. The key design choice was whether to push this gate to bullet level or keep it at step level, and this change resolves that in favor of step-level only.
