## Why

`missing_br_data.md` already uses `unresolved_after_stop: none` when no gaps are raised, but the current task-to-BR gate accepts the contradictory terminal state where every raised item is answered while `unresolved_after_stop` still says that clarification is pending. This leaves a completed clarification ledger machine-readably inconsistent and lets the stale state propagate into later validation.

## What Changes

- Extend the existing ledger convention so `## 7. Loop Decision -> unresolved_after_stop` is exactly `none` whenever every tracked `rised_item_N` is `rised=true`, while a pending summary remains valid when at least one item is still `rised=false`.
- Enforce the terminal rule in the existing task-to-BR gate as a recoverable exit `1` with an actionable `missing_br_data.md` diagnostic.
- Keep `## 1. Gate Status -> gate_result` as immutable historical evidence: neither the skill nor gate rewrites it, and a historical `gate_result: failed` does not prevent a terminally consistent ledger from passing.
- Update the durable task-to-BR rule, packaged task-to-BR and BR-clarification skill contracts, runtime documentation, and focused coordinator/installer tests without adding a command, validator, artifact, field, or CLI option.

## Capabilities

### New Capabilities

- `ledger-terminal-consistency`: Defines terminal-state consistency for the missing-business-data ledger, historical gate-result preservation, and task-to-BR gate enforcement.

### Modified Capabilities

- None.

## Impact

- Affects `missing_br_data.md` handling in the packaged task-to-BR and BR-clarification skills, the shared task-to-BR parser/types, and `packages/asdlc-coordinator/src/validate/task-to-br.ts`.
- Affects `overmind/rules/task_to_br_rule.md`, `overmind/README.md`, canonical feature-step completion documentation, coordinator tests, and installer propagation tests; the existing ledger template remains structural and unchanged.
- Existing ledgers whose items are all `rised=true` but whose terminal summary is stale will return exit `1` until `unresolved_after_stop` alone is repaired to `none`; their historical `gate_result` values remain unchanged.
- CRP-164 must land first so this change can build on its shared task-to-BR parsing work rather than creating a competing validator path.
