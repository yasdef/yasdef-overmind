## ADDED Requirements

### Requirement: Typed runner-config loader over the unchanged `.setup/models.md`

The system SHALL provide a `config/` loader that parses the **unchanged** `.setup/models.md` pipe-table into a typed, validated structure at load time, replacing the shell `load_model_config` awk (`02_responsibility_translation_map.md` row 6; decision 5 in `03_target_architecture.md ## Decisions`: format kept, awk replaced). The loader SHALL accept a models-file path and return a typed result mapping each declared phase to `{ command, model, args[] }`, where `args[]` is the ordered list of any extra fields after the model column. Parsing SHALL match the awk's row semantics: lines whose first non-whitespace character is `#` are comments and skipped; rows with fewer than three pipe-delimited fields are ignored; every field is trimmed of surrounding whitespace; the first matching row for a phase (case-insensitive on the phase key) wins. The `.setup/models.md` format SHALL NOT change and no workspace migration SHALL be required.

#### Scenario: Well-formed phase row parsed to typed config

- **WHEN** the loader reads a `.setup/models.md` containing `feature_contract_delta | codex | gpt-5.4 | --config | model_reasoning_effort='high'`
- **THEN** the result exposes the `feature_contract_delta` phase as `{ command: "codex", model: "gpt-5.4", args: ["--config", "model_reasoning_effort='high'"] }`

#### Scenario: Comments and short rows ignored

- **WHEN** the models file contains comment lines (starting with `#`) and a row with fewer than three fields
- **THEN** those lines are skipped and do not appear as phases in the typed result

### Requirement: Command validation against registered agent adapters

The loader SHALL validate each phase's `command` against the set of registered agent adapters — **only `codex`** initially — collapsing the shell's thirteen scattered `MODEL_CMD == codex` assertions into one rule (`03_target_architecture.md ## Runner config`). A phase whose command is not a registered adapter SHALL be reported as a load problem, not accepted.

#### Scenario: Non-codex command rejected as a load problem

- **WHEN** a phase row declares a command other than `codex` (e.g. `claude`)
- **THEN** the loader reports that phase as an invalid-command load problem and does not treat it as a runnable configuration

### Requirement: Load problems surface as Diagnostic values, never thrown

Consistent with the errors-as-values convention (`03_target_architecture.md ## Diagnostics`; `core-diagnostics` from `crp-145`), the loader SHALL NOT throw for data problems. Short and malformed rows are **skipped during table parsing** (per the parsing contract above) and do not by themselves produce a diagnostic; the diagnostic fires at **phase-resolution** time. A missing models file, a **requested phase that cannot be resolved to a valid `{ command, model }` row** (absent from the table, or present only as a short/malformed row that parsing skipped), or a resolved phase whose command is not a registered adapter (non-`codex`) SHALL each surface as a `Diagnostic` (`{ severity, source, reason, stepId? }`) in the loader's typed result, with `source` naming `.setup/models.md` and `reason` actionable at startup (naming the offending phase and the expected `phase | codex | <model> | <args...>` shape). Throwing is reserved for programmer errors.

#### Scenario: Missing models file degrades with a diagnostic

- **WHEN** the loader is given a path to a non-existent models file
- **THEN** it returns a typed result carrying a `Diagnostic` whose `source` is the models file and whose `reason` states the file was not found — and it does not throw

#### Scenario: Requested phase absent from the table degrades with a diagnostic

- **WHEN** a caller requests a phase that has no row in `.setup/models.md`
- **THEN** the result carries a `Diagnostic` naming the missing phase and the expected row shape, with no throw and no partial/undefined config silently returned

#### Scenario: Requested phase present only as a short row is unresolvable

- **WHEN** a caller requests a phase whose only row in `.setup/models.md` has fewer than three fields (so parsing skipped it)
- **THEN** the phase resolves as unresolvable and the result carries a `Diagnostic` (same as an absent phase) — the short row itself produced no separate diagnostic during parsing
