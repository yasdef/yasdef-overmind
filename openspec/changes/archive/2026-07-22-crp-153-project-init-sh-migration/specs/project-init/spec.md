## ADDED Requirements

### Requirement: Project init runs through a TypeScript verb over the generic executor

Init steps 1.1 and 2 SHALL be driven by `overmind project init --path <project>` through the existing generic executor and step catalog, not by shell. The repository SHALL NOT contain `overmind/scripts/init_project_stack_blueprints.sh` or `overmind/scripts/init_common_contract_definition.sh`. Steps `1.1` and `2` in the step catalog SHALL carry non-empty session actions, and no bespoke launcher SHALL be introduced — each session SHALL be a catalog entry executed by the generic executor with its model row loaded through `config/runner-config.ts`.

#### Scenario: Init step runs via the CLI verb

- **WHEN** an operator runs `overmind project init --path projects/<project>` inside an ASDLC workspace
- **THEN** the next pending project-init step is dispatched through the generic executor, its model session runs with the configured model row, and a non-success exit is returned when a bound gate, guard, required output, or the baseline commit fails

#### Scenario: Init shell launchers are absent

- **WHEN** the versioned production tree is inspected
- **THEN** `overmind/scripts/init_project_stack_blueprints.sh` and `overmind/scripts/init_common_contract_definition.sh` do not exist, no packaged staging references them, and the step catalog defines session actions for steps `1.1` and `2`

#### Scenario: Missing path argument is a usage error

- **WHEN** an operator runs `overmind project init` without `--path`
- **THEN** a usage error is written and a non-success exit is returned, and no session is launched

### Requirement: Project init selects the next pending step from the progress report

`overmind project init` SHALL determine which project-init step to run by evaluating the project's `ProgressReport` and selecting the next pending project-scoped step, using the same evaluation source as `overmind run` pending-work detection. It SHALL NOT contain hand-written per-step branches; the selected step definition SHALL be mapped to executor bindings and executed generically. When project-init steps are already complete, the verb SHALL report that no pending init step remains without launching a session.

#### Scenario: Next pending step is selected automatically

- **WHEN** step 1.1 is complete but step 2 is pending for a project
- **THEN** `overmind project init` dispatches step 2 without requiring the operator to name a step

#### Scenario: No pending init step is a clean no-op

- **WHEN** all project-init steps for the project are already complete
- **THEN** `overmind project init` reports that no pending init step remains and exits without launching a session

### Requirement: Project-type applicability governs step 1.1

Step 1.1 (stack blueprints) SHALL apply only to type `A` projects that have at least one active `backend`, `frontend`, or `mobile` class. For a non-type-`A` project, or a type-`A` project with no active stack class, step 1.1 SHALL be treated as complete/not-applicable so that next-pending selection advances to step 2. Step 2 (common contract) SHALL apply to projects of every type, binding blueprint evidence for type `A` and ready class-repo evidence for types `B`/`C`.

#### Scenario: Non-type-A project skips step 1.1

- **WHEN** `overmind project init` runs for a type `B` project
- **THEN** step 1.1 is not launched and the next pending step selected is step 2

#### Scenario: Type-A project with no stack class skips step 1.1

- **WHEN** a type `A` project has only an `infrastructure` class active
- **THEN** step 1.1 is treated as not-applicable and next-pending selection advances past it

### Requirement: Project-init baseline commit is a deterministic coordinator action

After step 2's gate passes, `overmind project init` SHALL commit the initialization baseline through the project git port: staging the project's `init_progress_definition.yaml`, `common_contract_definition.md`, and (for type `A`) the applicable `project_stack_blueprint_<class>.md` files, asserting that project initialization produced no unexpected changes outside that baseline pathspec, and creating the baseline commit. The commit SHALL run through an injected git port so it is deterministic under test, SHALL live in coordinator code rather than skill prose, and SHALL keep the project git scope distinct from the runtime-root and class-repository scopes.

#### Scenario: Baseline is committed after step 2

- **WHEN** step 2 completes and its gate passes for a project with a clean worktree apart from the baseline artifacts
- **THEN** the definition, `common_contract_definition.md`, and applicable blueprints are staged and committed as the initialization baseline through the injected git port

#### Scenario: Unexpected changes abort the baseline commit

- **WHEN** project initialization has produced changes outside the baseline pathspec
- **THEN** the commit is aborted with a clear error and the baseline is not committed

### Requirement: Class repo path reading is served by existing parse/repo modules

Reading and validating `meta_info.class_repo_paths` and `meta_info.project_classes` for project init SHALL be served by the existing `parse/project-definition.ts`, `repo/collect-ready-paths.ts`, and `repo/attach.ts` modules; the `overmind/scripts/common_libs/class_repo_paths.sh` common library SHALL be deleted and SHALL NOT be reintroduced as a parallel module. Ready class-repo evidence SHALL be limited to classes whose state is `ready` with an existing directory resolved to a canonical path.

#### Scenario: Ready-repo evidence derives from existing modules

- **WHEN** step 2 needs the authoritative ready class-repo paths for a type `B`/`C` project
- **THEN** the paths are derived from `parse/project-definition.ts`/`repo/collect-ready-paths.ts`, restricted to `ready` classes with existing directories, without invoking any shell library

#### Scenario: class_repo_paths shell library is absent

- **WHEN** the versioned production tree is inspected
- **THEN** `overmind/scripts/common_libs/class_repo_paths.sh` does not exist and no staging references it

### Requirement: Pending-work guidance names the TypeScript init verb

`overmind run` pending-work guidance, the init progress sequence diagram, and the init progress definition template SHALL name `overmind project init` and the TypeScript gate contract instead of the retired shell commands. The literal `.helper/check_project_stack_blueprint_quality.sh` completion text SHALL be replaced with the TypeScript gate contract, and `overmind/README.md`, `QUICKRUN.md`, and generated quick-run guidance SHALL contain no active shell invocation for init steps 1.1 and 2.

#### Scenario: Pending step 1.1 points at the init verb

- **WHEN** `overmind run` refuses because project step 1.1 is pending
- **THEN** the emitted guidance names `overmind project init --path <project>` and does not reference `init_project_stack_blueprints.sh`

#### Scenario: Pending step 2 points at the init verb

- **WHEN** `overmind run` refuses because project step 2 is pending
- **THEN** the emitted guidance names `overmind project init --path <project>` and does not reference `init_common_contract_definition.sh`

#### Scenario: Docs and template carry no init shell invocation

- **WHEN** `init_progress_definition_sequence_diagram.md`, `init_progress_definition_TEMPLATE.yaml`, `README.md`, and `QUICKRUN.md` are inspected
- **THEN** they describe `overmind project init` and the TypeScript gate contract and contain no active `.sh` invocation for steps 1.1 and 2
