## MODIFIED Requirements

### Requirement: Step 7 workflow SHALL emit typed planning-signal output in section 6
The Step 7 feature technical-requirements workflow SHALL write section 6 of `technical_requirements.md` using only the typed planning-signal contract introduced by this change: zero or more `### Planning Signal:` blocks, or the exact empty marker `- planning_signals: none` when no signal is needed. Once this contract is active, the workflow SHALL NOT emit loose `constraint_*` or `prep_*` entries in section 6.

#### Scenario: Generated technical requirements include a populated signal block
- **WHEN** the feature technical-requirements workflow determines that advisory cross-repo coordination intent should be preserved
- **THEN** the generated `technical_requirements.md` SHALL record that intent as one or more typed `### Planning Signal:` blocks in section 6
- **AND** SHALL NOT use legacy `constraint_*` or `prep_*` lines for that purpose

#### Scenario: Generated technical requirements include the explicit empty marker when no signal is needed
- **WHEN** the feature technical-requirements workflow does not identify a planning signal worth preserving
- **THEN** section 6 of the generated `technical_requirements.md` SHALL contain exactly `- planning_signals: none`

### Requirement: Feature technical requirements quality validation SHALL enforce the typed section 6 contract without over-triggering coordination
The repository SHALL provide a quality helper for `technical_requirements.md` that accepts the explicit section-6 empty marker, validates typed `planning_signal` blocks structurally including supported `signal_type`, and rejects legacy loose `constraint_*` / `prep_*` section-6 content after this change. The helper SHALL remain policy-free and SHALL NOT require a planning signal solely because the feature is multi-repo or because related contract-delta work exists.

#### Scenario: Empty marker passes helper validation
- **WHEN** section 6 contains `- planning_signals: none`
- **AND** the rest of `technical_requirements.md` is structurally valid
- **THEN** `check_feature_technical_requirements_quality.sh` SHALL exit successfully

#### Scenario: Unsupported signal type fails helper validation
- **WHEN** section 6 contains a typed planning-signal block whose `signal_type` is not `cross_repo_contract_lock`
- **THEN** `check_feature_technical_requirements_quality.sh` SHALL exit non-zero
- **AND** SHALL identify the unsupported `signal_type`

#### Scenario: Legacy loose section 6 content fails helper validation
- **WHEN** section 6 contains `constraint_*` or `prep_*` entries instead of typed planning-signal content or the explicit empty marker
- **THEN** `check_feature_technical_requirements_quality.sh` SHALL exit non-zero
- **AND** SHALL identify section 6 as using the retired loose-entry format

#### Scenario: Multi-repo scope alone does not require a planning signal
- **WHEN** a feature touches multiple active repo classes
- **AND** section 6 uses the explicit empty marker
- **THEN** `check_feature_technical_requirements_quality.sh` SHALL NOT fail solely because no planning signal block is present
