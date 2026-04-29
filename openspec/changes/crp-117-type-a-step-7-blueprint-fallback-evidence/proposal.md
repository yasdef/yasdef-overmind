## Why

Project type `A` can now define approved per-class stack blueprints during init, but Step `7` still treats type `A` as unsupported and cannot produce the required `project_surface_struct_resp_map_<class>.md` artifacts. This blocks every downstream feature-planning phase for new projects even when CRP-114 and CRP-115 have already produced valid blueprint evidence.

## What Changes

- Update Step `7` surface-map generation so project type `A` can use `project_stack_blueprint_<class>.md` as fallback structural evidence when a real repository is not yet scannable.
- Preserve repo scan as the strongest source whenever a class repo path is materialized and scannable, including type `A` F2+ cases.
- Define the per-row evidence resolution chain for type `A`: repo evidence -> blueprint evidence -> literal `<to be defined during implementation>` placeholder.
- Require the active-class blueprint for type `A` before model invocation, while leaving type `B` and `C` repo-backed behavior unchanged.
- Update Step `7` rules, prompt context, init progress wording, golden examples, and tests to cover blueprint-only, mixed repo/blueprint, and placeholder fallback rows.
- Keep blueprint consumption scoped to Step `7`; Steps `8`, `8.1`, `8.2`, and `8.3` continue to consume the generated surface maps rather than reading blueprints directly.

## Capabilities

### New Capabilities

- `overmind-type-a-step-7-blueprint-fallback-evidence`: Step `7` SHALL produce per-class surface-map artifacts for project type `A` by resolving each row from repo evidence when available, otherwise from the approved stack blueprint, otherwise from a placeholder.
- `overmind-surface-map-blueprint-evidence-boundary`: Step `7` SHALL treat blueprint citations as planned structural evidence only for project type `A` and SHALL NOT let blueprint consumption bypass repo scan for project types `B` or `C`.

### Modified Capabilities

(none - no main specs exist yet for these requirements)

## Impact

- Depends on `crp-114-type-a-stack-blueprint-artifact-contract` and `crp-115-type-a-stack-blueprint-init-flow`.
- Affected workflow definition:
  - `overmind/templates/init_progress_definition_TEMPLATE.yaml`
  - `overmind/init_progress_definition_sequence_diagram.md`
- Affected Step `7` assets:
  - `overmind/scripts/feature_repo_surface_and_exec_context.sh`
  - `overmind/rules/feature_repo_surface_and_exec_context_rule.md`
  - `overmind/golden_examples/project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md`
  - `overmind/golden_examples/project_surface_struct_resp_map_fe_GOLDEN_EXAMPLE.md`
- Affected tests:
  - `tests/ai_scripts/feature_repo_surface_and_exec_context_be_tests.sh`
  - `tests/ai_scripts/feature_repo_surface_and_exec_context_fe_tests.sh`
  - related init progress scanner tests if Step `7` completion conditions change
