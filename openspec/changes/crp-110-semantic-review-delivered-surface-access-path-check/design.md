## Context

`crp-099` introduced an optional implementation-plan semantic-review phase and `crp-100` repositioned it as optional Step `8.3`. `crp-108` split transport-layer presence from `user_reachable_surface`, and `crp-109` added `prerequisite_gaps.md` so required upstream operator-facing prerequisites cannot disappear before plan generation.

The remaining hole is downstream and semantic rather than structural. A plan can still add a new route, page, screen, CLI command, or endpoint and leave it practically unreachable because no inbound affordance exists or is planned. That failure is not the same as prerequisite-gap coverage: the surface itself is being delivered, but semantic review does not yet ask whether operators can actually get to it once delivered.

## Goals / Non-Goals

**Goals:**
- Extend Step `8.3` semantic review so it evaluates newly delivered user-reachable surfaces for inbound access-path clarity.
- Keep this check semantic and report-only, not a hard structural failure in `check_implementation_plan_quality.sh`.
- Ground the review in existing evidence sources: `prerequisite_gaps.md` when present and repo-class surface maps for inbound affordances.
- Add an explicit finding type and artifact-contract rules so accepted and rejected outcomes are both durable and reviewable.
- Enforce that terminal delivered-surface findings always carry non-empty `resolution_notes`.

**Non-Goals:**
- Do not move delivered-surface reachability into a hard structural quality gate.
- Do not require every isolated surface to be wrong; intentional isolation remains a valid outcome.
- Do not invent navigation or operator-flow requirements that are not justified by `requirements_ears.md` or explicit operator confirmation.
- Do not change the prerequisite-gap contract from `crp-109`; this change only consumes that artifact as context when available.

## Decisions

1. Keep delivered-surface reachability in semantic review
Rationale: the presence or absence of an inbound affordance is structurally observable, but deciding whether the missing path is a defect or intentional requires product-fit judgment. Step `8.3` already exists to capture judgment-driven planning issues, so the new check belongs there rather than in a shell gate.
Alternative considered: add the check to `check_implementation_plan_quality.sh`. Rejected because that would hard-fail intentionally isolated surfaces and force shell logic to make semantic product decisions.

2. Add a dedicated finding type instead of overloading existing semantic-review findings
Rationale: `delivered_surface_consumption_unclear` makes the concern explicit in the artifact, tests, and review discussions. A named finding type also allows the template and helper to enforce special handling such as mandatory `resolution_notes`.
Alternative considered: fold access-path concerns into a generic semantic finding bucket. Rejected because the new behavior would become ambiguous and difficult to validate deterministically.

3. Use a four-step heuristic grounded in surface maps and sibling steps
The reviewer should:
1. identify the delivered user-reachable surface,
2. inspect the applicable surface map for existing inbound affordances,
3. inspect sibling implementation steps for newly added inbound affordances,
4. raise a semantic finding if neither exists.

Rationale: this sequence is specific enough to be repeatable across runs without pretending the final judgment is mechanical.
Alternative considered: inspect only the target step or only the surface map. Rejected because inbound access may be introduced elsewhere in the same plan, and ignoring sibling steps would over-report false positives.

4. Treat `prerequisite_gaps.md` as optional supporting context, not the source of the finding
Rationale: prerequisite gaps reason about upstream required surfaces before plan generation. The new check reasons about newly delivered surfaces after plan generation. `prerequisite_gaps.md` is still useful supporting context for understanding intended operator journeys, but it should not redefine the delivered-surface check.
Alternative considered: derive the finding exclusively from `prerequisite_gaps.md`. Rejected because many newly delivered surfaces will not appear there as missing prerequisites.

5. Require non-empty `resolution_notes` for terminal delivered-surface findings
Rationale: this finding is inherently judgment-based. If a reviewer applies or rejects it without written resolution notes, the artifact loses the reasoning that justifies the decision and becomes hard to audit.
Alternative considered: allow empty notes when a status is terminal. Rejected because it weakens the only durable explanation for a non-mechanical decision.

## Risks / Trade-offs

- [Risk] Review output may over-flag intentionally isolated admin or setup surfaces.
  Mitigation: keep the check in semantic review and require `resolution_notes`, so reviewers can reject the finding explicitly when isolation is intentional.

- [Risk] Surface-map quality may be uneven across repo classes, reducing confidence in inbound-affordance checks.
  Mitigation: reuse the existing surface-map artifacts as evidence and scope the rule to the applicable repo classes present for the feature.

- [Risk] Adding more review inputs could make the semantic-review prompt noisier.
  Mitigation: bind only the applicable surface maps and `prerequisite_gaps.md` when present; do not broaden the context with unrelated artifacts.

- [Risk] Users may confuse this new finding with the prerequisite-gap gate from `crp-109`.
  Mitigation: document the distinction in the rule and examples: prerequisite gaps cover missing upstream required surfaces, while this finding covers reachability of newly delivered surfaces.

## Migration Plan

1. Update semantic-review contracts:
   - `overmind/rules/implementation_plan_semantic_review_rule.md`
   - `overmind/templates/implementation_plan_semantic_review_TEMPLATE.md`
   - `overmind/golden_examples/implementation_plan_semantic_review_GOLDEN_EXAMPLE.md`
2. Update the staged command:
   - `overmind/scripts/feature_implementation_plan_semantic_review.sh`
   - bind `prerequisite_gaps.md` and active repo-class surface maps into the review context when present
3. Update validation:
   - extend `overmind/scripts/helper/check_implementation_plan_semantic_review_quality.sh` so terminal `delivered_surface_consumption_unclear` findings require non-empty `resolution_notes`
4. Add tests:
   - a delivered surface with no inbound edge emits the finding
   - a sibling inbound-affordance step suppresses the finding
   - terminal delivered-surface findings fail validation when `resolution_notes` is empty

Rollback strategy: revert the semantic-review rule, template, golden example, command context bindings, and helper updates together. The optional Step `8.3` phase remains in place without the delivered-surface check.

## Open Questions

- None. The main unresolved point was whether this should be a hard gate or a semantic-review heuristic, and this change resolves it in favor of the existing optional semantic-review phase.
