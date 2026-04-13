## Context

Overmind already has worker-oriented coordination artifacts, but the existing flows target the shared `overmind/worker_registry.yaml` and worker-local `ai/<uuid>_dont_touch.txt` identity handoff. There is no project-scoped runtime command that records which workers are registered for a specific ASDLC project folder under `asdlc/projects/<project-id>`.

This change adds a new project-level staged command that follows the same `--path <asdlc/projects/<project-id>>` contract already used by project-scoped commands such as `feature_br_scaffold.sh` and `init_common_contract_definition.sh`. The implementation must stay shell-only, preserve existing files when present, and avoid adding new CLI flags beyond the required project path selector.

## Goals / Non-Goals

**Goals:**
- Add `project_register_worker.sh` as a project-level command that requires `--path <asdlc/projects/<project-id>>`.
- Use the selected project folder as the only write scope and persist registrations into `<project-path>/workers.yaml`.
- Reuse canonical project metadata already stored in `<project-path>/init_progress_definition.yaml` so `workers.yaml` records the correct `project_id`.
- Keep registration interactive and constrained to exactly one allowed worker class per new worker.
- Persist each new worker with a generated UUID, `active` status, and registration date while preserving all existing worker entries.
- Stage the command into ASDLC workspaces through the existing bootstrap/update sync path and document the new runtime flow.

**Non-Goals:**
- Replace or remove the existing coordinator-level `overmind/worker_registry.yaml` flow.
- Add edit/delete worker operations in this change.
- Introduce non-interactive class selection, bulk registration, or extra status-setting flags.
- Add a YAML parser dependency or move shell project-management scripts to another runtime.

## Decisions

1. Resolve project scope only from a required `--path <asdlc/projects/<project-id>>` argument.
Rationale: existing project-scoped staged commands already use an explicit project path selector, and this keeps write scope deterministic instead of relying on current working directory.
Alternative considered: infer the project from script location or current directory. Rejected because it becomes ambiguous in staged workspaces and weakens fail-fast validation.

2. Treat `<project-path>/init_progress_definition.yaml` `meta_info.project_id` as the canonical source for `workers.yaml` `project_id`.
Rationale: `project_setup_add_new_project.sh` already seeds `meta_info.project_id`, so the new registry should reuse that source of truth instead of deriving a second identifier from the folder name.
Alternative considered: use the basename of the selected project directory as `project_id`. Rejected because the stored metadata is more explicit and remains authoritative if folder naming rules evolve.

3. Create and maintain a dedicated `<project-path>/workers.yaml` file with top-level `project_id` and `workers` keys.
Rationale: project-scoped worker registration should live with other project runtime artifacts rather than reusing the shared coordinator registry, and a simple two-key structure is easy to read and update from shell.
Alternative considered: append worker records into `init_progress_definition.yaml`. Rejected because worker registration is mutable runtime coordination data, while project definition remains the stable project bootstrap contract.

4. Keep the class-selection flow interactive with a strict one-of-four chooser and normalize persisted values to `backend`, `frontend`, `mobile`, or `infrastructure`.
Rationale: the user explicitly wants one required class per worker, and an interactive enumerated chooser matches existing Overmind script conventions.
Alternative considered: free-form text entry. Rejected because it would require more error handling and risks invalid class names in persisted metadata.

5. Write new worker entries by preserving existing file content and appending one normalized worker block per successful run.
Rationale: the file may already contain multiple workers, so registration must be additive and non-destructive. Rewriting via a temporary file keeps the shell implementation deterministic without requiring in-place YAML mutation tools.
Alternative considered: always regenerate `workers.yaml` from scratch. Rejected because it risks overwriting manually preserved entries and makes failure recovery harder.

6. Print the success handoff as the final user-facing contract using the exact requested message with the generated UUID inserted.
Rationale: the worker UUID must be handed to the developer verbatim, and the requested completion line is part of the behavior rather than incidental logging.
Alternative considered: print a shorter generic success line. Rejected because it loses the explicit handoff instruction the operator needs.

## Risks / Trade-offs

- [Risk] Shell-based YAML updates can become fragile if the file shape drifts from the expected scaffold. -> Mitigation: keep the file schema minimal, create the scaffold when missing, and fail fast when required top-level keys are malformed or absent.
- [Risk] Using `init_progress_definition.yaml` as the `project_id` source makes registration depend on project bootstrap completeness. -> Mitigation: fail with a clear error when `meta_info.project_id` is missing instead of silently inventing a fallback id.
- [Risk] Repeated runs will intentionally create multiple worker entries, which can grow the file over time. -> Mitigation: scope this change to append-only registration and defer worker update/removal workflows to a separate change.
- [Risk] Existing ASDLC workspaces will not receive the new command unless staging/update flows copy it in. -> Mitigation: update `project_setup_first_init_machine.sh` bootstrap and update sync lists and cover staged command presence in shell tests.

## Migration Plan

1. Add `overmind/scripts/project_mgmt/project_register_worker.sh` with required `--path` parsing, project validation, project-id loading, class selection, UUID/date generation, and additive `workers.yaml` writes.
2. Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` so bootstrap and update flows stage `project_register_worker.sh` into `<asdlc>/.commands/`.
3. Extend project-management shell tests to cover path validation, first-run scaffold creation, repeated registration appends, invalid class retry behavior, and final success message output.
4. Update `overmind/README.md` so the staged command and `workers.yaml` runtime contract are documented alongside other project-scoped commands.
5. Confirm `openspec status --change crp-104-project-level-worker-registration` reports the change as apply-ready once tasks are created.

Rollback strategy: remove the staged command, stop copying it into ASDLC workspaces, and delete the associated docs/tests while leaving any already-created `workers.yaml` files untouched for manual cleanup.

## Open Questions

- None. The remaining uncertainty is implementation detail, not behavior contract.
