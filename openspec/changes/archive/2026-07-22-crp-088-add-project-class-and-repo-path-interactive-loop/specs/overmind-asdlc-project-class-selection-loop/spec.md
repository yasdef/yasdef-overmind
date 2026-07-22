## ADDED Requirements

### Requirement: Add-project flow SHALL run iterative project class selection until explicit completion
`overmind/scripts/project_mgmt/project_setup_add_new_project.sh` SHALL present class choices:
- `1. backend`
- `2. frontend`
- `3. mobile`
- `4. infrastructure`
- `5. all done, nothing else to add`

The class-selection prompt SHALL repeat until option `5` is selected.

#### Scenario: Class loop continues until done is selected
- **WHEN** user selects one or more class options from `1..4`
- **THEN** the script SHALL continue prompting for additional class choices
- **AND** SHALL stop class loop only when user selects option `5`

### Requirement: Add-project flow SHALL hide already selected classes and show running summary
Each selected class SHALL appear at most once in project definition metadata, and after each accepted class selection the script SHALL inform the user which classes are already added.

#### Scenario: Already selected class option is removed from menu
- **WHEN** user adds class `backend` during class loop
- **THEN** subsequent class prompts SHALL no longer display option `1. backend`
- **AND** backend SHALL still be present once in persisted class metadata

#### Scenario: Running class summary is shown after each accepted add
- **WHEN** user adds a new class during class loop
- **THEN** script SHALL print current list of already added classes

#### Scenario: Only done option remains after all classes are selected
- **WHEN** user has added `backend`, `frontend`, `mobile`, and `infrastructure`
- **THEN** the class-selection prompt SHALL display only option `5. all done, nothing else to add`
