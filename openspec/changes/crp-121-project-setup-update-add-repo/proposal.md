## Why

`overmind/scripts/project_mgmt/project_setup_update_project.sh` is currently a stub
that prints "Option 3 (update project) is not implemented yet." and exits 1. As a
result, once a project is bootstrapped there is no supported way to attach a repo
to a class that was registered as `deferred`, advance its status to `ready`, or
reclassify a project whose nature changed once real repos were attached.

## What Changes

- Replace the stub in `project_setup_update_project.sh` with an interactive
  add-repo flow that asks, in order: pick project (or quit) → pick class (or
  quit) → enter repo path (or quit). Any step accepts a quit input and exits
  cleanly without mutating state.
- Validate the entered repo path using the same checks used by
  `project_setup_add_new_project.sh` (reuse `validate_repo_path` /
  `resolve_repo_path`). On validation failure, re-prompt; on quit, exit cleanly.
- On successful validation, persist the repo against the chosen class in
  `projects/<project_id>/init_progress_definition.yaml` and transition that
  class entry's repo status from `deferred` to `ready`.
- After a successful add, if the project's `project_type_code` is `A` ("New
  project") and **all** class repo statuses in the project definition are
  `ready`, prompt the user whether to reclassify the project to `B` ("Existing
  project with partial context") or `C` ("Existing project with code-first
  context"). The prompt MUST allow finishing without changing the type. When a
  new type is chosen, update `project_type_code` and `project_type_label`
  accordingly.
- Add shell tests under `tests/ai_scripts/` covering: quit at each step, invalid
  path re-prompt, deferred→ready transition, the type-A reclassification prompt
  (accept B, accept C, decline), and the no-op path when not all repos are
  `ready`.

## Capabilities

### New Capabilities

- `project-update-add-repo`: Interactive flow for attaching a repo to an
  existing project's class, advancing that class's repo status from `deferred`
  to `ready` in `init_progress_definition.yaml`, and conditionally prompting to
  reclassify a type-`A` project to `B` or `C` once every class has a `ready`
  repo.

### Modified Capabilities

<!-- None. There are no existing specs in openspec/specs/ that own
     project-setup update behavior; no requirement-level changes to other
     capabilities are introduced. -->

## Impact

- **Code**: rewrite `overmind/scripts/project_mgmt/project_setup_update_project.sh`;
  factor reusable helpers (`validate_repo_path`, `resolve_repo_path`,
  project-type label/code helpers) out of
  `overmind/scripts/project_mgmt/project_setup_add_new_project.sh` if needed so
  both scripts share the same validation, without changing observable behavior
  of `project_setup_add_new_project.sh`.
- **Data**: in-place updates to `projects/<project_id>/init_progress_definition.yaml`
  — class repo entry path + status (`deferred`→`ready`), and optionally
  `project_type_code` / `project_type_label`.
- **Tests**: new suite `tests/ai_scripts/project_setup_update_project_tests.sh`.
- **Docs**: update `overmind/README.md` and `CLAUDE.md` test list to reflect the
  new script behavior and the new test command.
- **Out of scope**: removing repos, editing existing repos in place, multi-repo
  batch attach, and any change to the dispatcher menu.
