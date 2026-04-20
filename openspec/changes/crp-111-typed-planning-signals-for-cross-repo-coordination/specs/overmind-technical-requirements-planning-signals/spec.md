## ADDED Requirements

### Requirement: Technical requirements section 6 SHALL support optional typed planning-signal blocks
Section 6 of `technical_requirements.md` SHALL accept zero or more `### Planning Signal:` blocks. When no planning signal is needed, section 6 SHALL contain the exact line `- planning_signals: none` and SHALL remain valid.

#### Scenario: Section 6 accepts one valid planning signal block
- **WHEN** `technical_requirements.md` contains one `### Planning Signal:` block under section 6 with all required fields populated
- **THEN** the section SHALL be structurally valid without any `constraint_*` or `prep_*` entries

#### Scenario: Section 6 accepts the explicit empty-path marker
- **WHEN** no cross-repo planning signal is needed for the feature
- **THEN** section 6 SHALL contain exactly `- planning_signals: none`
- **AND** the quality helper SHALL accept the section as complete

#### Scenario: Section 6 accepts multiple planning signal blocks
- **WHEN** more than one coordination concern needs to be preserved
- **THEN** section 6 MAY contain multiple `### Planning Signal:` blocks
- **AND** each block SHALL remain independently identifiable by `signal_id`

### Requirement: cross_repo_contract_lock SHALL be the only supported planning-signal type in this change
Each section-6 `### Planning Signal:` block SHALL use `signal_type: cross_repo_contract_lock`. No other `signal_type` value is supported by this change. Each `cross_repo_contract_lock` block SHALL include the required fields `signal_id`, `signal_type`, `owner_repo`, `consumer_repos`, `required_artifact`, `must_precede`, `output_requirements`, and `source_evidence`. `owner_repo` and every repo named in `consumer_repos` SHALL belong to the active project classes for the artifact. `source_evidence` SHALL resolve to one or more local evidence tokens from the same artifact: `REQ-*`, `NFR-*`, or `comp/<component-slug>`, where `component-slug` is derived from the matching `### Component:` heading by lowercasing it and replacing non-alphanumeric runs with `-`.

#### Scenario: Valid cross_repo_contract_lock block passes structural validation
- **WHEN** section 6 contains a `cross_repo_contract_lock` signal with all required fields populated
- **AND** `owner_repo`, `consumer_repos`, and `source_evidence` all resolve correctly
- **THEN** the quality helper SHALL accept the block as structurally valid

#### Scenario: Unsupported signal type fails validation
- **WHEN** a planning signal uses any `signal_type` other than `cross_repo_contract_lock`
- **THEN** the quality helper SHALL exit non-zero
- **AND** SHALL identify the unsupported `signal_type` value

#### Scenario: Invalid repo ownership fails validation
- **WHEN** a planning signal names an `owner_repo` or `consumer_repos` value that is not one of the active project classes
- **THEN** the quality helper SHALL exit non-zero
- **AND** SHALL identify the invalid repo value

#### Scenario: Unresolved source evidence fails validation
- **WHEN** a planning signal contains a `source_evidence` token that does not resolve to a section 4 requirement ref or a section 5 component slug in the same artifact
- **THEN** the quality helper SHALL exit non-zero
- **AND** SHALL identify the unresolved evidence token

### Requirement: Planning signals SHALL remain advisory metadata rather than mandatory planning triggers
The technical-requirements contract, template, golden example, and quality helper SHALL treat planning signals as advisory coordination metadata only. The helper SHALL validate structure but SHALL NOT fail solely because a feature spans multiple repos, because `feature_contract_delta.md` indicates contract-delta work exists, or because section 6 uses the explicit empty marker. `must_precede` and `output_requirements` SHALL be recorded as declarative reviewable metadata and SHALL NOT by themselves create required slices or implementation-plan steps during the technical-requirements phase.

#### Scenario: Multi-repo feature without a signal still passes when the empty marker is used
- **WHEN** a feature spans multiple repos
- **AND** section 6 contains `- planning_signals: none`
- **THEN** the quality helper SHALL accept the artifact if the rest of the structure is valid

#### Scenario: Contract-delta work does not force a planning signal
- **WHEN** the surrounding feature workflow indicates contract-delta work exists
- **AND** section 6 contains `- planning_signals: none`
- **THEN** the technical-requirements quality helper SHALL NOT fail solely because no planning signal was emitted

#### Scenario: must_precede remains advisory metadata
- **WHEN** a planning signal contains a non-empty `must_precede` field
- **THEN** the technical-requirements quality helper SHALL treat that field as advisory section-6 content
- **AND** SHALL NOT require that a coordination slice or implementation-plan step already exist
