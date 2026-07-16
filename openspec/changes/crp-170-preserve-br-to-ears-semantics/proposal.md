## Why

The SKILL/TypeScript pipeline can produce structurally valid EARS requirements while losing business meaning already present in the source flow: ambiguity outside three preselected BR fields can bypass clarification, explicit prohibitions can be filed outside the EARS scope fields, and a specific example can replace a broader obligation. The measured UMSS regression shows that the existing stages need sharper semantic-preservation rules, not a new artifact or review phase.

## What Changes

- Generalize task-to-BR ambiguity externalization from the current three-field move list to every populated business-bearing BR field when an unresolved ambiguity materially affects acceptance or verification; reuse the existing `missing_br_data.md` ledger and clarification loop.
- Make the existing ambiguity rule enforceable by the task-to-BR gate for explicit configured ambiguity triggers in structured BR fields: unresolved values must move to `[UNFILLED]` with a pending ledger item, while a retained trigger is allowed only when a previously answered ledger item confirms that source field.
- Require every explicit source prohibition to appear in `### 2.3 Explicitly stated in source -> stated_constraints` or `### 5.2 Out of scope -> out_of_scope_items`; it may also appear in another relevant field, but only filing it elsewhere does not satisfy task-to-BR quality.
- Correct EARS conversion precedence so a specific rule, failure case, or example refines rather than replaces a broader requirement unless the BR summary explicitly says the specific case is exhaustive.
- Require a final EARS completeness sweep over the existing BR extraction map, including scope constraints and required test-level obligations, before completion.
- Add focused rule/skill, TypeScript gate, packaged-asset, and end-to-end UMSS regression coverage while retaining the existing artifacts, commands, phases, and operator decisions.
- Retire the four surviving `overmind/rules/*_rule.md` files so each migrated step has exactly one durable rule surface: the inlined rule section of its packaged skill.

## Capabilities

### New Capabilities

- `business-requirement-semantic-preservation`: Preserves acceptance-affecting ambiguity, explicit prohibitions, broad requirement coverage, scope constraints, and test obligations across the existing task-to-BR and EARS conversion stages.

### Modified Capabilities

<!-- None. openspec/specs/ contains no consolidated task-to-BR or EARS semantic-preservation capability. -->

## Impact

- `packages/installer/_data/skills/overmind-task-to-br/SKILL.md`: broaden ambiguity externalization and define deterministic placement for explicit prohibitions in the deployed runtime skill.
- `overmind/rules/`: deleted. The four remaining files duplicate their packaged skills, are bound by nothing at runtime, and had already drifted; `AGENTS.md`, both READMEs, and the ledger-terminal contract test move to the skill as the durable rule surface.
- `packages/asdlc-coordinator/src/validate/task-to-br.ts` and its parsing/tests: enforce configured ambiguity triggers across structured business fields using the existing ledger and stable `0`/`1`/`2` exit behavior.
- `packages/installer/_data/skills/overmind-requirements-ears/SKILL.md`: correct narrowing precedence and add the final extraction-map completeness sweep.
- Task-to-BR and requirements-EARS golden examples, installer propagation tests, and coordinator regression tests: demonstrate and protect the restored behavior.
- No new artifact, phase, command, CLI option, template field, or review-stage behavior.
