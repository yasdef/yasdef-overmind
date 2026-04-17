## 1. Define the transport vs user-reachable contract

- [x] 1.1 Update `overmind/rules/feature_repo_surface_and_exec_context_rule.md` to require `transport_layer` and `user_reachable_surface` subfields on every Section 3 layer block and Section 4 surface block, define what counts as user-reachable per project class (frontend: routes/pages/screens; backend: operator-reachable endpoints, CLI commands, scheduled jobs; mobile: screens/deep links), and forbid restating transport coverage as user-reachable presence. State that `user_reachable_surface` is the contract CRP-109's prerequisite trace consumes as ground truth, and require each entry to be a concrete navigable token (route path, full HTTP method+path, CLI command name, job identifier) rather than prose.
- [x] 1.2 Update `overmind/rules/technical_requirements_rule.md` to require the same split inside `### Requirement:` blocks under `current_state`, with `none` as the explicit marker when one side is empty.
- [x] 1.3 Document that the helper rejects single-line conflated `current_state` entries.

## 2. Update templates and golden examples

- [x] 2.1 Update `overmind/templates/project_surface_struct_resp_map_fe_TEMPLATE.md` and `overmind/templates/project_surface_struct_resp_map_be_TEMPLATE.md` so every Section 3 and Section 4 block carries the two subfields.
- [x] 2.2 Update `overmind/templates/technical_requirements_TEMPLATE.md` so each requirement's `current_state` carries the two subfields.
- [x] 2.3 Update or add golden examples that demonstrate the split, including at least one frontend block and one backend block where `transport_layer` is populated and `user_reachable_surface` is `none` (for example, a backend row with `transport_layer: ReconciliationService.run()` and `user_reachable_surface: none` to show "transport exists, invocable surface missing").

## 3. Implement generation and helper enforcement

- [x] 3.1 Update `overmind/scripts/feature_repo_surface_and_exec_context.sh` so generated maps emit both subfields per block.
- [x] 3.2 Update `overmind/scripts/feature_technical_requirements.sh` so generated requirements emit both subfields per `current_state`.
- [x] 3.3 Add or update `overmind/scripts/helper/check_repo_surface_and_exec_context_quality.sh` to fail when any block is missing one of the subfields, when both subfields are present but blank, or when the single-line conflated form is used.
- [x] 3.4 Update `overmind/scripts/helper/check_technical_requirements_quality.sh` with the same checks against `current_state`.

## 4. Add automated coverage

- [x] 4.1 Update `tests/ai_scripts/feature_repo_surface_and_exec_context_tests.sh` with passing coverage for valid split form and failing coverage for missing/blank subfields and conflated single-line form.
- [x] 4.2 Update `tests/ai_scripts/feature_technical_requirements_tests.sh` with the same coverage against `current_state`.

## 5. Update pipeline documentation

- [x] 5.1 Update `overmind/init_progress_definition_sequence_diagram.md`: add a note to the Step `7` and Step `8` blocks indicating that both surface maps and `technical_requirements.md` now record `transport_layer` and `user_reachable_surface` as separate subfields; no step renumbering required for this change
- [x] 5.2 Update `overmind/templates/init_progress_definition_TEMPLATE.yaml`: add a `finished_only_if_conditions_meet` condition to the Step `7` and Step `8` entries stating that `user_reachable_surface` subfields are required in the produced artifacts alongside `transport_layer`

## 6. Validate change readiness

- [x] 6.1 Run the relevant `tests/ai_scripts/` suites for surface-map generation, technical-requirements generation, and their quality validators.
- [x] 6.2 Run `openspec status --change crp-108-surface-map-and-tech-req-transport-vs-user-reachable-split` and confirm the change is apply-ready.
