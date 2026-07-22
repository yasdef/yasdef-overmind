## Why

Overmind currently has coordinator-level worker registration on the `overmind` branch, but it does not provide a project-scoped runtime command for registering a worker against a specific ASDLC project. That leaves project owners without a durable `workers.yaml` record that captures which worker UUID belongs to which project class before work is handed off to a developer.

## What Changes

- Add a new project-level runtime script at `overmind/scripts/project_mgmt/project_register_worker.sh`.
- Require the script to run only with `--path <asdlc/projects/<project-id>>` and fail fast when the path does not resolve to a valid project directory.
- Create `<project-path>/workers.yaml` when it does not already exist, and preserve existing content when it already exists.
- Require `workers.yaml` to store basic project metadata with `project_id` plus a workers collection containing, for each worker:
  - generated worker UUID
  - exactly one non-empty class from `backend`, `frontend`, `mobile`, or `infrastructure`
  - status from `active`, `postponed`, or `deleted`
  - registration date
- Make the registration flow interactive so the operator must choose exactly one worker class before registration completes.
- Generate a new UUID for each new worker registration, append the worker entry with status set to `active`, and print the completion handoff message instructing the operator to pass the UUID to the developer.
- Keep the change minimal and non-destructive: no new parallel workflow variants and no extra CLI flags beyond the required project `--path` contract.

## Capabilities

### New Capabilities
- `overmind-project-worker-registry-file`: Project-level worker registration SHALL create and preserve `<project-path>/workers.yaml` with `project_id` metadata and structured worker records.
- `overmind-project-worker-registration`: The register-worker flow SHALL validate project-path scope, require exactly one allowed worker class, generate a UUID, persist the new worker as `active` with registration date, and print the final UUID handoff message.

### Modified Capabilities
- None.

## Impact

- Affected scripts:
  - `overmind/scripts/project_mgmt/project_register_worker.sh`
  - `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`
  - `overmind/scripts/project_mgmt/project_setup_update_project.sh`
- Affected runtime artifacts:
  - `<asdlc/projects/<project-id>/workers.yaml`
- Affected tests:
  - `tests/ai_scripts/` project-management script coverage for project-path validation, file scaffolding, and worker registration flow
- Affected docs:
  - `overmind/README.md`
- Affected systems:
  - Project-scoped worker coordination metadata in ASDLC runtime workspaces
