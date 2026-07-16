## Context

The current task-to-BR rule already requires every unresolved or low-confidence business detail to enter `missing_br_data.md`, and it explicitly names ambiguity triggers such as `simple`. Its operational move list and TypeScript gate, however, inspect only `### Needs validation -> assumptions_needing_validation`, `## 15. Open Questions`, and `### 5.3 Open scope boundaries -> unclear_scope_points`. An ambiguous value in `## 10. Failure Cases and Edge Cases -> rejection_cases` can therefore remain populated and pass the gate.

The BR template also has multiple plausible destinations for negative source statements. In the measured UMSS run, explicit Definition of Done prohibitions survived under `## 12. Non-Functional Requirements -> ### 12.4 Operational and rollout -> config_expectations`, but did not reach `### 2.3 Explicitly stated in source -> stated_constraints` or `### 5.2 Out of scope -> out_of_scope_items`. The requirements-EARS skill reads all three areas, yet the resulting EARS overview dropped the prohibitions because their scope role was no longer explicit.

Finally, `packages/installer/_data/skills/overmind-requirements-ears/SKILL.md` currently says to prefer narrower requirements. This permits a specific case such as a missing Telegram user id to replace the broader source obligation for invalid Telegram user data. The TypeScript EARS gate validates block shape, numbering, and EARS syntax; semantic source coverage remains model-owned.

The correction stays within the current Task-to-BR → BR clarification → requirements-EARS flow.

## Goals / Non-Goals

**Goals:**

- Externalize acceptance-affecting ambiguity from every relevant structured BR field through the existing ledger and clarification loop.
- Place explicit source prohibitions in fields that preserve their scope meaning.
- Prevent specific rules and examples from silently narrowing broader BR obligations during EARS conversion.
- Require a final model-owned coverage sweep for scope constraints, functional and rejection behavior, NFRs, and required test levels.
- Keep rule, deployed skill, deterministic gate, golden examples, and tests aligned.

**Non-Goals:**

- Add a phase, artifact, template field, command, CLI option, or operator decision.
- Change EARS review behavior.
- Build a general natural-language entailment engine or grep raw source prose for every possible prohibition.
- Require an exact error-message literal unless the existing clarification loop obtains one from the operator.
- Change EARS document structure or gate exit-code semantics.

## Decisions

### 1. Keep semantic ownership in the deployed skills

The deployed task-to-BR skill is the durable task-to-BR source of truth, and the requirements-EARS conversion contract stays in its deployed skill because that migrated step has no surviving legacy `br_to_ears` rule file. Implementation began by editing `overmind/rules/task_to_br_rule.md` in parallel with the skill; maintaining both surfaces is what exposed the duplication that decision 6 resolves by retiring the legacy rule directory. Templates remain structural; golden examples illustrate the updated quality target.

The model owns judgments such as whether wording materially affects acceptance, whether a negative source statement is an explicit prohibition, and whether two requirements overlap. TypeScript enforces only deterministic structure and the closed lexical ambiguity backstop described below.

Alternative considered: introduce a semantic validator comparing raw input, BR, and EARS. Rejected because it would add a second model/process surface and exceed the low-blast correction.

### 2. Generalize ambiguity handling with a bounded deterministic backstop

The semantic task-to-BR rule applies to populated business fields in `## 2. Source Request Snapshot` except `### 2.2 Raw source references`, `## 3. Feature Intent` through `## 12. Non-Functional Requirements`, `## 14. Assumptions`, and `## 15. Open Questions`. `## 1. Document Meta`, `## 13. Existing-System Context`, and `## 16. Linked Artifacts` are outside this scan because they carry metadata, repo-scan evidence, or artifact locators rather than source business wording.

The TypeScript task-to-BR validator reuses the current markdown traversal and adds a closed, case-insensitive whole-word/phrase check for the ambiguity triggers named by the durable rule. A populated scanned field containing a trigger fails with an actionable field-specific diagnostic unless `missing_br_data.md` contains a `rised=true` item whose normalized `source=<section> -> <field>` locator matches that field. The missing-data parser exposes the source locator rather than making the validator scrape the raw ledger line repeatedly.

Reporting is grouped by trigger; confirmation stays per field. A BR routinely restates one business fact as a constraint, a functional requirement, and a business rule — on the measured UMSS summary a single under-specified error response occupies five fields. Reporting each field separately turns one open question into five near-duplicate diagnostics, so the gate emits one problem per trigger naming every field that still retains it.

