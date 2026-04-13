## ADDED Requirements

### Requirement: Step contracts SHALL support project-class-conditional requirement guards
`overmind/init_progress_definition.yaml` step entries under `finished_only_if_artefacts_present` and `input_required` SHALL support an optional structured `required_if` guard that references `meta_info.project_classes`.

#### Scenario: Backend-only metadata enables only backend tech-summary requirement
- **WHEN** `meta_info.project_classes` contains `backend` and does not contain `frontend` or `mobile`
- **THEN** entries guarded for backend tech summary SHALL be mandatory
- **AND** entries guarded for frontend/mobile tech summary SHALL be non-mandatory

#### Scenario: Frontend/mobile-only metadata enables only frontend tech-summary requirement
- **WHEN** `meta_info.project_classes` contains `frontend` or `mobile` and does not contain `backend`
- **THEN** entries guarded for frontend/mobile tech summary SHALL be mandatory
- **AND** entries guarded for backend tech summary SHALL be non-mandatory

#### Scenario: Fullstack metadata requires both tech summaries
- **WHEN** `meta_info.project_classes` contains both `backend` and (`frontend` or `mobile`)
- **THEN** both guarded tech-summary entries SHALL be mandatory

#### Scenario: Empty project classes do not force guarded tech-summary requirements
- **WHEN** `meta_info.project_classes` is empty
- **THEN** guarded backend/frontend tech-summary entries SHALL be non-mandatory

### Requirement: Condition evaluation semantics SHALL be deterministic and shared
All consumers of step contracts that evaluate `required_if` SHALL use the same predicate semantics for `meta_info.project_classes` so artifact checks and input checks cannot diverge.

#### Scenario: Shared any-of predicate semantics are applied
- **WHEN** `required_if.meta_info.project_classes.any_of` is declared for an entry
- **THEN** a match SHALL occur only when at least one configured value exists in `meta_info.project_classes`

#### Scenario: Unguarded entries remain always required
- **WHEN** an entry omits `required_if`
- **THEN** that entry SHALL remain mandatory under existing behavior

#### Scenario: Invalid conditional contract is rejected explicitly
- **WHEN** a step entry declares malformed or unsupported `required_if` content
- **THEN** the consumer SHALL fail fast with an explicit validation error instead of silently treating the entry as optional

### Requirement: Steps 5 and 6 SHALL gate tech-summary inputs by project class
Step 5 (`Resolve Missing Technical Details`) and Step 6 (`Technical Requirements Structuring`) `input_required` entries for `project_tech_summary_be.md` and `project_tech_summary_fe.md` SHALL be guarded by project-class conditions.

#### Scenario: Step 5 and Step 6 require backend summary for backend class
- **WHEN** `meta_info.project_classes` contains `backend`
- **THEN** Step 5 and Step 6 input checks SHALL require `project_tech_summary_be.md`

#### Scenario: Step 5 and Step 6 require frontend summary for frontend/mobile classes
- **WHEN** `meta_info.project_classes` contains `frontend` or `mobile`
- **THEN** Step 5 and Step 6 input checks SHALL require `project_tech_summary_fe.md`

#### Scenario: Step 5 and Step 6 treat tech summaries as non-blocking when classes are empty
- **WHEN** `meta_info.project_classes` is empty
- **THEN** Step 5 and Step 6 input checks SHALL NOT fail solely because `project_tech_summary_be.md` or `project_tech_summary_fe.md` is missing
