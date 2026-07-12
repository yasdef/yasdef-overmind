## ADDED Requirements

### Requirement: Class management is reusable after creation or as a standalone command

The coordinator SHALL provide one deterministic class-management subprocess that can receive a newly created project root from `overmind project create` or resolve an existing project through argumentless `overmind project add-class-and-repo`. The standalone command SHALL use the current project when invoked from a project, auto-select the only discovered project, or ask the operator to select one when multiple projects exist. It SHALL print the selected project before class mutation and SHALL add no path flag.

#### Scenario: Post-create handoff uses the new project

- **WHEN** project creation succeeds and the operator chooses to add project classes
- **THEN** class management starts against the newly created project without asking the operator to select the project again

#### Scenario: Standalone command selects among existing projects

- **WHEN** the operator runs `overmind project add-class-and-repo` from a runtime workspace containing multiple projects
- **THEN** the command asks which project to manage and starts no class prompt until a project is selected

#### Scenario: Standalone command accepts no arguments

- **WHEN** the operator passes an argument to `overmind project add-class-and-repo`
- **THEN** the command returns a usage error without changing any project

### Requirement: Class management uses a repeatable add-or-finish loop

The class-management subprocess SHALL repeatedly offer `add new class` and `all done`. Each pass SHALL first display an informational summary of the already-added classes and their repository state, for example `already added: backend (repo deferred), frontend (repo ready)`, reflecting staged changes accepted earlier in the session; the summary SHALL be omitted when the project has no configured class. Choosing add SHALL present `backend`, `frontend`, `mobile`, and `infrastructure` as plain selectable options, including classes that already exist. Choosing all done SHALL persist any accepted staged changes and finish successfully; choosing it before any change SHALL be a successful no-op.

#### Scenario: Already-added classes are summarized before the menu

- **WHEN** the project has a deferred backend class and a ready frontend class and the add-or-finish menu is shown
- **THEN** the summary reports backend as repo deferred and frontend as repo ready, and the class picker still offers all four classes as plain options

#### Scenario: Operator adds multiple classes in one session

- **WHEN** the operator adds backend, returns to the class menu, adds frontend, and then selects all done
- **THEN** both accepted class records are persisted in canonical backend-before-frontend order

#### Scenario: Operator finishes immediately

- **WHEN** the operator selects all done as the first action
- **THEN** the command exits successfully without modifying the project definition

### Requirement: Every added or changed class has an explicit class policy

After class selection, the subprocess SHALL require exactly one class policy from `A`, `B`, or `C`, or an explicit escape/back action. Escape/back SHALL return to the add-or-finish loop without changing or staging the selected class. The selected class policy SHALL be written to `meta_info.class_repo_paths.<class>.policy` and SHALL NOT change `meta_info.project_type_code` or `project_type_label`.

#### Scenario: Escape returns without mutation

- **WHEN** the operator selects a class and then chooses escape/back at the policy prompt
- **THEN** the class has no staged or persisted change and the add-or-finish menu is shown again

#### Scenario: Class policy is independent from project type

- **WHEN** a project with `project_type_code: "A"` receives a backend class with policy `C`
- **THEN** backend records `policy: "C"` while the project type code and label remain unchanged

### Requirement: Class policy determines repository state capture

Policy `A` SHALL produce `state: "deferred"` and `path: ""` without asking for a repository. Policies `B` and `C` SHALL ask whether the repository will be added now or later. Later SHALL preserve the selected policy with deferred/empty state. A valid path supplied now SHALL preserve the selected policy with `state: "ready"` and the canonical absolute path.

#### Scenario: Policy A is always deferred

- **WHEN** the operator selects policy `A` for mobile
- **THEN** mobile is proposed with policy `A`, state deferred, and an empty path, and no repository question is shown

#### Scenario: Policy B repository is deferred

- **WHEN** the operator selects policy `B` for backend and chooses to add its repository later
- **THEN** backend is proposed with policy `B`, state deferred, and an empty path

#### Scenario: Policy C repository is ready

- **WHEN** the operator selects policy `C` for frontend and supplies a valid repository directory
- **THEN** frontend is proposed with policy `C`, state ready, and the canonical absolute repository path

### Requirement: Repository path failure returns to the now-or-later decision

An add-now repository path SHALL be rejected when it is blank, missing, not a directory, or an empty directory. The command SHALL report the validation reason and return to the repository add-now/add-later decision for the same class and policy. It SHALL persist only a path that passes validation and canonical resolution.

#### Scenario: Invalid path can be retried

- **WHEN** the operator chooses add now, supplies an invalid path, chooses add now again, and supplies a valid non-empty directory
- **THEN** the invalid path is never staged and the class is proposed ready with the canonical valid path

#### Scenario: Invalid path can be deferred

- **WHEN** the operator supplies an invalid add-now path and then chooses add later
- **THEN** the class is proposed deferred with an empty path and retains its selected `B` or `C` policy

### Requirement: Existing class replacement requires explicit comparison confirmation

When the selected class already exists and the complete proposed policy/state/path differs, the subprocess SHALL display the current record and proposed record and ask for explicit confirmation before staging the replacement. Declining SHALL preserve the current record and return to the add-or-finish loop. An identical proposal SHALL be reported unchanged without confirmation or write. An accepted replacement SHALL clear that class's `contract_reconciled` value.

#### Scenario: Existing ready repository is replaced

- **WHEN** backend currently has policy `C` and ready path `/repo/old`, the operator proposes policy `B` and ready path `/repo/new`, and confirms the displayed replacement
- **THEN** backend records the new policy/path/state and no longer carries a successful `contract_reconciled` value

#### Scenario: Existing class replacement is declined

- **WHEN** the operator proposes a different record for an existing class and declines confirmation
- **THEN** the existing class record remains byte-equivalent and the class menu is shown again

### Requirement: Accepted class changes are coherent and atomically persisted

The subprocess SHALL stage accepted class records in memory and, on all done, atomically update `meta_info.project_classes` and `meta_info.class_repo_paths` once while preserving unrelated metadata and the complete `steps` block. Both structures SHALL use canonical class order and contain the same class keys. Policy `A` SHALL be valid only with deferred/empty state; ready SHALL require a non-empty canonical path; deferred SHALL require an empty path.

#### Scenario: Closed input does not persist the pending session

- **WHEN** operator input closes before all done
- **THEN** no staged class change from that session is written to the project definition

#### Scenario: Unrelated definition content is preserved

- **WHEN** accepted class changes are persisted
- **THEN** unrelated `meta_info` fields and every line from the top-level `steps` block remain unchanged

### Requirement: Class changes use the project repository transaction boundary

Before persisting a changed session, the command SHALL require a clean project-repository worktree when git status is inspectable. After an atomic class-definition update in a git-backed project, it SHALL offer one commit for the session. Explicit decline SHALL retain the accepted uncommitted definition and report that state; inspection, staging, or commit failure SHALL return a typed diagnostic and SHALL NOT report a successful commit.

#### Scenario: Dirty project blocks class mutation

- **WHEN** a git-backed project has pre-existing uncommitted changes before class management attempts to persist accepted changes
- **THEN** persistence is refused with the dirty paths identified and no staged class change is written

#### Scenario: Accepted session is committed once

- **WHEN** multiple class changes are accepted, all done is selected, and the operator confirms the commit
- **THEN** one project-repository commit contains the single atomic definition update for the session
