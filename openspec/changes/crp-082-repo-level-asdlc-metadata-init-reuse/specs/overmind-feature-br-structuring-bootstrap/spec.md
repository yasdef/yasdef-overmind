## REMOVED Requirements

### Requirement: BRS initializer SHALL capture project type via strict numeric chooser
**Reason**: Project type selection becomes a repo-level initialization concern owned by `overmind/scripts/init_asdlc_in_this_repo.sh`.
**Migration**: Run `overmind/scripts/init_asdlc_in_this_repo.sh` before `overmind/scripts/init_br_scaffold.sh` so canonical repo metadata exists in `overmind/init_progress_definition.yaml`.

## ADDED Requirements

### Requirement: BRS initializer SHALL reuse canonical repo project type metadata
`overmind/scripts/init_br_scaffold.sh` SHALL read `meta_info.project_type_code` and `meta_info.project_type_label` from `overmind/init_progress_definition.yaml` and SHALL write those values into the resolved BR summary file instead of asking the user to choose project type interactively.

#### Scenario: Valid repo metadata is copied into BR summary
- **WHEN** `meta_info.project_type_code` and `meta_info.project_type_label` are present and valid
- **THEN** `overmind/scripts/init_br_scaffold.sh` SHALL write those exact values into the resolved `feature_br_summary.md`
- **AND** SHALL not prompt the user to choose project type

#### Scenario: Missing repo metadata blocks BR scaffold initialization
- **WHEN** `meta_info.project_type_code` or `meta_info.project_type_label` is missing or invalid
- **THEN** `overmind/scripts/init_br_scaffold.sh` SHALL exit non-zero
- **AND** SHALL instruct the user to run `overmind/scripts/init_asdlc_in_this_repo.sh`

## MODIFIED Requirements

### Requirement: Initializer behavior SHALL be regression-tested under canonical script tests location
Tests for BRS initialization SHALL exist under `tests/ai_scripts/` and SHALL validate repo-metadata reuse, fail-fast behavior when canonical repo metadata is missing or invalid, deterministic structure, skeleton-only behavior, and one-line FR/BR section contract.

#### Scenario: Script tests execute from repository root
- **WHEN** the BRS initializer and related task-to-BR helper suites run
- **THEN** they SHALL verify canonical repo project-type metadata is reused without a chooser prompt
- **AND** SHALL verify fail-fast guidance when repo metadata is missing or invalid
- **AND** SHALL verify deterministic skeleton output, no Epic/Story prefill, and one-line FR/BR contract expectations
