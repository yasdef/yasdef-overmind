## 1. Task-to-BR semantic rules

- [x] 1.1 Update the durable task-to-BR rule surface so ambiguity externalization applies to every acceptance-affecting populated business field, defines the bounded field scope and unresolved-versus-confirmed lifecycle, and requires explicit source prohibitions in `### 2.3 Explicitly stated in source -> stated_constraints` or `### 5.2 Out of scope -> out_of_scope_items`. Implemented first in `overmind/rules/task_to_br_rule.md`; superseded by the packaged skill when section 5 retired that file.
- [x] 1.2 Mirror the durable ambiguity and prohibition-routing rules in `packages/installer/_data/skills/overmind-task-to-br/SKILL.md` without changing the existing invocation, ledger, artifact, or gate workflow.
- [x] 1.3 Update the task-to-BR golden examples to demonstrate an ambiguity raised from a field outside the former three-field list and an explicit prohibition routed to a scope-bearing field.

## 2. Deterministic task-to-BR ambiguity backstop

- [x] 2.1 Extend the missing-business-data parser and `RisedItem` type to expose the existing `source=<section> -> <field>` locator with normalized comparison semantics; add parser tests for valid, absent, and whitespace/case variants.
- [x] 2.2 Extend `packages/asdlc-coordinator/src/validate/task-to-br.ts` to scan the design-defined business fields for the durable rule's closed ambiguity triggers and return an actionable recoverable diagnostic when a trigger remains without a matching answered ledger item.
- [x] 2.3 Add task-to-BR validator tests for ambiguity in `rejection_cases`, unresolved externalization, matching `rised=true` confirmation, nonmatching and `rised=false` items, excluded metadata/repo/artifact sections, whole-word/phrase matching, and unchanged `0`/`1`/`2` behavior.
- [x] 2.4 Group ambiguity diagnostics by trigger so a fact restated across several BR fields is one problem, and let one ledger item name every field its answer covers through a comma-separated `source=` locator list; keep confirmation per field so the same trigger word in an unrelated field stays reported. Update the parser, `RisedItem`, rule text, golden example, spec, and tests.
- [x] 2.5 Propagate the multi-field `source=` locator contract to the BR-clarification skill and the missing-data templates, requiring an answer to reach every field its item names before `rised=true`, and pin the shared contract with a cross-skill test.

## 3. Requirements-EARS semantic preservation

- [x] 3.1 Replace unconditional narrowing guidance in `packages/installer/_data/skills/overmind-requirements-ears/SKILL.md` with the broad-plus-specific precedence rule and explicit exhaustive-clarification exception.
- [x] 3.2 Add the final in-place extraction-map coverage sweep to the requirements-EARS skill, covering EARS obligations, scope/out-of-scope placement, NFRs, and `### 12.5 Testing and quality -> required_test_levels` / `special_quality_constraints` placement in existing verification or NFR fields.
- [x] 3.3 Update the requirements-EARS golden example with representative broad-plus-specific behavior, an explicit scope prohibition, and a required test-level obligation while preserving the current template structure.

## 4. Propagation and regression coverage

- [x] 4.1 Extend installer asset tests to assert both runner installations receive the updated task-to-BR and requirements-EARS skills and examples, including the owning semantic-preservation rules.
- [x] 4.2 Add focused semantic contract fixtures covering the measured regression shapes: ambiguity outside the former allowlist, prohibition misfiled only as configuration, broad invalid-data behavior plus a specific missing-id case, and backend automated-test verification.
- [x] 4.3 Run `npm test`, `npm run verify`, `npm run test --workspace overmind-installer`, and `npm run test --workspace asdlc-coordinator`; repair only failures caused by this change.

## 5. Single durable rule surface

- [x] 5.1 Move the `## Mission` quality-ranking requirement from `overmind/rules/project_agents_md_claude_md_rule.md` into `packages/installer/_data/skills/overmind-agents-md/SKILL.md` so no rule-only content is lost.
- [x] 5.2 Delete `overmind/rules/`, whose four remaining files duplicate their packaged skills and are bound by nothing at runtime.
- [x] 5.3 Repoint `packages/asdlc-coordinator/test/ledger-terminal-contract.test.ts` at the packaged task-to-BR and BR-clarification skills only.
- [x] 5.4 Update `AGENTS.md`, root `README.md`, and `overmind/README.md` so the durable rule surface is the inlined rule section of the packaged skill.
- [x] 5.5 Rerun `npm run verify`; repair only failures caused by this change.

## 6. End-to-end acceptance

Precondition: the target workspace still has the pre-change skills installed, so reinstall them (`overmind init` update mode) before the rerun. The contract fixtures in section 4 assert shipped skill text and executed gate behavior; they are not a substitute for this rerun.

- [ ] 6.1 Rerun the measured UMSS source through the current Task-to-BR, clarification, and requirements-EARS stages, providing the previously established error-message answer through the existing clarification loop.
- [ ] 6.2 Confirm the rerun raises the under-specified error response from its original business field and the final `requirements_ears.md` retains the general invalid-Telegram-data rejection, the missing-id case, explicit market/ledger/forecasting/blockchain/complex-analytics exclusions, and the backend-test obligation.
