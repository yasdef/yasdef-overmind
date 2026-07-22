## ADDED Requirements

### Requirement: Progress scanner SHALL support project-scoped definition resolution
Scanner execution for ASDLC project management SHALL support project-scoped definition resolution using `<project-path>/init_progress_definition.yaml` instead of repository-global `overmind/init_progress_definition.yaml`.

#### Scenario: Project-scoped definition drives checklist rendering
- **WHEN** scanner is invoked with `/asdlc/projects/<project-id>`
- **THEN** checklist step parsing SHALL use `/asdlc/projects/<project-id>/init_progress_definition.yaml`
- **AND** rendered checklist completion SHALL be evaluated from the selected project scope

### Requirement: Project-scoped scans SHALL be isolated per selected project
Project progress evaluation SHALL be isolated to the selected project path so results are not affected by another project’s definition or artifacts.

#### Scenario: Different projects produce independent progress states
- **WHEN** two project folders contain different `init_progress_definition.yaml` and artifact states
- **THEN** scanning project A SHALL produce project A state
- **AND** scanning project B SHALL produce project B state without reusing project A state
