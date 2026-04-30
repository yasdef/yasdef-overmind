## 1. Type A Evidence Resolution

- [x] 1.1 Update `overmind/scripts/feature_repo_surface_and_exec_context.sh` to remove the project type `A` hard stop before model invocation
- [x] 1.2 Add target collection for type `A` active backend/frontend/mobile classes using ready repo evidence when the configured class repo path is ready and resolves to a directory
- [x] 1.3 Add type `A` blueprint binding for `projects/<project-id>/project_stack_blueprint_<class>.md` as planned fallback evidence when no ready class repo path is available or when a ready repo path leaves rows/fields unresolved
- [x] 1.4 Ensure missing type `A` repo and missing matching blueprint fails before model invocation with a blocking message naming the missing blueprint
- [x] 1.5 Preserve existing type `B` and `C` ready-repo selection behavior and failure messages

## 2. Prompt And Rule Updates

- [x] 2.1 Update Step `7` prompt construction to bind repository evidence and, for type `A`, planned blueprint fallback evidence when available; state that repo evidence wins per row/field
- [x] 2.2 Update `overmind/rules/feature_repo_surface_and_exec_context_rule.md` so type `A` uses repo evidence first, blueprint evidence second, and `<to be defined during implementation>` when neither source resolves a row
- [x] 2.3 Update rule text to label blueprint-derived values as planned structural evidence, not repository-proven code evidence
- [x] 2.4 Ensure prompt and rule text keep `requirements_ears.md`, `feature_contract_delta.md`, and `init_progress_definition.yaml` as the feature-scoping inputs
- [x] 2.5 Ensure prompt and rule text keep stack blueprint consumption scoped to Step `7` and project type `A`

## 3. Surface-Map Examples And Progress Definition

- [x] 3.1 Update backend surface-map golden example to illustrate repo evidence, type `A` blueprint evidence, and `<to be defined during implementation>` fallback rows
- [x] 3.2 Update frontend/mobile surface-map golden example to illustrate repo evidence, type `A` blueprint evidence, and `<to be defined during implementation>` fallback rows
- [x] 3.3 Update `overmind/templates/init_progress_definition_TEMPLATE.yaml` Step `7` wording to describe type `A` repo-first, blueprint-fallback, and placeholder behavior
- [x] 3.4 Update `overmind/init_progress_definition_sequence_diagram.md` so type `A` Step `7` no longer appears MCP-only
- [x] 3.5 Confirm downstream Step `8`, `8.1`, `8.2`, and `8.3` wording continues to depend on generated surface maps rather than direct blueprint reads

## 4. Backend Step 7 Tests

- [x] 4.1 Add backend tests proving type `A` with no ready repo and approved backend blueprint invokes the model and writes `project_surface_struct_resp_map_backend.md`
- [x] 4.2 Add backend tests proving type `A` with a partially materialized ready backend repo uses repo evidence for materialized rows and planned blueprint evidence for unmaterialized rows in the same surface map
- [x] 4.3 Add backend tests proving type `A` without ready repo or backend blueprint fails before model invocation
- [x] 4.4 Add backend prompt assertions for planned blueprint evidence wording and the `<to be defined during implementation>` fallback instruction
- [x] 4.5 Add backend regression assertions proving type `B` and `C` do not bind stack blueprints

## 5. Frontend And Mobile Step 7 Tests

- [x] 5.1 Add frontend tests proving type `A` with no ready repo and approved frontend blueprint invokes the model and writes `project_surface_struct_resp_map_frontend.md`
- [x] 5.2 Add mobile tests proving type `A` with no ready repo and approved mobile blueprint invokes the model and writes `project_surface_struct_resp_map_mobile.md`
- [x] 5.3 Add mixed target tests proving type `A` can use repo evidence for one active class, blueprint evidence for another active class, and repo-plus-blueprint fallback within a partially materialized class
- [x] 5.4 Add frontend/mobile prompt assertions for planned blueprint evidence wording and placeholder fallback instructions
- [x] 5.5 Add frontend/mobile regression assertions proving type `B` and `C` behavior is unchanged

## 6. Verification

- [x] 6.1 Run `bash tests/ai_scripts/feature_repo_surface_and_exec_context_be_tests.sh`
- [x] 6.2 Run `bash tests/ai_scripts/feature_repo_surface_and_exec_context_fe_tests.sh`
- [x] 6.3 Run `bash tests/ai_scripts/init_progress_scanner_tests.sh`
- [x] 6.4 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh`
- [x] 6.5 Run `openspec validate crp-117-type-a-step-7-blueprint-fallback-evidence --strict`
