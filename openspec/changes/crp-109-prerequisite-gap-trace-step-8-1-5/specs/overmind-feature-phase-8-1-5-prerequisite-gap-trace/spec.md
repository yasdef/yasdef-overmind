## ADDED Requirements

### Requirement: Step 8.2 position and ordering
The feature pipeline SHALL include a required Step `8.2` positioned after Step `8.1` (implementation slices) and before Step `8.3` (implementation plan); Step `8.3` SHALL NOT start until Step `8.2` is complete.

#### Scenario: Step 8.2 runs after slices, before plan
- **WHEN** the e2e orchestrator advances past Step `8.1`
- **THEN** the orchestrator SHALL invoke Step `8.2` next and SHALL NOT invoke Step `8.3` until `check_prerequisite_gaps_quality.sh` exits with status 0

#### Scenario: Skipping Step 8.2 is not permitted
- **WHEN** the orchestrator evaluates whether Step `8.2` may be skipped
- **THEN** the orchestrator SHALL treat Step `8.2` as a non-optional required step and SHALL refuse to advance to `8.3` without it

#### Scenario: Resume flag accepts 8.2 as a step identifier
- **WHEN** the orchestrator is invoked with `--resume 8.2`
- **THEN** the orchestrator SHALL resume from Step `8.2` and SHALL accept `prerequisite-gap-trace` and `prerequisite-gaps` as alias identifiers for this step

### Requirement: prerequisite_gaps.md artifact production
The generator script `feature_prerequisite_gaps.sh` SHALL produce `prerequisite_gaps.md` at the feature path by reading `requirements_ears.md`, `technical_requirements.md`, and `implementation_slices.md` as inputs.

#### Scenario: Artifact produced from required inputs
- **WHEN** `feature_prerequisite_gaps.sh` is invoked with a valid feature path containing `requirements_ears.md`, `technical_requirements.md`, and `implementation_slices.md`
- **THEN** the script SHALL produce `prerequisite_gaps.md` at that feature path

#### Scenario: Script fails on missing required input
- **WHEN** any of `requirements_ears.md`, `technical_requirements.md`, or `implementation_slices.md` is absent from the feature path
- **THEN** `feature_prerequisite_gaps.sh` SHALL exit with a non-zero status and SHALL print an error identifying the missing file

#### Scenario: Each EARS requirement gets at least one entry
- **WHEN** `requirements_ears.md` contains N requirements
- **THEN** `prerequisite_gaps.md` SHALL contain one section per requirement, even if the prerequisites list for that requirement is empty

### Requirement: Unmet prerequisite promotion to slices
Before Step `8.3` may start, every `unmet` prerequisite in `prerequisite_gaps.md` SHALL be promoted to `implementation_slices.md` as a scheduled slice and the corresponding entry SHALL be updated to `status: scheduled_in_slices` with a valid `slice_ref`.

#### Scenario: Promotion updates status and slice_ref
- **WHEN** an `unmet` prerequisite is added as a new slice in `implementation_slices.md`
- **THEN** the `prerequisite_gaps.md` entry for that prerequisite SHALL be updated to `status: scheduled_in_slices` and `slice_ref` SHALL reference the new slice identifier

#### Scenario: Gate re-checked after promotion
- **WHEN** `prerequisite_gaps.md` is updated following promotion
- **THEN** `check_prerequisite_gaps_quality.sh` SHALL be re-run and SHALL pass before the orchestrator advances to Step `8.3`
