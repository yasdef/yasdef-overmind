## Context

The successful master-era implementation is recoverable from repository history. At revision `4c076e8a`, its Task-to-BR rule required every unresolved or low-confidence business detail to be externalized as a follow-up question, while its helper validated artifact and ledger structure only. For the measured UMSS story, step 4.1 commit `7f5e47e5` created five `rised=false` questions and step 4.2 commit `7ddb91e2` recorded their answers and marked them `rised=true`.

CRP-172 replaced that broad discovery instruction with a source-obligation review, an explicit behavioral-materiality taxonomy, several question-suppression rules, and a closed lexical validator over the generated BR. In the post-CRP UMSS run, step 4.1 preserved more raw facts but produced only one question, driven by the token `simple`; the question did not change acceptance behavior. The historical and current runs use the same configured models and reasoning levels, so the behavioral contract is the principal controlled difference.

The current TypeScript runtime, context builder, packaged-skill layout, and ledger lifecycle remain valuable. This change restores the old model responsibility inside that architecture rather than restoring the old shell implementation.

## Goals / Non-Goals

**Goals:**

- Restore active discovery of relevant unresolved or low-confidence business details during step 4.1.
- Keep the discovery rule as concise and open-ended as the successful master rule.
- Feed step 4.2 useful business questions through the existing `missing_br_data.md` contract.
- Return deterministic validation to structural and lifecycle concerns.
- Reduce model-facing policy introduced by CRP-172 instead of adding another corrective layer.

**Non-Goals:**

- Change step 4.2 interaction or readiness behavior.
- Change EARS generation or step 5.1 review behavior.
- Restore legacy shell orchestration or legacy runtime paths.
- Add a new artifact, phase, model call, validator, state, command, or CLI option.
- Require an exact question count or encode the measured UMSS questions as a fixed acceptance list.

## Decisions

### 1. Port the master discovery responsibility, not the master shell

The inlined rule in `packages/installer/_data/skills/overmind-task-to-br/SKILL.md` will again state that every relevant unresolved or low-confidence business detail must be externalized as a targeted business question. The model reads the raw story and current BR, fills what the source supports, and creates a question rather than silently completing a business detail it cannot state confidently.

The rule remains limited to business intent, actors, access, scope, rules, inputs, outputs, states, failures, and user-visible outcomes. Technical implementation choices remain outside Task-to-BR clarification.

Alternative considered: refine CRP-172's materiality taxonomy with more cases. Rejected because the v4 run showed that the decision tree itself became a question-suppression surface, and expanding it would repeat the workaround pattern.

### 2. Remove the CRP-172 question-suppression policy

The dedicated Source-Obligation Review, behavioral-impact enumeration, and clauses that pre-classify source wording as not question-worthy will be removed. A source statement may be represented faithfully and still leave a useful business decision open; for example, “do not create a duplicate” does not define the repeat-request disposition, and “simple non-sensitive error” does not define the intended user-visible response.

The restored rule does not require questions for facts stated clearly enough to use. It relies on model business judgment, as master did, rather than an enumerated allow/deny decision tree.

Alternative considered: keep both policies and give the master clause higher priority. Rejected because competing criteria would preserve ambiguity about which rule governs and would increase model-facing complexity.

### 3. Remove closed lexical enforcement from the Task-to-BR validator

`packages/asdlc-coordinator/src/validate/task-to-br.ts` will stop scanning generated BR fields for the six configured words and stop emitting ambiguity-trigger diagnostics. Corresponding focused validator tests will be removed or rewritten around the surviving structural contract.

The validator continues to check document structure, required metadata and source references, FR/BR shape, unresolved-item syntax, locator consistency, answer pointers, and terminal ledger state. Semantic gap discovery remains model-owned.

Alternative considered: keep the lexical list as a backstop. Rejected because the measured v4 run shows the enforced backstop dominated the semantic task and generated the only question, while master achieved better discovery with no lexical validator.

### 4. Preserve modern transport and ledger mechanics unchanged

The TypeScript capture/context commands, raw-story inlining, required source references, Jira persistence, linked-artifact extraction, allowed-write surface, `rised_item_N` schema, terminal-state rules, and stable gate exit codes remain. `missing_br_data.md` continues to be emitted for every current Task-to-BR run, including an empty terminal ledger when no gap is discovered.

Step 4.2 remains a ledger consumer. Its “ask no questions when no unresolved items exist” behavior is unchanged because the historical implementation also skipped clarification when no pending ledger item existed; the quality difference arose in step 4.1 discovery.

### 5. Keep examples informative but non-normative

The existing `feature_br_summary.md` and `missing_br_data.md` golden examples will stay aligned and demonstrate several useful question shapes, such as an unspecified eligible audience, valid-input boundary, repeat-request outcome, or user-visible failure response. They will not prescribe an exact count, require those domains for every story, or contain policy prose explaining which candidate questions are forbidden.

Tests will assert that the restored skill contract and examples survive installation, that the lexical validator policy is absent, and that preserved runtime and ledger contracts remain intact. Model-run quality will be evaluated by the operator after implementation rather than represented as a deterministic test or mandatory implementation task.

## Risks / Trade-offs

- [Risk] Broad discovery may produce more questions than CRP-172. → Mitigation: retain the business-only scope and one-question-per-independent-gap rule; evaluate usefulness through the operator run rather than a hard-coded ceiling.
- [Risk] Removing lexical enforcement loses deterministic detection of configured words. → Mitigation: those words remain useful illustrative examples in the model-owned discovery guidance, matching the master responsibility split.
- [Risk] Simplifying the skill could remove unrelated modern contracts. → Mitigation: preserve and assert capture, source-reference, Jira, linked-artifact, runtime-path, ledger, terminal-state, and exit-code clauses explicitly.
- [Risk] Model variability can still change question recall. → Mitigation: first restore the proven master contract with the same model settings, then assess the resulting run before introducing any further change.

## Migration Plan

1. Simplify the packaged Task-to-BR inlined rule to the master-style active discovery contract while preserving modern invocation and artifact mechanics.
2. Remove the closed lexical scan and its diagnostics from the TypeScript validator.
3. Revise the existing golden example and focused contract tests.
4. Run coordinator, installer, and repository verification suites.
5. Install and evaluate step 4.1 manually against the same UMSS source before deciding on any subsequent CRP.

Rollback is a normal revert of the skill, validator, example, and tests; no runtime artifact migration is required.

## Open Questions

None.
