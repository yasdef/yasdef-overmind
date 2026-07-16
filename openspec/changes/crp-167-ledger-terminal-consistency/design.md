## Context

`missing_br_data.md` carries two different kinds of state. `## 1. Gate Status -> gate_result` records the result of the task-to-BR gate round that produced the ledger, while `## 7. Loop Decision -> unresolved_after_stop` summarizes the ledger's current unresolved state. The initial failed result is valuable audit history and remains valid after later clarification answers resolve every item.

The durable task-to-BR rule and packaged task-to-BR skill already prescribe `unresolved_after_stop: none` when the ledger has no raised gaps. The BR-clarification skill sets an answered item to `rised=true` and records its destination pointer, but does not set the terminal summary after the last answer. `readMissingBrData` exposes only whether the summary is filled, and `validateTaskToBr` consequently accepts an all-`rised=true` ledger whose summary still says `Pending...`. `validateBrClarification` invokes that base validator, so it also accepts the contradiction once its separate all-raised check passes.

CRP-164 changes the same task-to-BR parser and validator to enforce source-reference binding. CRP-167 follows it and extends those shared parsing utilities rather than introducing a parallel ledger parser. The runtime validator remains the existing TypeScript `gate task-to-br` command installed through the coordinator bundle.

## Goals / Non-Goals

**Goals:**

- Give an empty or fully answered ledger one deterministic terminal representation: `unresolved_after_stop: none`.
- Return recoverable exit `1` when the existing task-to-BR gate sees a stale terminal summary.
- Preserve every existing `gate_result` value as historical evidence when clarification updates the ledger.
- Keep the durable rule, packaged runtime skills, canonical step-completion documents, bundle, and installed skill copies aligned.

**Non-Goals:**

- Adding a new ledger artifact, field, command, validator, or CLI option.
- Reclassifying or rewriting historical gate rounds.
- Per-item correlation between `- answers:` destination lines and ledger items is not enforced today and remains out of scope; the current gate checks only whether at least one answer line is filled when any item is `rised=true`.
- Semantic review of answer content or changing the `rised` spelling and lifecycle.

## Decisions

### D1: Terminal state is derived from the existing ledger markers

The ledger is terminal when `## 3. Unresolved Items Ledger (Rised)` contains no `rised_item_N` entries, or when it contains entries and every entry is `rised=true`. In either terminal form, the trimmed `## 7. Loop Decision -> unresolved_after_stop` value must equal the literal lowercase token `none`.

An entry without a valid `rised` state remains an existing gate error and is not treated as terminal. When at least one entry is `rised=false`, the existing rule that `unresolved_after_stop` be filled continues to apply. The change does not add semantic parsing of the free-text pending summary.

The all-`rised=true` predicate uses the existing lifecycle contract: the BR-clarification skill may set `rised=true` only after the answer is written to `feature_br_summary.md` and an answer-destination pointer is recorded. Deterministic enforcement is weaker: the current gate checks only that at least one `## 6. Latest User Answers -> answers` line is filled when any item is `rised=true`. That check still runs independently, so terminal `none` cannot make a completely unfilled answers section pass, but this change does not prove one answer pointer per item.

Alternative considered: infer terminal state from `gate_result`. Rejected because that field describes an earlier gate round and is intentionally historical. Alternative considered: count answer pointers. Rejected because the current pointer format has no ledger-item identifier, and changing that traceability schema is a separate concern.

### D2: Extend the shared parser with the actual loop-decision value

`readMissingBrData` will expose the trimmed `unresolved_after_stop` value, in addition to its current filled-state data and parsed `risedItems`. `validateTaskToBr` will use that parsed value and the existing item states to apply the terminal predicate. CRP-167 must be implemented after CRP-164 and integrated with its parser changes so source-reference and ledger checks coexist in one validation path.

