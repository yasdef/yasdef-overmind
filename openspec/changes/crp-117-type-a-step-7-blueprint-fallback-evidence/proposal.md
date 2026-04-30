## Why

Project type `A` can now define approved per-class stack blueprints during init, but Step `7` still treats type `A` as unsupported and cannot produce the required `project_surface_struct_resp_map_<class>.md` artifacts. This blocks every downstream feature-planning phase for new projects even when CRP-114 and CRP-115 have already produced valid blueprint evidence.

## What Changes

- Update Step `7` surface-map generation so project type `A` can produce `project_surface_struct_resp_map_<class>.md` artifacts using the approved stack blueprint as always-required planned evidence plus repo scan when the class path is scannable.
- Require `project_stack_blueprint_<class>.md` at the project root for every active type `A` class before model invocation — hard error if missing. This is unconditional and does not depend on whether a repo path is also available.
- Run repo scan additionally whenever `class_repo_paths[<class>].path` resolves to a scannable directory, using it as the stronger per-field evidence source.
- Define per-field evidence resolution in the model output: for §4 `repo_paths` and `transport_layer` fields the chain is repo evidence → blueprint evidence → literal `<to be defined during implementation>`. §3 layer blocks are enumerated only for layers present in repo or anticipated by the blueprint; layers absent from both sources are omitted from §3, not placeholdered.
- Leave type `B` and `C` repo-backed behavior unchanged.
- Update Step `7` rules, prompt context, init progress wording, golden examples, and tests to cover blueprint-only (F1), mixed repo/blueprint (F2+), and placeholder rows for surfaces unknown to both sources.
- Keep blueprint consumption scoped to Step `7`; Steps `8`, `8.1`, `8.2`, and `8.3` continue to consume the generated surface maps rather than reading blueprints directly.

## Capabilities

### New Capabilities

- `overmind-type-a-step-7-blueprint-fallback-evidence`: Step `7` SHALL produce per-class surface-map artifacts for project type `A` by always requiring the approved stack blueprint (hard error if missing) and additionally using repo evidence when the class path is scannable. In the model output, §4 `repo_paths` and `transport_layer` fields resolve as: repo → blueprint → `<to be defined during implementation>`. §3 layers are enumerated only when backed by repo or blueprint evidence; layers absent from both are omitted.
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
