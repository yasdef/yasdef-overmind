## ADDED Requirements

### Requirement: EARS review receives both authoritative and raw business sources

The EARS-review context SHALL require and bind `feature_br_summary.md` as the authoritative clarified-decision source and `user_br_input.md` as the raw drift-detection source. Both sources SHALL be read-only, and the mutable surface SHALL remain limited to `requirements_ears.md` and `requirements_ears_review.md`.

#### Scenario: Context exposes both business sources

- **WHEN** EARS-review context is assembled for a feature containing `feature_br_summary.md`, `user_br_input.md`, and `requirements_ears.md`
- **THEN** it identifies the BR summary as the authoritative clarified-decision source and the user input as the raw drift-detection source
- **AND** it identifies only `requirements_ears.md` and `requirements_ears_review.md` as writable

#### Scenario: Required raw input is missing

- **WHEN** EARS-review context is requested for a feature without `user_br_input.md`
- **THEN** context assembly exits `2` with a diagnostic naming the missing raw business source

#### Scenario: Review attempts to modify a business source

- **WHEN** the EARS-review session modifies either `feature_br_summary.md` or `user_br_input.md`
- **THEN** step `5.1` fails its deterministic read-only guard and does not accept the session

#### Scenario: Requirements generation guard remains unchanged

- **WHEN** the step catalog entries for step `5` and step `5.1` are loaded
- **THEN** step `5` continues to protect only its `feature_br_summary.md` business source
- **AND** a separate step `5.1` guard protects both `feature_br_summary.md` and `user_br_input.md`

### Requirement: EARS review applies explicit source precedence

The EARS-review skill SHALL treat clarified decisions recorded in `feature_br_summary.md` as authoritative while using `user_br_input.md` to detect semantic drift. The skill SHALL NOT silently replace a clarified summary decision with raw wording; source discrepancies SHALL be handled through the review findings and operator-disposition loop.

#### Scenario: Raw source conflicts with a clarified summary decision

- **WHEN** raw input states one behavior and the BR summary records an explicit clarified decision that differs from it
- **THEN** the review preserves the BR summary as the current authority
- **AND** it records the raw-source discrepancy as a finding for auditable operator disposition instead of silently overwriting the summary decision

### Requirement: Narrowing relative to raw input is a mandatory finding

The EARS-review skill SHALL compare both `feature_br_summary.md` and `requirements_ears.md` with `user_br_input.md`. Every statement in the summary or EARS that is narrower than the corresponding raw obligation SHALL produce a material finding. Narrowing includes adding a condition, state, actor, or qualifier that permits behavior the raw source prohibits or reduces required coverage.

#### Scenario: ACTIVE qualifier weakens duplicate-account protection

- **WHEN** `user_br_input.md` prohibits duplicate accounts for the same user and account type without a status qualifier
- **AND** `feature_br_summary.md` or `requirements_ears.md` blocks duplicates only when the existing account is `ACTIVE`
- **THEN** the review records a mandatory finding that identifies the `ACTIVE` qualifier as an unsupported narrowing
- **AND** the finding cites the raw rule, the corresponding BR summary location, and the affected EARS requirement

#### Scenario: EARS preserves the full raw obligation

- **WHEN** the summary and EARS preserve the full scope of a raw business obligation without an added narrowing qualifier
- **THEN** the review does not create a raw-source narrowing finding for that obligation

### Requirement: Review ledgers preserve dual-source traceability

The EARS-review ledger SHALL record both source artifacts in document metadata. Every finding SHALL contain `source_br_summary_reference` and `source_user_br_input_reference`; findings not motivated by raw-source drift SHALL use the literal `none` as `source_user_br_input_reference`. The EARS-review validator SHALL report recoverable exit `1` problems when these required fields are missing or unfilled.

#### Scenario: Raw-narrowing finding is traceable through both sources

- **WHEN** a finding is created because a raw obligation was narrowed in the summary or EARS
- **THEN** the ledger records concrete `source_user_br_input_reference` and `source_br_summary_reference` values together with the affected requirement targets

#### Scenario: Existing ledger lacks dual-source fields

- **WHEN** the EARS-review gate validates a ledger without `source_user_br_input` metadata or without the required raw-source reference on a finding
- **THEN** it exits `1` and names each missing or unfilled field so the ledger can be repaired

#### Scenario: Future chain validation encounters a pre-dual-source ledger

- **WHEN** a future terminal artifact-chain check validates a previously completed feature whose EARS-review ledger lacks the dual-source fields
- **THEN** that ledger must be regenerated or upgraded through EARS review before the chain can pass
- **AND** the chain does not treat absent raw-source evidence as a legacy-compatible pass

### Requirement: Future Formal Requirements verification retains the raw-source backstop

`design_docs/phase_refactoring_light_version/02_phase_redesign_and_target_architecture.md` `### F2 — Formal Requirements` SHALL define its mandatory embedded verification pass with the same source contract: `feature_br_summary.md` is authoritative for clarified decisions, `user_br_input.md` is an independent drift detector, and narrowing relative to raw input is a mandatory finding.

#### Scenario: Formal Requirements target design is consulted

- **WHEN** the future light-version Formal Requirements phase is implemented from the target architecture document
- **THEN** its verification design includes both business sources and does not use `feature_br_summary.md` as the sole drift-audit input
