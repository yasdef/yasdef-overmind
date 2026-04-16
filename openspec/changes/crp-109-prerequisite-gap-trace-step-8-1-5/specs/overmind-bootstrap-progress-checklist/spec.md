## ADDED Requirements

### Requirement: Step 8.1.5 in progress definition template and scanner
The progress-definition template `init_progress_definition_TEMPLATE.yaml` SHALL include a `step_number: 8.1.5` block between the `8.1` and `8.2` entries, and `init_progress_scanner.sh` SHALL recognize `prerequisite_gaps.md` as the completion artifact for Step `8.1.5`.

#### Scenario: Template contains 8.1.5 step block
- **WHEN** a new `init_progress_definition.yaml` is scaffolded from the template
- **THEN** the resulting file SHALL include a step entry for `8.1.5` with `step_name: "Run Prerequisite Gap Trace"` positioned between the `8.1` and `8.2` entries

#### Scenario: Scanner detects Step 8.1.5 as complete when artifact is present
- **WHEN** `init_progress_scanner.sh` scans a feature path that contains `prerequisite_gaps.md`
- **THEN** the scanner SHALL report Step `8.1.5` as finished

#### Scenario: Scanner detects Step 8.1.5 as incomplete when artifact is absent
- **WHEN** `init_progress_scanner.sh` scans a feature path that does not contain `prerequisite_gaps.md`
- **THEN** the scanner SHALL report Step `8.1.5` as not finished and SHALL identify it as the `next step` when Steps `8.1` is complete and `8.2` has not started

#### Scenario: Step 8.1.5 required before 8.2 in scanner ordering
- **WHEN** `init_progress_scanner.sh` evaluates the next required step for a feature where `implementation_slices.md` is present but `prerequisite_gaps.md` is absent
- **THEN** the scanner SHALL output `next step: 8.1.5` rather than `8.2`