The gate remains read-only. A terminal ledger with a value other than `none`, including `[UNFILLED]` or stale `Waiting...` text, returns exit `1` and a diagnostic naming `missing_br_data.md`, `## 7. Loop Decision -> unresolved_after_stop`, and the required literal. Runtime failures and the existing missing-artifact classifications do not change.

Alternative considered: add a second ledger helper or post-processing command. Rejected because the existing task-to-BR gate already reads the artifact and BR clarification already composes that gate.

### D3: Update current state without rewriting historical gate evidence

The durable task-to-BR rule and both packaged skills will distinguish the two fields explicitly:

- after the final answer, update only the current terminal summary to `unresolved_after_stop: none` as part of the normal ledger write;
- preserve every pre-existing `gate_result` line and value exactly.

The validator neither requires `gate_result: passed` nor uses `gate_result` to determine terminal state. A regression fixture will retain `gate_result: failed` while all items are `rised=true` and the terminal summary is `none`; it must pass. This is intentional audit preservation, not legacy leniency.

The no-rewrite behavior is a model write contract. Deterministically proving field history would require a before/after session snapshot or a new semantic write guard, which this small gate-consistency change does not introduce. Installer contract tests will ensure both runner skill copies receive the preservation instruction.

### D4: Keep structure, behavior, and deployment responsibilities separated

`overmind/rules/task_to_br_rule.md` remains the concise durable behavior source. Its terminal invariant is mirrored in the inlined runtime rules of `overmind-task-to-br/SKILL.md` and `overmind-br-clarification/SKILL.md`, because the migrated runtime installs packaged skills rather than staging the legacy rule as a separate runtime input. `missing_br_data_TEMPLATE.md` remains unchanged because it already defines the field shape and templates do not own lifecycle behavior.

`overmind/templates/init_progress_definition_TEMPLATE.yaml` `Clarify BR and check EARS readiness` completion conditions and the matching feature loop in `overmind/init_progress_definition_sequence_diagram.md` will state the terminal ledger condition. `overmind/README.md` will carry only concise operational guidance. The coordinator build refreshes `packages/asdlc-coordinator/dist/overmind.js`, and installer tests prove fresh and update installations carry the changed skills into both `.codex/skills/` and `.claude/skills/`.

Alternative considered: update only the validator. Rejected because the model needs the repair rule that produces the state the deterministic gate expects, and the canonical step documents must describe the same completion condition.

## Risks / Trade-offs

- [Existing completed ledgers with stale `Waiting...` text begin failing] → Return recoverable exit `1`; repair only `unresolved_after_stop` to `none` and preserve `gate_result`.
- [CRP-164 and CRP-167 both change task-to-BR parsing and validation] → Land CRP-164 first and extend its shared helpers and tests rather than replacing its source-reference checks.
- [A skill could still violate the historical-field instruction] → Put the rule in both writing skills and verify installed payloads; stronger before/after enforcement is a separate write-guard change.
- [The future terminal gate chain revalidates an older inconsistent ledger] → Treat that failure as intended and recoverable; rerun BR clarification or repair the terminal summary without regenerating historical gate evidence.
- [Source and installed skill payloads drift] → Build the coordinator bundle and exercise installer fresh/update propagation for both runner directories.

## Migration Plan

1. Land CRP-164, then extend its task-to-BR parser and validator with terminal-summary parsing and the recoverable consistency check.
2. Update the durable task-to-BR rule, both packaged writing skills, canonical step documentation, and concise runtime documentation.
3. Add focused parser/gate/BR-clarification tests, including a passing terminal ledger with historical `gate_result: failed`, and refresh the bundled coordinator.
4. Verify fresh and update installs for Codex and Claude skill payloads, then run coordinator, installer, repository, and verification suites.
5. Repair older inconsistent ledgers by changing `unresolved_after_stop` to `none` after confirming every item is `rised=true`; leave `gate_result` untouched.

Rollback removes the terminal-value check and associated skill/documentation clauses. No artifact-schema rollback is required because the change uses existing fields.

## Open Questions

- None blocking.
