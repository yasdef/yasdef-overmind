## ADDED Requirements

### Requirement: Missing-business-data ledger has a deterministic terminal summary

The task-to-BR and BR-clarification rules SHALL treat `missing_br_data.md` as terminal when `## 3. Unresolved Items Ledger (Rised)` is empty or when every tracked `rised_item_N` is `rised=true`. In either terminal state, they SHALL set `## 7. Loop Decision -> unresolved_after_stop` to the exact literal `none`. When at least one item remains `rised=false`, the existing filled pending-summary behavior SHALL remain valid.

#### Scenario: No raised gaps use the existing terminal token

- **WHEN** `## 3. Unresolved Items Ledger (Rised)` contains no `rised_item_N` entries
- **THEN** `## 7. Loop Decision -> unresolved_after_stop` is exactly `none`

#### Scenario: Final answered item closes the ledger

- **WHEN** the BR-clarification skill records the final answer in `feature_br_summary.md`
- **AND** sets the final remaining `rised_item_N` to `rised=true`
- **THEN** it sets `## 7. Loop Decision -> unresolved_after_stop` to exactly `none` before rerunning the gate

#### Scenario: Pending ledger retains a pending summary

- **WHEN** at least one tracked `rised_item_N` remains `rised=false`
- **THEN** a filled `unresolved_after_stop` summary continues to represent the unresolved state

### Requirement: Historical gate results remain immutable during clarification

The task-to-BR and BR-clarification skills SHALL preserve every pre-existing `## 1. Gate Status -> gate_result` value exactly when updating `missing_br_data.md`. The task-to-BR gate SHALL treat `gate_result` as historical evidence and SHALL NOT require it to equal `passed` for a terminally consistent ledger.

#### Scenario: Answered ledger preserves its initial failed result

- **WHEN** an existing ledger has `gate_result: failed`
- **AND** clarification changes every tracked item to `rised=true`
- **THEN** the skill leaves `gate_result: failed` unchanged
- **AND** changes the current `unresolved_after_stop` summary to `none`

#### Scenario: Historical failure does not block a consistent terminal ledger

- **WHEN** every tracked item is `rised=true`
- **AND** `unresolved_after_stop` is `none`
- **AND** the historical `gate_result` remains `failed`
- **THEN** the historical value contributes no task-to-BR gate problem

### Requirement: Task-to-BR gate enforces terminal ledger consistency

The task-to-BR gate SHALL parse the trimmed `## 7. Loop Decision -> unresolved_after_stop` value and SHALL require the exact literal `none` when the ledger is empty or every parsed item is `rised=true`. A different, missing, empty, or unfilled value in either terminal state SHALL produce recoverable exit `1` with an actionable diagnostic naming `missing_br_data.md`, the full field path, and the required literal. The gate SHALL retain its existing exit classifications for all other artifact and runtime failures.

#### Scenario: Fully answered ledger with none passes terminal validation

- **WHEN** one or more ledger items exist and every item is `rised=true`
- **AND** `## 7. Loop Decision -> unresolved_after_stop` is `none`
- **AND** all other task-to-BR checks pass
- **THEN** the task-to-BR gate exits `0`

#### Scenario: Fully answered ledger with stale pending text fails recoverably

- **WHEN** one or more ledger items exist and every item is `rised=true`
- **AND** `unresolved_after_stop` still contains `Waiting for user input.`
- **THEN** the task-to-BR gate exits `1`
- **AND** its diagnostic identifies `missing_br_data.md -> ## 7. Loop Decision -> unresolved_after_stop` and requires `none`

#### Scenario: Empty ledger with unfilled terminal summary fails recoverably

- **WHEN** the ledger contains no `rised_item_N` entries
- **AND** `unresolved_after_stop` is `[UNFILLED]`
- **THEN** the task-to-BR gate exits `1` with the terminal-summary diagnostic

#### Scenario: Pending item does not trigger the terminal-none check

- **WHEN** at least one valid ledger item is `rised=false`
- **AND** `unresolved_after_stop` contains a filled pending summary
- **THEN** terminal-summary validation contributes no problem
- **AND** BR-clarification readiness remains responsible for blocking completion while the item is unresolved

#### Scenario: BR clarification composes terminal consistency

- **WHEN** the BR-clarification gate evaluates an all-`rised=true` ledger whose `unresolved_after_stop` value is stale
- **THEN** it propagates the task-to-BR base-gate exit `1` and diagnostic
- **AND** it does not report BR clarification complete

### Requirement: Installed skills carry the terminal-ledger contract

The Overmind installer SHALL deploy task-to-BR and BR-clarification skills containing the terminal-summary and historical-`gate_result` preservation rules to both supported runner skill directories on fresh install and update.

#### Scenario: Fresh install exposes the consistency rule

- **WHEN** an ASDLC workspace is initialized from the updated package
- **THEN** both `.codex/skills/` and `.claude/skills/` contain task-to-BR and BR-clarification skills with the terminal-summary rule
- **AND** both writing skills instruct the runner to preserve existing `gate_result` values

#### Scenario: Update replaces stale skill contracts

- **WHEN** an existing ASDLC workspace is updated through the installer
- **THEN** stale installed task-to-BR and BR-clarification skill copies are replaced with the packaged terminal-consistency contract
