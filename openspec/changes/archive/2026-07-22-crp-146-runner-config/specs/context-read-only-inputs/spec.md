## ADDED Requirements

### Requirement: ContextResult exposes read-only inputs as a typed field

The system SHALL extend `ContextResult` (`types/`) with an optional structured `readOnlyInputs: string[]` carrying the read-only input paths the context builder computed, so consumers read them as typed data rather than by scraping stdout (`02_responsibility_translation_map.md` row 10: "reads `readOnlyInputs` from the typed result. Zero output parsing"; design D5). This replaces the shell's `sed -n 's/^- read_only_input: //p'` extraction from context stdout. The field is the authoritative typed source for the Slice 2 `fromContext` guards (`session-guards`) and the executor (`step-executor`); those consumers SHALL read `ContextResult.readOnlyInputs` and SHALL NOT parse the `- read_only_input:` text lines.

#### Scenario: fromContext builder result carries typed read-only inputs

- **WHEN** a `fromContext` context builder (e.g. `contract-delta`) runs successfully for a feature
- **THEN** its `ContextResult` carries a `readOnlyInputs` array listing the read-only input paths (feature BR summary, EARS, common contract baseline, and any pending sibling deltas), as typed data

#### Scenario: Consumers read the typed field, not the text

- **WHEN** the `fromContext` guard or the executor needs the protected read-only set
- **THEN** it reads `ContextResult.readOnlyInputs` directly and performs no stdout/text parsing to obtain those paths

### Requirement: The extension is additive — existing context text is byte-unchanged

The extension SHALL be **strictly additive**: `ContextResult.text` and its rendered `- read_only_input: <path>` lines SHALL remain byte-for-byte unchanged, so the standalone `overmind context` CLI verb and any other existing consumer are unaffected. The new `readOnlyInputs` field SHALL be derived from the **same** paths the text lines render, so the typed field and the text never diverge. `readOnlyInputs` SHALL be populated in the `fromContext` builders (contract-delta, surface-map, technical-requirements, implementation-slices, prerequisite-gaps, implementation-plan, plan-semantic-review, surface-map-enrich); builders that carry no read-only inputs MAY leave the field absent or empty.

#### Scenario: Context text output is unchanged for a touched builder

- **WHEN** a `fromContext` builder that now populates `readOnlyInputs` is rendered to text
- **THEN** the `.text` output — including its `## Read-Only Inputs` block and `- read_only_input:` lines — is byte-identical to the pre-change output

#### Scenario: Typed field matches the rendered text lines

- **WHEN** a `fromContext` builder's `ContextResult` is inspected
- **THEN** its `readOnlyInputs` set equals the set of paths its `- read_only_input:` text lines render (no divergence between the field and the text)