Evidence, however, must name the field it clears. The same trigger word carries different questions in different fields: the measured summary uses `simple` for the error response, for adoption counts, and for the first-sprint flow. A confirmation that cleared every occurrence of the word would silently accept the other two. An answered `rised=true` item therefore confirms exactly the fields its `source=` locator list names, and the ledger marker accepts a comma-separated list so one answered question can cover every field that restates it. A one-locator item is the same syntax with one element, so existing ledgers stay valid.

For an unresolved trigger, the skill follows the current lifecycle: create a `rised=false` item, replace the source value with `[UNFILLED]`, and let BR clarification obtain the answer. A `rised=false` item does not permit the ambiguous wording to remain populated. If the operator explicitly confirms the original wording, the answered `rised=true` item provides durable evidence and the gate permits it.

The semantic rule continues to catch acceptance-affecting ambiguity beyond the closed examples even when the deterministic backstop cannot recognize it.

Alternative considered: scan every string in the file or reject every lexical match unconditionally. Rejected because metadata, locators, repo evidence, and explicitly confirmed language would create avoidable false positives.

### 3. Route explicit prohibitions by meaning before downstream conversion

Every explicit source prohibition—such as `no X`, `does not introduce X`, an Out of Scope entry, or a negative Definition of Done statement—must appear in either `### 2.3 Explicitly stated in source -> stated_constraints` or `### 5.2 Out of scope -> out_of_scope_items`. The same statement may also be recorded in another relevant field such as `config_expectations`; only that additional placement is insufficient.

This is a model-owned extraction and quality rule. The TypeScript gate does not grep raw source negations because reliable equivalence between source prose and normalized BR wording is not deterministic. The task-to-BR golden example and installed-skill contract tests make the routing expectation visible and prevent accidental removal.

Alternative considered: add a raw-source negation grep. Rejected because incidental negation and paraphrased prohibitions would produce both false positives and false negatives.

### 4. Make broad requirements authoritative unless specificity is explicitly exhaustive

The requirements-EARS skill replaces unconditional `Prefer narrower requirements` guidance with an additive precedence rule:

- A specific rule, failure case, or example refines the broader requirement.
- Both broad coverage and the specific case remain represented when they impose distinct testable obligations.
- The specific case may replace the broad requirement only when the BR summary explicitly says it is exhaustive or a clarification explicitly narrows the scope.

This directly protects cases such as `invalid Telegram user data` plus `missing unique Telegram user id`: the missing-id behavior cannot erase the broader invalid-data rejection.

Alternative considered: rely exclusively on the later EARS review to detect narrowing. Rejected because prevention in the owning conversion rule is lower blast and review remains defense in depth.

### 5. Finish EARS conversion with an in-place coverage sweep

Before finalization, the requirements-EARS skill inventories the populated values covered by its existing extraction map and checks their destination in the current EARS structure:

- functional, business-rule, permission, failure, state, and integration obligations map to independently testable EARS bullets;
- explicit prohibitions and non-goals appear in `Scope` or `## Overview -> Out of scope`, and also in an EARS bullet when they constrain runtime behavior;
- NFR facts become NFR blocks when they impose a product quality constraint;
- `### 12.5 Testing and quality -> required_test_levels` and applicable `special_quality_constraints` appear in the relevant `**Verification:**` fields or an NFR when they are themselves product obligations.

The sweep is an internal authoring check in the existing skill. It creates no traceability artifact and does not require a new template field. Short existing source-reference hints remain optional.

Alternative considered: extend the structural EARS validator into semantic BR-to-EARS comparison. Rejected because wording equivalence and obligation coverage are model judgments; deterministic tests instead protect the skill contract and representative outputs.

### 6. Collapse the duplicated rule surface onto the packaged skills

Applying decision 1 exposed the cost of the half-finished skills migration: the same ambiguity and prohibition rules had to be written into both `overmind/rules/task_to_br_rule.md` and the packaged skill. Four rule files survive out of the original set; the other twelve were deleted with their steps because the migration guide's delete list names the old script, helper, and tests but never the old rule.

Nothing binds the survivors at runtime. The installer stages only `_data/skills/**`, no substituter remains for their `<TARGET_BR_ARTIFACT>`-style placeholders, and `cli-project-init.test.ts` already asserts the context commands do **not** reference the "retired" blueprint and common-contract rule files. Each packaged skill is a superset of its rule: `task_to_br_rule.md` never gained the `source_refs` captured-source binding the skill carries, and the common-contract skill adds the `inferred` contract status the rule lacks.

