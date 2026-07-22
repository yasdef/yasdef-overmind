## Context

The legacy master Task-to-BR run used a short, focused rule that required every unresolved or low-confidence business detail to become a follow-up question. During that single step 4.1 session, the model resolved five business uncertainties with the operator and recorded the answers in `confirmed_assumptions`; it created no `missing_br_data.md`, so the legacy step 4.2 did not run. The migrated ledger handoff is a deliberate improvement, but its larger procedural contract and TypeScript ambiguity gate recognize six literal tokens only after the model has written `feature_br_summary.md`. In the measured post-CRP-170 UMSS run the model removed `simple` while paraphrasing the source, the derived-BR gate passed, and step 4.2 received only one question while step 4.1 missed material valid-input criteria, the orphan/pre-linked-account outcome, and the under-specified error response.

Step 4.2 already has the correct responsibility: it asks the unresolved questions recorded by step 4.1. The correction therefore belongs in the model-owned Task-to-BR semantic extraction contract, while TypeScript remains responsible for deterministic capture, paths, artifact structure, and stable gate exit codes.

## Goals / Non-Goals

**Goals:**

- Restore focused source-obligation review before Task-to-BR completion.
- Produce one relevant business question for every unresolved decision that can change observable behavior or acceptance.
- Preserve all current artifacts, step boundaries, ledger syntax, and gate exit codes.
- Demonstrate quality against the identical UMSS source over repeated model runs, not only contract fixtures.
- Reduce competing model-facing semantic and gate-mechanics prose where the same requirement is repeated.

**Non-Goals:**

- Add a phase, artifact, traceability matrix, semantic validator, model call, command, or CLI option.
- Make step 4.2 discover questions that step 4.1 missed.
- Redirect the closed lexical gate to unstructured raw prose or make each raw token occurrence an automatic question.
- Require the candidate run to reproduce every legacy question or the same total question count.
- Change Jira capture, linked-artifact extraction, source-reference binding, or readiness behavior.

## Decisions

### 1. Replace layered ambiguity prose with one focused source-obligation review

The deployed Task-to-BR skill will require the model to inspect the captured story before finalizing the BR. For each explicit acceptance criterion, business rule, scope statement, negative path, prohibition, actor, guard, state, outcome, and required data result, the model determines whether the source provides enough business information for an observable acceptance decision.

When a material decision is missing, the model writes one targeted `rised=false` question to the existing ledger and leaves the affected BR field `[UNFILLED]`. This review is an internal authoring method, not a new artifact or template section.

The skill text will state this contract once in a dedicated section and reference it from completion criteria instead of restating variants across hard constraints, missing-data mechanics, ambiguity scope, and quality criteria.

Alternative considered: add another model review pass after Task-to-BR. Rejected because it adds latency and another orchestration surface for a responsibility the Task-to-BR model already owns.

### 2. Define materiality by behavioral impact, not lexical presence

A question is material when different reasonable answers would change an actor, guard, allowed or rejected outcome, state transition, persisted result, returned data, scope boundary, or acceptance verification. The model does not ask when the raw source already supplies the answer, when the wording is descriptive but bounded by adjacent criteria, or when the choice is purely technical implementation.

One independent decision produces one question. If the same fact appears in several BR fields, the existing multi-field `source=` locator records every destination while the ledger contains one question.

Alternative considered: require one question per raw ambiguity-token occurrence. Rejected because the measured source uses `simple` for both descriptive phrases and an acceptance-affecting error response; automatic rows would lower question relevance and require deterministic mapping from raw prose to BR fields that does not exist.

### 3. Keep the lexical gate as a backstop, not a completion definition

The existing TypeScript scan over generated business fields remains unchanged by this CRP. It catches configured words that survive into the BR, but a clean lexical result does not replace the source-obligation review and is not described as proof of semantic completeness.

No new raw-source lexical gate or semantic equivalence validator is added. Semantic question discovery remains model-owned, matching the legacy quality mechanism; step 5.1 remains the independent downstream recovery mechanism addressed by CRP-173.

Alternative considered: point `AMBIGUITY_TRIGGERS` at `user_br_input.md`. Rejected because immutable raw tokens would either block step 4.1 until the later clarification step or need new occurrence-disposition state, creating a circular or more complex workaround.

### 4. Measure Task-to-BR recovery independently of CRP-173

CRP-172 acceptance examines only the BR and clarification ledger produced by step 4.1 from the measured UMSS source. It does not run step 5.1 and does not depend on CRP-173 being implemented first. CRP-173 measures the separate downstream recovery path and may be implemented in either order without changing CRP-172's baseline.

### 5. Use the legacy run as a behavioral baseline, not an exact-output golden

Acceptance uses the identical UMSS source and the same configured model settings. One acceptance batch contains three independent clean candidate runs because the measured migrated runs produced four, three, and one questions from the same source.

Every run in an accepted batch must surface the three known acceptance-shaping decisions: valid-versus-invalid Telegram data; the outcome when new-identity creation encounters an inconsistent pre-existing OFFCHAIN_POINTS account without a corresponding identity; and the under-specified frontend error response. Questions about whether user counts include identities without an ACTIVE OFFCHAIN_POINTS account, and any other additional questions, are evaluated by the same behavioral-impact materiality rule rather than accepted or rejected because master did or did not ask them.

If any run misses one of the three required decisions, the whole batch fails. The implementer does not extend a failed batch with extra samples: they identify the missed source obligation, revise the skill or example within this CRP, rerun contract verification, and start one fresh three-run batch. If that replacement batch also fails, the CRP remains behaviorally incomplete and returns to the owner for an explicit decision before the acceptance rule is changed or further batches are run.

This is behavioral acceptance evidence and remains unchecked until the actual installed skill is rerun. Unit and installer tests prove contract propagation only.

Alternative considered: assert that the new run emits exactly five questions. Rejected because two legacy questions were lower-value contextual questions and exact wording/count would reward over-questioning rather than business quality.

## Risks / Trade-offs

- [Risk] Model variability can still omit a material question. → Mitigation: fail the complete three-run batch on a miss, revise the semantic contract before one fresh batch, and require owner disposition after a second failed batch instead of accumulating favorable samples; CRP-173 remains a separately measured downstream recovery path.
- [Risk] A broad semantic review can over-question descriptive wording. → Mitigation: define materiality by observable acceptance impact and include positive and negative examples in the golden example or contract tests.
- [Risk] Simplifying the skill can accidentally remove capture or ledger constraints. → Mitigation: limit simplification to duplicated semantic/gate prose and add contract assertions that capture, runtime paths, ledger syntax, source references, linked-artifact handling, readiness, and final-gate clauses remain present.
- [Risk] The lexical backstop may continue to create false confidence in operator messaging. → Mitigation: state explicitly that it is a bounded backstop and require behavioral acceptance before declaring the correction complete.

## Migration Plan

1. Rewrite the Task-to-BR skill's semantic authoring section around the focused source-obligation review and materiality rule.
2. Update the Task-to-BR golden example and contract tests to distinguish a material ambiguity from a descriptive bounded phrase.
3. Run the existing coordinator, installer, and repository verification suites.
4. Install the candidate skill into clean runtime workspaces and run the identical UMSS Task-to-BR flow at least three times.
5. Record the material-question acceptance result. If one run misses a required decision, revise the contract and run one fresh three-run batch rather than adding samples to the failed batch.
6. If the replacement batch also fails, keep behavioral acceptance incomplete and return to the owner for explicit disposition.

Rollback is a normal revert of the skill, example, and tests; no stored artifact or command migration is required.

## Open Questions

None.
