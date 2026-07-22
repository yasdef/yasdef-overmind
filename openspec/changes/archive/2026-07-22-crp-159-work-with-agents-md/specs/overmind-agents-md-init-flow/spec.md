## ADDED Requirements

### Requirement: Step 1.1 runs a stack-blueprint session then an agents-md session per active class

Init step 1.1 SHALL be labelled `Define Project Stack Blueprints And Agent Guidelines For Active Classes` and SHALL carry two session actions per class, dispatched in order for each active class of a type `A` project: the `overmind-stack-blueprint` session producing `project_stack_blueprint_<class>.md`, then the `overmind-agents-md` session producing `project_agents_md_claude_md_<class>.md`. Eligibility SHALL match the existing stack-blueprint eligibility: `project_type_code: A`, for every class in `meta_info.project_classes`.

#### Scenario: Both sessions run for each active class

- **WHEN** step 1.1 runs for a type `A` project with active `backend` and `frontend` classes
- **THEN** the blueprint session and then the agents-md session are dispatched for `backend`, and the blueprint session and then the agents-md session are dispatched for `frontend`

#### Scenario: Agents-md session follows its class blueprint

- **WHEN** the agents-md session for a class is dispatched
- **THEN** that class's `project_stack_blueprint_<class>.md` already exists and is bound as a read-only input

#### Scenario: Missing required agents-md output fails the step

- **WHEN** an agents-md session ends without writing its `project_agents_md_claude_md_<class>.md`
- **THEN** the step fails on the missing required output

#### Scenario: Type B and C projects run neither session

- **WHEN** project init runs for a project whose `project_type_code` is `B` or `C`
- **THEN** step 1.1 requires neither artifact and init advances to step 2

### Requirement: Step 1.1 completes only when both artifacts exist for every active class

Step 1.1 SHALL be complete for a type `A` project only when every class in `meta_info.project_classes` has both a `project_stack_blueprint_<class>.md` and a `project_agents_md_claude_md_<class>.md` at the project root, each passing its gate. The `init_progress_definition.yaml` step 1.1 entry SHALL declare `project_agents_md_claude_md_backend.md`, `project_agents_md_claude_md_frontend.md`, and `project_agents_md_claude_md_mobile.md` as artifacts required when `project_type_code` equals `A` and the matching class is active.

#### Scenario: Blueprint alone does not complete the step

- **WHEN** a type `A` project has a gate-passing blueprint for every active class but no agent guidelines artifact
- **THEN** step 1.1 remains pending

#### Scenario: Both artifacts for every active class complete the step

- **WHEN** every active class has a gate-passing blueprint and a gate-passing agent guidelines artifact
- **THEN** step 1.1 is complete and project init advances to step 2

#### Scenario: A class added later reopens the step

- **WHEN** a class is added to a type `A` project that had completed step 1.1
- **THEN** step 1.1 goes pending until the new class has both artifacts, and the existing classes' gate-passing artifacts are left unchanged

### Requirement: Step 2 blocks on the agent guidelines artifacts and the baseline commit owns them

For a type `A` project, Create Cross-Repository Contract Definition For This Project SHALL NOT proceed until every active class has a `project_agents_md_claude_md_<class>.md`, on the same terms as the existing per-class blueprint precondition. The step-2 initialization baseline commit SHALL include `project_agents_md_claude_md_<class>.md` for every active class in its owned paths, alongside `init_progress_definition.yaml`, `common_contract_definition.md`, and the per-class blueprints.

#### Scenario: Missing agent guidelines blocks step 2

- **WHEN** step 2 is attempted for a type `A` project with an active class that has no `project_agents_md_claude_md_<class>.md`
- **THEN** step 2 reports the missing required artifact and does not proceed

#### Scenario: Baseline commit owns the agent guidelines artifacts

- **WHEN** step 2 completes for a type `A` project with active `backend` and `frontend` classes
- **THEN** the initialization baseline commit contains both agent guidelines artifacts and the commit's owned-path guard treats them as expected changes

#### Scenario: Type B and C baselines carry no agent guidelines artifact

- **WHEN** step 2 completes for a project whose `project_type_code` is `B` or `C`
- **THEN** the initialization baseline commit owns `init_progress_definition.yaml` and `common_contract_definition.md` only
