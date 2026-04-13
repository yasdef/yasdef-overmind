## MODIFIED Requirements

### Requirement: Product-artifact and scanner scripts SHALL support an optional `--feature_path` override
The scripts `overmind/scripts/init_br_scaffold.sh`, `overmind/scripts/init_scan_repo_for_br.sh`, `overmind/scripts/init_task_to_br.sh`, `overmind/scripts/init_user_br_clarification.sh`, and `overmind/scripts/init_br_check_ears_readiness.sh` SHALL accept an optional `--feature_path <path>` argument for selecting the artifact root used in that invocation.

#### Scenario: Script runs without explicit feature path override
- **WHEN** any covered script is invoked without `--feature_path`
- **THEN** it SHALL use `overmind/product` as the artifact root

#### Scenario: Script runs with explicit feature path override
- **WHEN** any covered script is invoked with `--feature_path overmind/product/custom-folder`
- **THEN** it SHALL use `overmind/product/custom-folder` as the artifact root for that invocation

### Requirement: Progress scanner SHALL resolve product checklist paths from invocation-selected feature root
`overmind/scripts/project_mgmt/init_progress_scanner.sh` SHALL require `--path <feature-folder>` selecting a feature folder under `asdlc/projects/<project-id>`, SHALL infer the owning project root from that path, and SHALL resolve logical product-root checklist targets against that selected feature folder without requiring YAML edits.

#### Scenario: Scanner fails when explicit feature path is omitted
- **WHEN** `init_progress_scanner.sh` runs without `--path`
- **THEN** it SHALL exit non-zero
- **AND** it SHALL print an error describing the required feature-level `--path` argument

#### Scenario: Scanner resolves product-root checklist targets to selected feature folder
- **WHEN** `init_progress_scanner.sh` runs with `--path <asdlc/projects/<project-id>/feature-1>` and checklist artifact entries target logical product root
- **THEN** the scanner SHALL resolve those product-root checklist targets under `<project>/feature-1` for that invocation

#### Scenario: Scanner keeps non-product path behavior unchanged
- **WHEN** `init_progress_scanner.sh` runs with `--path <feature-folder>` and evaluates checklist artifact entries that target non-product locations
- **THEN** the scanner SHALL preserve existing project-root default resolution and explicit `special_folder` behavior for those non-product entries

#### Scenario: Scanner feature selection is invocation-scoped
- **WHEN** `init_progress_scanner.sh` runs once with `--path <asdlc/projects/<project-id>/feature-1>` and later with `--path <asdlc/projects/<project-id>/feature-2>`
- **THEN** each run SHALL resolve product-root checklist targets only from the feature folder selected in that invocation

### Requirement: Regression coverage SHALL enforce default, override, and isolation contracts
Shell tests under `tests/ai_scripts/` SHALL validate default-path behavior, override-path behavior, repeated-run statelessness, and cross-script isolation for the covered product-artifact scripts. The scanner suite SHALL validate required `--path` behavior, project-root inference, invalid-path failure modes, and selected-feature checklist resolution.

#### Scenario: Contract test suite validates feature path behavior for product-artifact scripts
- **WHEN** `bash tests/ai_scripts/crp-068/feature_path_override_contract_tests.sh` is run from repository root
- **THEN** it SHALL pass and confirm default, override, stateless repeated-run, and cross-script isolation behavior for product-artifact scripts

#### Scenario: Progress scanner suite validates feature-level path entrypoint behavior
- **WHEN** `bash tests/ai_scripts/init_progress_scanner_tests.sh` is run from repository root
- **THEN** it SHALL include coverage confirming scanner `--path` validation, project inference, and feature-selected checklist resolution behavior