All four are deleted. `AGENTS.md` and both READMEs are updated so "durable rule" means the inlined rule section of the packaged skill, and the ledger-terminal contract test pins the two skills that ship. The one rule-only nuance — `## Mission` ranking code quality, maintainability, and testability ahead of delivery speed — moves into the agents-md skill before its rule is removed.

Alternative considered: keep the rule files as upstream specs and add a rule/skill parity test per pair. Rejected because it adds four permanent test surfaces to protect content that no runtime reads.

### 7. Prove recovery with focused and measured regression evidence

Coordinator tests cover ambiguity scanning, source-locator parsing, pending versus answered ledger behavior, excluded sections, diagnostics, and unchanged exit codes. Installer tests assert the deployed skills and golden examples contain the owning rules. A focused semantic fixture covers broad-plus-specific behavior, explicit scope prohibitions, and required test-level preservation.

These fixtures assert authored content and shipped skill text. They establish that the rule is stated, demonstrated, and — for the deterministic backstop — enforced. They do not establish what a conversion run produces, so they do not stand in for the acceptance rerun.

The task-to-BR backstop was checked against the measured BR summary itself: running the new validator over the recorded UMSS `feature_br_summary.md` returns exit `1` with one grouped diagnostic for the trigger `simple`, naming seven fields. Four of them — `### 2.3 Explicitly stated in source -> stated_constraints`, `## 6. Functional Requirements -> FR-11`, `## 7. Business Rules and Decision Logic -> BR-6`, and `### Recovery and retry expectations -> retry_or_recovery_expectations` — carry the under-specified error-response wording that reached EARS, alongside `## 9. State and Data Expectations -> data_outputs_required`. The same artifact passed the previous gate. The remaining two, `### 3.1 Business goal -> problem_being_solved` and `### 12.2 Performance and reliability -> performance_requirements`, use the word descriptively rather than as an acceptance obligation; per-field confirmation keeps them distinguishable from the error-response question, and the trigger scope is left unchanged pending what the rerun shows about its operator cost.

The measured UMSS input is rerun as end-to-end acceptance evidence, against a workspace reinstalled with the updated skills. Success means the resulting flow asks for the under-specified error response and the final EARS artifact retains broad invalid-data behavior, explicit source prohibitions, and the backend-test obligation.

## Risks / Trade-offs

- [Risk] Lexical triggers can flag intentionally accepted wording. → Mitigation: scan only business-bearing fields and permit a matching answered ledger item as confirmation evidence.
- [Risk] The model can still miss a paraphrased prohibition. → Mitigation: make routing normative in the owning packaged task-to-BR skill, illustrate it in the golden example, and cover the measured failure in acceptance evidence.
- [Risk] Broad-plus-specific preservation can produce repetitive EARS blocks. → Mitigation: require distinct independently testable obligations; specificity refines within the same block when separate blocks add no test value.
- [Risk] Ledger source matching can drift with heading whitespace or case. → Mitigation: parse the existing locator into a typed value and normalize heading/field whitespace and case for comparison while preserving the artifact format.
- [Risk] The completeness sweep is model-owned rather than mechanically provable. → Mitigation: keep the checklist explicit, add representative contract fixtures, and use the UMSS rerun as behavioral acceptance evidence.
- [Risk] Deleting the rule files can drop content the packaged skill never absorbed. → Mitigation: compare each rule against its skill and validator before deletion, and move the one rule-only nuance into the owning skill; the files remain recoverable from git history.

## Migration Plan

1. Update the durable task-to-BR rule surface, deployed skill, and golden example.
2. Extend missing-data parsing and task-to-BR validation with the bounded ambiguity backstop and focused tests.
3. Update the requirements-EARS skill precedence and completeness sweep plus its golden example and contract tests.
4. Delete `overmind/rules/` and repoint `AGENTS.md`, both READMEs, and the ledger-terminal contract test at the packaged skills.
5. Run coordinator, installer, and repository verification suites.
6. Rerun the measured UMSS feature flow and compare the resulting `feature_br_summary.md`, `missing_br_data.md`, and `requirements_ears.md` against the acceptance points in this design.

The change has no stored-data or command migration. Rollback is a normal revert of the skill, validator/parser, examples, tests, and deleted rule files.

## Open Questions

None.
