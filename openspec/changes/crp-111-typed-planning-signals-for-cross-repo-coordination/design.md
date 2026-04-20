## Context

Section 6 of `technical_requirements.md` currently mixes two incompatible goals:
- preserve cross-repo coordination intent for downstream planning, and
- stay lightweight enough that technical requirements do not become a hidden planning phase.

Today that section is expressed as loose `constraint_*` and `prep_*` prose, and the quality helper requires at least one of each. That creates two concrete problems:
- the artifact cannot say "no coordination signal is needed here" in a typed, reviewable way, and
- downstream phases must reconstruct coordination intent from prose instead of consuming a stable contract.

Gap 2 is deliberately narrower than the later coordination work. This change does not add a coordination planner. It only gives Step 7 a typed advisory surface so cross-repo intent can survive into later phases without forcing those phases to overreact.

## Goals / Non-Goals

**Goals:**
- Replace the current section 6 loose-entry contract with zero or more typed `### Planning Signal:` blocks plus one explicit empty marker when no signal is needed.
- Add one initial signal type, `cross_repo_contract_lock`, with a fixed required field set.
- Keep planning signals advisory-only so they preserve intent without becoming mandatory execution steps.
- Update the rule, template, golden example, and quality helper together so the contract is deterministic.
- Add targeted tests for valid signal, empty marker, unresolved evidence, duplicate ids, and invalid repo ownership.

**Non-Goals:**
- Do not require a planning signal for every multi-repo feature.
- Do not require a planning signal merely because `feature_contract_delta.md` reports `delta_needed: true`.
- Do not make section 6 a blocker when no signal is needed.
- Do not create a new planning artifact or coordination workflow in this change.
- Do not let `must_precede` or `output_requirements` turn into hidden slice or plan steps during the technical-requirements phase.

## Decisions

1. Keep section 6 in place, but replace its inner shape with typed blocks or an exact empty marker
Rationale: keeping section 6 avoids unnecessary artifact churn while still fixing the contract. The new valid states are:
- one or more `### Planning Signal:` blocks, or
- the exact empty-path line `- planning_signals: none`

This preserves the artifact outline while eliminating ambiguous `constraint_*` / `prep_*` prose.
Alternative considered: create a new top-level section or a separate coordination artifact. Rejected because Gap 2 is only about typed carry-forward intent, not about adding another planning phase.

2. Start with one supported signal type: `cross_repo_contract_lock`
Rationale: the current gap is real, but the repo does not yet need a broad signal taxonomy. One narrow type keeps the contract easy to teach, test, and validate. It also leaves room for a later change to add more types once downstream consumers are clearer.
Alternative considered: introduce several signal types immediately. Rejected because it would expand the change beyond Gap 2 and encourage consumers to infer more behavior than the pipeline currently supports.

3. Make `source_evidence` resolve against artifact-local anchors only
Rationale: the helper needs deterministic validation without crawling unrelated artifacts. `source_evidence` should therefore resolve only against:
- section 4 requirement refs: `REQ-*` / `NFR-*`
- section 5 component refs: `comp/<component-slug>`

`component-slug` should be derived from the `### Component:` heading by lowercasing it and replacing non-alphanumeric runs with `-`.
Alternative considered: allow arbitrary prose evidence. Rejected because prose reintroduces the same ambiguity this change is trying to remove.

4. Validate structure only; never infer whether a signal was required
Rationale: Gap 2 explicitly says the signal means "coordination may be needed here", not "coordination is now mandatory". The helper should therefore check only:
- unique `signal_id`
- supported `signal_type`
- required fields present
- `owner_repo` and `consumer_repos` belong to active repo classes
- `source_evidence` tokens resolve
- the empty marker is accepted

The helper must not fail solely because the feature is multi-repo or because a contract delta exists.
Alternative considered: require a signal whenever the feature spans multiple repos or exposes shared-contract drift. Rejected because that would turn advisory metadata into a hard policy gate.

5. Keep sequencing fields declarative and non-executable
Rationale: `must_precede` and `output_requirements` are useful because they explain the coordination concern in a reviewable way. They should remain plain advisory fields inside the signal block, not plan-step identifiers and not generator instructions.
Alternative considered: require downstream step ids or task ids in the signal. Rejected because that would collapse planning into technical requirements and create hidden execution obligations too early.

6. Avoid production script changes unless the existing staged command truly depends on old section 6 wording
Rationale: `feature_technical_requirements.sh` already delegates artifact content to the rule, template, golden example, and helper. The minimal-change path is to update the contract files and tests first, then only touch the orchestrator if a real hardcoded dependency appears.
Alternative considered: proactively edit the staged command. Rejected because no current evidence shows the script owns section 6 semantics directly.

## Risks / Trade-offs

- [Risk] Downstream consumers may start treating `planning_signal` blocks as mandatory coordination work.
  Mitigation: keep the specs and rule explicit that signals are advisory only, and keep the helper policy-free.

- [Risk] Writers may keep using loose `constraint_*` / `prep_*` prose under section 6 after typed blocks exist.
  Mitigation: update the template and golden example to show only the typed form, and make the helper reject the legacy loose-entry shape.

- [Risk] Empty-path handling could regress into a silent omission instead of an explicit choice.
  Mitigation: require the exact empty marker `- planning_signals: none` so "no signal needed" is visible and testable.

- [Risk] Evidence-token validation could become brittle if token formats are too broad.
  Mitigation: keep `source_evidence` scoped to local requirement refs and normalized component slugs only.

- [Risk] The unchanged section heading may suggest that `constraint_*` prose is still allowed.
  Mitigation: keep the heading for continuity, but rewrite the rule/template/example so the only accepted section-6 shapes are typed planning-signal blocks or the empty marker.

## Migration Plan

1. Update the section 6 contract files:
   - `overmind/rules/technical_requirements_rule.md`
   - `overmind/templates/technical_requirements_TEMPLATE.md`
   - `overmind/golden_examples/technical_requirements_GOLDEN_EXAMPLE.md`
2. Update `overmind/scripts/helper/check_feature_technical_requirements_quality.sh` to parse typed section-6 content, resolve evidence tokens, and accept the empty marker.
3. Update the section-6 fixtures and assertions in:
   - `tests/ai_scripts/check_feature_technical_requirements_quality_tests.sh`
   - `tests/ai_scripts/init_feature_technical_requirements_tests.sh`
4. Re-run the affected test suites and confirm the change is apply-ready through `openspec status`.

Rollback strategy: revert the rule/template/golden example/helper/test changes together. The rest of the technical-requirements artifact remains intact, so section 6 can return to the prior loose-entry contract without affecting unrelated sections.

## Open Questions

- None for this change. Additional planning-signal types and any real coordination-planning behavior should be handled in later follow-up work rather than folded into Gap 2.
