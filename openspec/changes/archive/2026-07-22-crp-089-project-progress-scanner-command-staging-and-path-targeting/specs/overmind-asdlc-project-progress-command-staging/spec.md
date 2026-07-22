## ADDED Requirements

### Requirement: ASDLC bootstrap SHALL stage project progress scanner command
The first-machine ASDLC bootstrap flow SHALL stage a runnable progress scanner helper at `/asdlc/.commands/init_progress_scanner.sh`.

#### Scenario: Bootstrap stages scanner command with executable mode
- **WHEN** `project_setup_first_init_machine.sh` completes successfully
- **THEN** `/asdlc/.commands/init_progress_scanner.sh` SHALL exist
- **AND** the staged scanner command SHALL be executable

### Requirement: Staged scanner command SHALL accept an ASDLC project path
The staged scanner command SHALL accept a project directory path under `/asdlc/projects/` and SHALL evaluate progress for that selected project.

#### Scenario: Scanner runs for selected project path
- **WHEN** user runs `/asdlc/.commands/init_progress_scanner.sh /asdlc/projects/<project-id>`
- **THEN** scanner SHALL load `/asdlc/projects/<project-id>/init_progress_definition.yaml`
- **AND** scanner output SHALL represent current progress state for that selected project

#### Scenario: Scanner rejects project path outside ASDLC projects root
- **WHEN** user provides a path outside `/asdlc/projects/`
- **THEN** scanner SHALL exit non-zero with a clear validation error

#### Scenario: Scanner rejects project path without definition file
- **WHEN** selected project path does not contain `init_progress_definition.yaml`
- **THEN** scanner SHALL exit non-zero with a clear missing-definition error
