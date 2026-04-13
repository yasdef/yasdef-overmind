## Context

`crp-097` and `crp-098` strengthen deterministic implementation-plan validation around step-level requirement links, step-level technical evidence, and unresolved-work coverage. Those gates are intentionally structural: they can prove that a plan is linked and complete enough to execute, but they cannot make higher-order semantic judgments such as:

- whether one step combines unrelated behavior that should be split,
- whether one repo slice hides two independent technical gaps behind one heading,
- whether dependency ordering is formally valid but semantically awkward for handoff or review.

Those judgments are best handled by a model-driven review pass, not by expanding the shell helper into fuzzy heuristics. The repository already uses an optional review pattern at Step `4.1`, so Step `8.1` can follow the same staged-optional idea while staying report-only and non-blocking.

## Goals / Non-Goals

**Goals:**
- Add an optional Step `8.1` immediately after implementation-plan generation.
- Stage a dedicated feature command for semantic review of `implementation_plan.md`.
- Produce one durable artifact, `implementation_plan_semantic_review.md`, beside other feature-phase outputs.
- Keep the review focused on semantic cohesion, split quality, and ordering/dependency quality at implementation-step scope.
- Reuse the existing optional-step scanner pattern so incomplete Step `8.1` does not block later required progress.

**Non-Goals:**
- Do not redesign or replace the deterministic structural helper for implementation plans.
- Do not move FR or evidence links to checklist bullets.
- Do not automatically mutate `implementation_plan.md` as part of semantic review.
- Do not introduce an interactive yes/no remediation loop like `requirements_ears_review`; this phase is a report artifact, not a mutation workflow.

## Decisions

1. Make Step `8.1` report-only
Rationale: the purpose of the phase is to surface semantic quality findings, not to silently rewrite the shared plan. Keeping it report-only reduces risk, preserves human control, and makes the optional phase easy to rerun after manual plan updates.
Alternative considered: automatically rewrite `implementation_plan.md` based on semantic findings. Rejected because semantic restructuring is judgment-heavy and should remain explicit and reviewable.

2. Keep the review at implementation-step scope
Rationale: the current implementation-plan contract is step-centered for repo ownership, FR links, evidence links, and dependencies. Semantic review should reason over the same unit instead of inventing a second bullet-level review surface.
Alternative considered: review individual checklist bullets. Rejected because the requested contract is step-level, and semantic slicing concerns are primarily about step boundaries.

3. Use a dedicated review artifact with a findings ledger
Rationale: a durable artifact makes semantic concerns visible in history, review, and later planning adjustments. A lightweight findings ledger can record `no_findings: true` or explicit findings with severity, target steps, and recommended restructuring.
Alternative considered: stdout-only advice. Rejected because it is not durable, hard to gate, and easy to lose.

4. Model Step `8.1` as optional in progress definition
Rationale: Step `4.1` already proves the scanner can render optional feature steps without blocking later required progress. Reusing that pattern keeps the new phase low-friction and makes bootstrap/update behavior predictable.
Alternative considered: make semantic review mandatory. Rejected because the user asked for an optional phase and the value depends on plan complexity.

5. Add a dedicated quality helper for the semantic-review artifact
Rationale: even though the review itself is model-generated, the artifact shape should still be deterministic enough to validate for completeness, target references, and `no_findings`/ledger consistency.
Alternative considered: rely on the command alone without a helper. Rejected because staged feature phases in this repo normally prove their output contract with a helper before completion.

## Risks / Trade-offs

- [Risk] Teams may confuse semantic review findings with hard structural failures.
  Mitigation: keep this artifact separate from `check_implementation_plan_quality.sh` and document it as an optional semantic pass after structural validation.

- [Risk] A report-only phase may create findings without ensuring they are acted on.
  Mitigation: make recommendations explicit and step-targeted so users can revise `implementation_plan.md` deliberately and rerun Step `8` or `8.1`.

- [Risk] Review output could drift into style commentary instead of semantic planning issues.
  Mitigation: constrain the rule to cohesion, split quality, dependency sense, and requirement/evidence grouping, and exclude wording-only comments.

- [Risk] Optional-step handling could regress scanner next-step behavior.
  Mitigation: reuse the existing optional-step pattern in YAML and add scanner tests proving Step `8.1` can remain incomplete without blocking progress.

## Migration Plan

1. Add the semantic-review artifact scaffold:
   - `overmind/rules/implementation_plan_semantic_review_rule.md`
   - `overmind/templates/implementation_plan_semantic_review_TEMPLATE.md`
   - `overmind/golden_examples/implementation_plan_semantic_review_GOLDEN_EXAMPLE.md`
   - `overmind/scripts/helper/check_implementation_plan_semantic_review_quality.sh`
2. Add the staged command:
   - `overmind/scripts/feature_implementation_plan_semantic_review.sh`
3. Add the phase row to `overmind/setup/models.md`.
4. Update `overmind/templates/init_progress_definition_TEMPLATE.yaml`, `overmind/init_progress_definition_sequence_diagram.md`, and `overmind/README.md` for optional Step `8.1`.
5. Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` so first-init/update staging includes the new command and support assets.
6. Add tests in `tests/ai_scripts/` for staged-command behavior, artifact generation, helper validation, staging, and scanner optional-step rendering.

Rollback strategy: remove the Step `8.1` scaffold, staged command, helper, and progress-template entry together, leaving Step `8` as the final planning phase.

## Open Questions

- None. The main design question was whether `8.1` should mutate the plan or produce a review report, and this change resolves that in favor of a report-only optional phase.
