## ADDED Requirements

### Requirement: EARS review performs ordered capture and translation checks
Step 5.1 SHALL perform a raw capture-fidelity comparison before a clarified-BR translation-fidelity comparison in the existing review session.

#### Scenario: Raw obligation is lost before EARS
- **WHEN** `user_br_input.md` contains a material obligation or guard that is absent or weakened in both `feature_br_summary.md` and `requirements_ears.md`
- **THEN** step 5.1 SHALL record a material raw-drift finding before it can declare `no_findings: true`

#### Scenario: EARS differs from clarified BR
- **WHEN** `feature_br_summary.md` records expected behavior and `requirements_ears.md` omits, changes, or adds behavior relative to that summary
- **THEN** step 5.1 SHALL record a translation-fidelity finding

#### Scenario: One issue crosses both comparisons
- **WHEN** the same semantic drift is visible from raw to BR and from BR to EARS
- **THEN** step 5.1 SHALL create one finding containing the applicable raw, BR, and EARS evidence rather than duplicate findings

### Requirement: Raw fidelity covers all material drift directions
The raw capture-fidelity comparison SHALL detect lost obligations, removed guards, unsupported broadening, unsupported narrowing, actor or state changes, contradictions, and invented behavior.

#### Scenario: Guard is removed
- **WHEN** raw input limits account resolution to a registered user with an OFFCHAIN_POINTS account and the BR or EARS removes that account precondition
- **THEN** step 5.1 SHALL report unsupported broadening caused by the removed guard

#### Scenario: Qualifier narrows a prohibition
- **WHEN** raw input prohibits duplicate same-type accounts regardless of status and the BR or EARS applies the prohibition only to an ACTIVE account
- **THEN** step 5.1 SHALL report unsupported narrowing caused by the added qualifier

#### Scenario: Behavior is invented
- **WHEN** the BR or EARS introduces a material outcome with no raw basis and no explicit clarification evidence
- **THEN** step 5.1 SHALL report the unsupported addition for operator disposition

### Requirement: Review context presents raw and clarification evidence
The EARS-review context SHALL bind the existing read-only `user_br_input.md`, `feature_br_summary.md`, and `missing_br_data.md` sources and SHALL inline the captured raw story and clarification-ledger contents in the assembled model context.

#### Scenario: All review sources exist
- **WHEN** EARS-review context is assembled for a feature with raw input, BR summary, clarification ledger, and EARS artifacts
- **THEN** the context SHALL emit their authoritative paths and SHALL include dedicated inlined raw-story and clarification-evidence sections

#### Scenario: Clarification ledger is missing
- **WHEN** `missing_br_data.md` is absent while EARS-review context is assembled
- **THEN** context assembly SHALL stop with the existing blocking context-error behavior before review begins

### Requirement: Clarified decisions remain authoritative but reviewable
Step 5.1 SHALL treat an operator decision as explicit clarification evidence when an answered `rised=true` item in `missing_br_data.md` maps through its `source=` locator to the resolved answer in `feature_br_summary.md`, while still surfacing any discrepancy with raw input.

#### Scenario: Clarification intentionally changes raw wording
- **WHEN** an answered clarification-ledger item maps to a BR answer that changes or narrows raw behavior
- **THEN** step 5.1 SHALL cite the discrepancy, recommend confirmation or retention of the clarified decision, and SHALL NOT silently restore the raw wording

#### Scenario: Summary change has no clarification evidence
- **WHEN** the summary differs materially from raw input without a corresponding answered ledger item mapped to that BR field
- **THEN** step 5.1 SHALL treat the difference as raw-source drift rather than assume it was intentional

### Requirement: Finding citations reflect their actual source
Every raw-drift finding SHALL cite a concrete `source_user_br_input_reference`; `source_user_br_input_reference: none` SHALL be used only for a finding caused solely by BR-to-EARS translation of an explicit clarified decision.

#### Scenario: Finding originates in raw drift
- **WHEN** a finding identifies loss, broadening, narrowing, contradiction, or invention relative to raw input
- **THEN** the finding SHALL contain a concrete raw reference and the corresponding BR and EARS targets

#### Scenario: Finding originates only in clarified-BR translation
- **WHEN** raw input has no corresponding obligation and EARS mistranslates a BR decision evidenced by an answered clarification-ledger item mapped to that BR field
- **THEN** the finding MAY use `source_user_br_input_reference: none` and SHALL cite the clarified BR location

### Requirement: No-findings completion requires both semantic comparisons
Step 5.1 SHALL emit `no_findings: true` only after completing both raw capture-fidelity and clarified-BR translation-fidelity comparisons without finding a material discrepancy.

#### Scenario: BR and EARS agree after raw loss
- **WHEN** BR and EARS are mutually consistent but both omit or broaden a material raw obligation
- **THEN** step 5.1 SHALL create a raw-drift finding and SHALL NOT emit `no_findings: true`

#### Scenario: Both comparisons are clean
- **WHEN** raw obligations are faithfully captured or explicitly clarified and EARS faithfully translates the resulting BR
- **THEN** step 5.1 MAY complete with `no_findings: true`

### Requirement: Behavioral acceptance proves recovery on measured artifacts
The change SHALL remain behaviorally incomplete until one complete acceptance batch of three installed review runs recovers the verified measured raw-loss defect in every run without reporting the template-conformant EARS system-name construction as an actor defect.

#### Scenario: Measured v3 review run
- **WHEN** the candidate skill reviews clean frozen copies of the measured v3 raw input, BR summary, clarification ledger, and pre-review EARS artifact
- **THEN** it SHALL find the removed OFFCHAIN_POINTS account-resolution precondition with concrete raw provenance

#### Scenario: EARS system name describes frontend behavior
- **WHEN** a conformant EARS criterion uses `THE User Management Service System` in the template's single system-name slot and states that counts are displayed in the administration website
- **THEN** step 5.1 SHALL NOT report an actor mismatch solely from that required grammatical construction

#### Scenario: Measured pre-review EARS fixture is frozen
- **WHEN** the measured v3 review ledger contains `no_findings: true` and no EARS changes were applied
- **THEN** the current measured v3 `requirements_ears.md` SHALL be treated as the pre-review state and SHALL be frozen with its raw, BR, and clarification-ledger inputs before CRP-172 can alter the BR baseline

#### Scenario: Initial acceptance batch has a partial result
- **WHEN** any run in the initial three-run batch misses the required raw-drift finding
- **THEN** the batch SHALL fail, the missed comparison obligation SHALL drive a skill, context, or example correction, contract verification SHALL be rerun, and one fresh three-run batch SHALL replace rather than extend the failed batch

#### Scenario: Replacement acceptance batch still has a partial result
- **WHEN** any run in the replacement three-run batch misses the required raw-drift finding
- **THEN** behavioral acceptance SHALL remain incomplete and the owner SHALL explicitly decide the next disposition before the acceptance rule is changed or another batch is run

#### Scenario: Structural tests pass without behavioral evidence
- **WHEN** skill-contract, installer, and ledger-validator tests pass but the repeated measured review runs have not completed
- **THEN** the behavioral acceptance task SHALL remain incomplete
