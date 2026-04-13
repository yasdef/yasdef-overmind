## ADDED Requirements

### Requirement: Add-project flow SHALL ask per selected class whether repo path is ready now
After class-selection loop completes, add-project SHALL iterate selected classes and ask for each class:
- `we need to add repo path in your system for <project class>`
- `1. yes, ready to add`
- `2. no, I'll add it later`

#### Scenario: User defers repo path for a selected class
- **WHEN** user selects option `2` for a class repo-path question
- **THEN** script SHALL continue with next selected class
- **AND** project definition metadata SHALL persist that class with deferred path state

### Requirement: Add-project flow SHALL validate repo path when user is ready to add
When user selects option `1`, script SHALL prompt for path and SHALL accept only paths that exist and are non-empty.

#### Scenario: Invalid repo path is rejected and re-prompted
- **WHEN** user provides missing path, non-directory path, or empty directory path
- **THEN** script SHALL print validation error
- **AND** SHALL re-prompt for path for the same class

#### Scenario: Valid repo path is persisted for class
- **WHEN** user provides existing non-empty directory path for selected class
- **THEN** script SHALL persist that path under `meta_info.class_repo_paths.<class>.path`
- **AND** SHALL set `meta_info.class_repo_paths.<class>.state` to `ready`
