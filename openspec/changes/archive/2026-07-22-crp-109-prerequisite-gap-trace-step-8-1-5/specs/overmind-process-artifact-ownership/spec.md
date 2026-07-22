## ADDED Requirements

### Requirement: Step 8.2 coordinator assets under overmind/
The coordinator-owned planning assets stored under `overmind/` SHALL include the Step `8.2` rule, template, golden example, generator script, and quality helper introduced by this change.

#### Scenario: Rule file present at expected path
- **WHEN** the `overmind/` directory is inspected
- **THEN** `overmind/rules/prerequisite_gaps_rule.md` SHALL exist and SHALL define how to produce a valid `prerequisite_gaps.md` artifact

#### Scenario: Template file present at expected path
- **WHEN** the `overmind/` directory is inspected
- **THEN** `overmind/templates/prerequisite_gaps_TEMPLATE.md` SHALL exist and SHALL provide the structural scaffold for `prerequisite_gaps.md`

#### Scenario: Golden example present at expected path
- **WHEN** the `overmind/` directory is inspected
- **THEN** `overmind/golden_examples/prerequisite_gaps_GOLDEN_EXAMPLE.md` SHALL exist and SHALL demonstrate a fully populated `prerequisite_gaps.md` with at least one `present_in_repo`, one `scheduled_in_slices`, and one resolved-from-`unmet` entry

#### Scenario: Generator script present and executable
- **WHEN** the `overmind/scripts/` directory is inspected
- **THEN** `overmind/scripts/feature_prerequisite_gaps.sh` SHALL exist and SHALL be executable

#### Scenario: Quality helper present and executable
- **WHEN** the `overmind/scripts/helper/` directory is inspected
- **THEN** `overmind/scripts/helper/check_prerequisite_gaps_quality.sh` SHALL exist and SHALL be executable

#### Scenario: Assets staged to ASDLC projects by setup scripts
- **WHEN** `project_setup_first_init_machine.sh` or `project_setup_update_project.sh` is run
- **THEN** both scripts SHALL stage the Step `8.2` generator and quality helper to the project `.commands/` directory alongside the existing Step `8.1` and `8.3` scripts
