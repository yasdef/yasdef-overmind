## ADDED Requirements

### Requirement: Common-contract-definition artifact SHALL have canonical template and golden example
The repository SHALL include canonical structure and reference-style files for Step-2 output:
- `overmind/templates/common_contract_definition_TEMPLATE.md`
- `overmind/golden_examples/common_contract_definition_GOLDEN_EXAMPLE.md`

#### Scenario: Contract files exist for common contract definition
- **WHEN** contributors need output guidance for `common_contract_definition.md`
- **THEN** both the template and golden example SHALL exist under the canonical `overmind/templates/` and `overmind/golden_examples/` locations

### Requirement: Common-contract-definition quality gate SHALL validate generated artifact structure
The repository SHALL provide `overmind/scripts/helper/check_common_contract_definition_quality.sh` to validate `common_contract_definition.md` against the canonical artifact contract.

#### Scenario: Helper passes valid artifact
- **WHEN** the helper is run against a `common_contract_definition.md` that satisfies the canonical contract
- **THEN** it SHALL exit `0`

#### Scenario: Helper fails invalid artifact
- **WHEN** the helper is run against a `common_contract_definition.md` that violates the canonical contract
- **THEN** it SHALL exit `1`
- **AND** SHALL print a concrete quality failure reason

#### Scenario: Staged helper runs without repository git-root dependency
- **WHEN** helper is invoked from staged path `asdlc/.helper/check_common_contract_definition_quality.sh`
- **THEN** it SHALL resolve target paths against ASDLC root
- **AND** SHALL not require repository git-root lookup to execute

### Requirement: Implementation of this scaffold SHALL follow the repository phase-pattern skill
Work that implements this change SHALL use the local `overmind-new-pipeline-step` skill so template, golden example, rule, helper, init script, model setup, docs, and tests are updated as one aligned scaffold.

#### Scenario: Contributors implement the phase scaffold
- **WHEN** this change is implemented
- **THEN** the implementation flow SHALL use `overmind-new-pipeline-step`
- **AND** SHALL update the full phase scaffold surface instead of only a partial subset of files
