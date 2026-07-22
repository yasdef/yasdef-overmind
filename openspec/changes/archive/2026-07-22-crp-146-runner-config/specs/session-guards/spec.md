## ADDED Requirements

### Requirement: One snapshot/verify guard module for the readOnlyGuards union

The system SHALL provide **one** guard module in `runner/` implementing the full typed `readOnlyGuards` union declared on the step catalog (`sequencing/step-catalog.ts` `ReadOnlyGuard`), replacing the hand-copied `mktemp`/`cp`/`cmp -s` blocks and 7.1's bespoke exists/absent handling (`02_responsibility_translation_map.md` row 11; `03_target_architecture.md ## Key contracts`). The module SHALL provide a snapshot step (before the session) and a verify step (after the session) driven by catalog data, and SHALL be applied uniformly — 7.1 is a catalog entry, not an executor branch. Guard violations SHALL be reported as `Diagnostic` values naming the offending path and the violated mode.

The three modes SHALL behave as:
- **`fromContext`** — the protected set is the read-only inputs reported by the context result (the `agent-runner`/executor supplies them); each protected file is snapshotted and MUST be byte-identical after the session, matching the shell's per-file `cmp -s` loop (steps 6, 7, 8, 8.x).
- **`mustExistUnchanged`** — each named file MUST exist before the session and be byte-identical after; a missing-before file or a modified-after file is a violation (steps 5/5.1 on `feature_br_summary.md`).
- **`preserveExistence`** — each named file is unchanged if present, and if absent before MUST stay absent after; the session MUST NOT create, delete, or replace it (step 7.1 on `external_sources.yaml` and `init_progress_definition.yaml`) — the only step with this mode.

#### Scenario: fromContext protected file modified is a violation

- **WHEN** a `fromContext` step's session modifies one of the read-only inputs the context reported
- **THEN** verify reports a `Diagnostic` naming that file as a read-only input that must not be modified

#### Scenario: mustExistUnchanged file altered is a violation

- **WHEN** a step declaring `mustExistUnchanged` on `feature_br_summary.md` runs a session that changes that file
- **THEN** verify reports a violation for `feature_br_summary.md`

#### Scenario: preserveExistence — present-unchanged passes, present-modified fails

- **WHEN** a `preserveExistence` guarded file exists before the session and is byte-identical afterward
- **THEN** verify passes for that file; **and WHEN** instead the file is modified during the session, verify reports a violation

#### Scenario: preserveExistence — absent stays absent passes, absent-created fails

- **WHEN** a `preserveExistence` guarded file is absent before the session and remains absent afterward
- **THEN** verify passes for that file; **and WHEN** instead the session creates it, verify reports a create violation

### Requirement: requiredOutputs assertion with empty-list-is-legal semantics

After a successful session the guard module SHALL assert that each file in the session action's `requiredOutputs` exists, reporting a `Diagnostic` for any missing required output (parity with the shell's `[[ -f ]]` post-run checks). An **empty** `requiredOutputs` list SHALL be legal and SHALL assert nothing — it is not an error — supporting steps that mutate existing artifacts in place with nothing new to produce (step 7.1 mutates surface maps and asserts no fresh output).

#### Scenario: Missing required output is reported

- **WHEN** a session declares `requiredOutputs: ["feature_contract_delta.md"]` and the file is absent after a successful run
- **THEN** the module reports a `Diagnostic` that the required output was not produced

#### Scenario: Empty requiredOutputs asserts nothing

- **WHEN** step 7.1's session (with `requiredOutputs: []`) completes
- **THEN** the module performs no output-existence assertion and reports no diagnostic for missing outputs
