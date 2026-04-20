## Context

`crp-108` split transport-layer presence from `user_reachable_surface`, and `crp-109` added prerequisite-gap tracing so the workflow can detect when an operator-facing prerequisite is missing before plan generation. That closes the "is the prerequisite missing?" question, but it does not guarantee that later planning phases keep scheduling the missing surface itself.

The remaining regression is that, once Step `8.1` and Step `8.3` start reshaping work, they can drift toward auth, API, state, contract, or coordination work and quietly drop the actual required login page, admin route, protected shell, or lookup screen. The change needs to preserve direct alignment to `requirements_ears.md` without expanding into adjacent problems like inbound navigation design or optional coordination planning.

## Goals / Non-Goals

**Goals:**
- Use upstream prerequisite evidence as the canonical source for which missing operator-facing surfaces must survive downstream planning.
- Keep prerequisite-gap validation aligned with that preservation source so downstream slices and plans consume a trustworthy set of required missing operator-facing surfaces.
- Require Step `8.1` to preserve each required missing operator-facing surface in at least one explicit feature-delivery slice.
- Require Step `8.3` to preserve the same surface in at least one explicit implementation-plan step until the surface is delivered.
- Add deterministic slice-level and plan-level quality checks that fail when the required surface disappears behind supporting work.
- Keep the preservation check evidence-driven rather than hardcoded to one route name or one UI framework.

**Non-Goals:**
- Do not fabricate user-facing work when `requirements_ears.md` does not require a user-facing surface.
- Do not add a new end-to-end pipeline regression suite for this change; targeted artifact-level regression coverage is sufficient for this scope.
- Do not solve inbound navigation-affordance or operator discovery in this change; that remains distinct from preserving the required surface itself.
- Do not redefine the transport-layer vs `user_reachable_surface` split from `crp-108`.
- Do not turn optional coordination work into a mandatory blocker regime; that is separate coordination-planning work.

## Decisions

1. Use `prerequisite_gaps.md` as the preservation source of truth
Rationale: This change starts after prerequisite tracing. The workflow already has one artifact that interprets `requirements_ears.md` into named missing user-reachable prerequisites. Re-deriving the preservation set independently in Step `8.1`, Step `8.3`, and both helpers would create drift. The minimal coherent design is to make `prerequisite_gaps.md` keep required missing operator-facing surfaces explicitly identifiable and let later phases consume that normalized evidence.
Alternative considered: derive preserved surfaces directly from `technical_requirements.md` or `requirements_ears.md` inside each downstream step. Rejected because it duplicates interpretation logic and makes later helper behavior harder to keep aligned.

2. Treat preserved-surface coverage as explicit delivery work, not as token resolution
Rationale: the failure mode is not absence of related work; it is absence of the surface itself. A missing login page is not satisfied by auth middleware, token wiring, or a contract update. The rule therefore has to ask whether slices and plan steps explicitly deliver the operator-facing surface, while still allowing surrounding supporting work to exist.
Alternative considered: count any related auth/API/state/contract work as indirect surface coverage. Rejected because that is exactly how the current drift hides the required operator outcome.

3. Keep matching evidence-driven and semantic, not route-list-driven
Rationale: the same required surface may appear as a route, page, shell, screen, or equivalent entry surface depending on project class and framework. Hardcoding route names or framework-specific labels would be brittle and would miss legitimate equivalents. The preservation logic should instead match on the named operator-facing surface meaning established upstream, using literal paths when present but not requiring them in every case.
Alternative considered: gate only on literal route/path string reuse across artifacts. Rejected because it would fail valid plans that use equivalent wording and would be too narrow for non-web repos.

4. Separate preserved-surface delivery from inbound reachability
Rationale: This change is about not losing a required surface after prerequisite tracing. It does not answer how operators discover or navigate to that surface once delivered. That downstream product-fit question already belongs to the semantic-review concern from `crp-110`. Keeping the boundary explicit avoids overloading this change and prevents the preservation gate from inventing extra navigation work.
Alternative considered: require every preserved surface to also have explicit inbound navigation work. Rejected because it conflates two related but distinct checks and would overspecify planning behavior.

## Risks / Trade-offs

- [Risk] The preservation set could overreach and force user-facing work for gaps that are actually transport-only or internal.
  Mitigation: source the set from required missing `user_reachable_surface` prerequisites only, and keep internal execution gaps explicitly out of that set.

- [Risk] Helpers may under-detect valid coverage if slice or step wording is too vague.
  Mitigation: require slices and plan steps to state the delivered operator-facing surface explicitly enough to map back to the upstream named surface.

- [Risk] Semantic matching can regress into brittle string matching over time.
  Mitigation: keep the rule and tests focused on upstream surface meaning, with literal paths as evidence when available but not as the only acceptable representation.

- [Risk] Teams may expect this change to solve navigation/access-path gaps too.
  Mitigation: keep the non-goals explicit in the rule, design, and tests, and preserve the boundary with semantic-review access-path checks.

## Migration Plan

1. Extend upstream preservation input:
   - update `overmind/rules/prerequisite_gaps_rule.md` so required missing operator-facing surfaces remain explicitly identifiable for downstream consumers
   - update `overmind/scripts/helper/check_prerequisite_gaps_quality.sh` so the prerequisite artifact validation enforces that preserved operator-facing surfaces remain distinguishable from transport-only and internal gaps
2. Update planning rules:
   - update `overmind/rules/implementation_slices_rule.md`
   - update `overmind/rules/implementation_plan_rule.md`
   - update matching templates and golden examples where those rules need preserved-surface examples
3. Extend quality helpers:
   - update `overmind/scripts/helper/check_implementation_slices_quality.sh`
   - update `overmind/scripts/helper/check_implementation_plan_quality.sh`
4. Add regression coverage:
   - prerequisite-gap validation tests for required missing operator-facing surfaces versus transport-only/internal gaps, including `unmet` to `scheduled_in_slices` transitions
   - slice-level and plan-level tests for missing login surface, missing protected shell, missing admin entry route, and missing operator-facing lookup page
   - negative tests confirming that supporting-only auth/API/coordination work does not satisfy preserved-surface coverage
   - positive tests confirming equivalent operator-surface wording passes without relying on one exact route literal or one framework-specific label
   - negative tests confirming that no user-facing work is fabricated when upstream requirements do not require one

Rollback strategy: revert the prerequisite-gap classification extension, the planning-rule updates, the two helper changes, and their tests together. Without those four pieces moving together, the pipeline would mix old and new preservation semantics.

## Open Questions

None. The core design boundary is settled: preserve required missing operator-facing surfaces through slices and plan, but do not expand this change into navigation-affordance or coordination policy.
