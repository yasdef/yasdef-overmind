## ADDED Requirements

### Requirement: Class membership has an interactive command with two actions

`overmind project add-class` SHALL be interactive and argumentless, and SHALL offer exactly two mutating actions: add a class that is not in `meta_info.project_classes`, or change a class that is. The action menu SHALL also offer `Done` as a non-mutating clean exit. When a mutating action has no available target, its menu label SHALL disclose that unavailable state while keeping the action selectable so the operator can request the full diagnostic. An unknown argument SHALL produce a usage error with a non-success exit and no project change. The command SHALL resolve the project by using the current project when invoked from one, auto-selecting the only discovered project, or asking the operator to select one when several exist, and SHALL print the selected project before the first class prompt. It SHALL add no path flag.

#### Scenario: Standalone command selects among existing projects

- **WHEN** the operator runs `overmind project add-class` from a runtime workspace containing multiple projects
- **THEN** the command asks which project to manage, prints the selected project, and prompts for no class until a project is selected

#### Scenario: Command rejects unknown arguments

- **WHEN** the operator passes an unknown argument to `overmind project add-class`
- **THEN** the command returns a usage error and no project definition is changed

#### Scenario: No membership action is available

- **WHEN** all supported classes are already present and every existing class is already deferred with an empty path and policy `A`
- **THEN** the command labels add/change as unavailable, lets the operator inspect add/change unavailability messages, and exits cleanly through `Done`

#### Scenario: Unavailable action is visible before selection

- **WHEN** an action has no available class target
- **THEN** the action menu labels that action as unavailable before the operator selects it

#### Scenario: Operator finishes without changes

- **WHEN** the operator selects `Done` from the action menu
- **THEN** the command exits successfully without changing the project definition

### Requirement: Adding a class declares it as deferred with no repository

The add action SHALL offer the supported classes that are absent from `meta_info.project_classes` and SHALL insert the selected class as `state: "deferred"`, `path: ""`, and `policy: "A"`, keeping `meta_info.project_classes` and `meta_info.class_repo_paths` in canonical class order with the same class keys. It SHALL NOT ask for a repository path or a class policy, and SHALL report that `overmind project reconcile` binds existing repositories when they are available.

#### Scenario: A class absent at creation is added later

- **WHEN** a project has `backend` and `frontend` and the operator adds `mobile`
- **THEN** `mobile` is recorded deferred with an empty path and policy `A`, no repository path is requested, and the operator is told that `overmind project reconcile` binds existing repositories

#### Scenario: Canonical order is preserved

- **WHEN** `mobile` is added to a project that already has `frontend`
- **THEN** `project_classes` and `class_repo_paths` both list `frontend` before `mobile`

### Requirement: Changing a class resets it to deferred

The change action SHALL offer the classes present in `meta_info.project_classes` that are not already `state: "deferred"`, `path: ""`, and `policy: "A"`, showing each offered class's current policy, state, and path, and SHALL require explicit confirmation before mutation. On confirmation it SHALL reset the selected class to `state: "deferred"`, `path: ""`, `policy: "A"` and SHALL clear that class's `contract_reconciled` value. When no class is resettable, the command SHALL report that every existing class is already deferred with policy `A` and no repository path, then return to the add/change action prompt. Declining reset confirmation SHALL leave the class record unchanged and return to the action prompt. Closed input SHALL leave the class record unchanged. The change action SHALL NOT ask for a repository path or a class policy.

#### Scenario: A wrongly bound class is reset

- **WHEN** `backend` is ready at `/repo/wrong` with policy `C` and `contract_reconciled: true`, and the operator confirms changing it
- **THEN** `backend` becomes deferred with an empty path and policy `A`, carries no successful `contract_reconciled` value, and feature work may proceed without repo evidence until an existing repository is bound again

#### Scenario: Declining leaves the class unchanged

- **WHEN** the operator selects a class to change and declines the confirmation
- **THEN** the class record remains byte-equivalent, no project file is changed, and the command returns to the action prompt

#### Scenario: Already deferred policy A classes are not reset candidates

- **WHEN** every existing class is already deferred with an empty path and policy `A`
- **THEN** choosing the change action reports that no existing project classes need reset and returns to the add/change action prompt

### Requirement: Membership changes are coherent and preserve unrelated definition content

A membership mutation SHALL write one class row as a single definition update, preserving unrelated `meta_info` fields, unrelated `class_repo_paths` row content, and every line of the top-level `steps:` block. Every class row SHALL carry a `policy` of `A`, `B`, or `C`; policy `A` SHALL be valid only with `state: "deferred"` and an empty path.

#### Scenario: Unrelated definition content is preserved

- **WHEN** a class is added or reset
- **THEN** unrelated `meta_info` fields, unrelated class row fields, and every line from the top-level `steps:` block remain unchanged

#### Scenario: Closed input does not persist a change

- **WHEN** operator input closes before the mutation is confirmed
- **THEN** the project definition is not changed

### Requirement: Membership changes use the project repository transaction boundary

Before prompting for a class membership action, the command SHALL require a clean project-repository worktree when git status is inspectable. After the definition update in a git-backed project it SHALL offer one commit. Explicit decline SHALL retain the accepted uncommitted definition and report that state; inspection, staging, or commit failure SHALL return a typed diagnostic and SHALL NOT report a successful commit.

#### Scenario: Dirty project blocks the membership change

- **WHEN** a git-backed project has pre-existing uncommitted changes
- **THEN** the membership action is not prompted, the change is refused with the dirty paths identified, and no definition change is written

#### Scenario: Accepted change is committed once

- **WHEN** a class is added and the operator confirms the commit
- **THEN** one project-repository commit contains the definition update
