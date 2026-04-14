## Why

`implementation_plan.md` already supports optional `#### Assigned:` lines, but Overmind has no feature-level runtime script that assigns workers to plan steps after planning is complete. As a result, assignment is manual, class-to-worker matching is error-prone, and operators do not get deterministic output when a class has no eligible worker.

## What Changes

- Add a new feature-level runtime script `overmind/scripts/feature_assing_workers.sh`.
- Require `--feature_path <asdlc/projects/<project-id>/<feature-folder>>` and fail fast when the target feature path is invalid.
- Gate execution on implementation-plan readiness: the script runs only when `<feature-path>/implementation_plan.md` exists and contains parseable step blocks with `#### Repo:` ownership.
- Load workers from `<project-path>/workers.yaml` and resolve availability strictly by exact worker class (`backend`, `frontend`, `mobile`).
- For each repo class present in the implementation plan:
  - if zero active workers exist for that class, emit a meaningful class-scoped error message;
  - if exactly one active worker exists, auto-select that worker UUID for all steps of that class;
  - if more than one active worker exists, require the operator to pick exactly one worker from that class.
- Update `implementation_plan.md` so every step has `#### Assigned:` with either:
  - the selected worker UUID for that step’s repo class; or
  - a deterministic error message when no class-matching worker is available.
- Keep assignment additive and non-destructive: preserve existing step structure, order, and checklist content while rewriting only `#### Assigned:` values.
- Add docs and shell regression coverage for readiness gating, class filtering, multi-worker interactive selection, no-worker error output, and final plan mutation behavior.

## Capabilities

### New Capabilities

- `overmind-feature-implementation-plan-worker-assignment`: Feature-level worker assignment SHALL validate implementation-plan readiness, resolve workers strictly by step repo class, require exactly one class worker selection when multiple are available, and write deterministic `#### Assigned:` values (UUID or error) across all implementation steps.

### Modified Capabilities

- None.

## Impact

- Affected code:
  - `overmind/scripts/feature_assing_workers.sh` (new)
- Affected docs:
  - `overmind/README.md`
  - `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` staged command guidance, if command staging is required
- Affected tests:
  - `tests/ai_scripts/` new shell suite for feature-level worker assignment behavior
- Affected runtime artifacts:
  - `<asdlc/projects/<project-id>/<feature-folder>/implementation_plan.md`
  - `<asdlc/projects/<project-id>/workers.yaml` (read-only input)
