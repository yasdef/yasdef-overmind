## Why

`overmind project create` currently couples project identity with a mandatory, creation-only class/repository loop. This prevents creating an intentionally empty project and leaves no dedicated command for adding or changing class policy and repository bindings later.

## What Changes

- **BREAKING**: split project onboarding into two subprocesses with separate ownership:
  - `overmind project create` captures the project name and project-level `project_type_code`, creates the project with empty `project_classes` and `class_repo_paths`, then optionally hands off to class management.
  - `overmind project add-class-and-repo` selects an existing project and runs the same class-management subprocess independently at any later time.
- After project creation, ask whether the operator wants to add project classes. Declining finishes successfully; accepting invokes class management against the newly created project without repeating project selection.
- Add a repeatable class-management loop with exactly two top-level actions: add/change a class, or finish.
- For an add/change action, select `backend`, `frontend`, `mobile`, or `infrastructure`, then select class policy `A`, `B`, or `C`; an escape action at the policy prompt returns to the top-level loop without mutation.
- Persist class policy under `meta_info.class_repo_paths.<class>.policy`, separately from the project-level `meta_info.project_type_code`.
- Policy `A` always records `state: "deferred"` and `path: ""`. Policies `B` and `C` ask whether to add a repository now or later; later records deferred/empty state, while a valid repository path records `state: "ready"` and its canonical absolute path.
- Validate an entered repository path as an existing, non-empty directory. Invalid input returns to the add-now/add-later decision so the operator can retry or defer.
- When the class already exists, show its current record and the proposed replacement and require explicit confirmation before changing it. Decline leaves the definition unchanged and returns to the top-level loop.
- **BREAKING**: class management becomes the sole interactive writer of `project_classes` and `class_repo_paths`. `overmind project reconcile` retains contract reconciliation for ready classes but no longer prompts to attach deferred repositories.
- Keep both commands interactive and argumentless; reuse existing runtime/project discovery rather than adding a new path flag.

## Capabilities

### New Capabilities

- `project-class-management`: repeatable interactive creation and replacement of class policy/state/path records, including navigation, validation, confirmation, and project selection.

### Modified Capabilities

- `project-creation`: project creation captures only identity and project type before creating an empty class map, then optionally delegates to class management.
- `project-update`: project reconciliation no longer owns deferred repository attachment; class/repository metadata changes use the dedicated class-management command.

## Impact

- `packages/asdlc-coordinator/src/capture/project.ts` — separate base project creation from class capture and allow empty class metadata.
- `packages/asdlc-coordinator/src/capture/` or a focused project-class module — add the reusable class-management primitive and typed result.
- `packages/asdlc-coordinator/src/parse/project-definition.ts` — add deterministic add/replace mutation for class policy, state, and path while preserving unrelated definition content.
- `packages/asdlc-coordinator/src/cli/run.ts` — add `project add-class-and-repo`, project selection, and the optional post-create handoff.
- `packages/asdlc-coordinator/src/orchestrator/run-project-reconciliation-flow.ts` — remove deferred-class attachment prompts and retain reconciliation of ready unreconciled classes.
- Coordinator tests, `README.md`, and `QUICKRUN.md` — cover and document both entry points, all policy branches, invalid-path recovery, escape, and confirmed replacement.
- Existing project definitions remain readable; no deployed/runtime workspace file is rewritten by this change.
