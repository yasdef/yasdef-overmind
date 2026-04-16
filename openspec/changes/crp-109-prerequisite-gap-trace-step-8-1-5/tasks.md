## 1. Rule, Template, and Golden Example

- [ ] 1.1 Create `overmind/rules/prerequisite_gaps_rule.md` defining how to produce a valid `prerequisite_gaps.md` including field definitions for `status`, `evidence`, and `slice_ref`. Include the CRP-108 class taxonomy (frontend navigable routes/pages/screens; backend HTTP endpoints, CLI commands, scheduled jobs, admin tools; mobile screens/deep links) and explicitly exclude internal service-to-service dependencies from the trace scope — they remain covered by CRP-098 `gap/TECH_REQ-*` and `comp/*` tokens.
- [ ] 1.2 Create `overmind/templates/prerequisite_gaps_TEMPLATE.md` with the per-EARS-requirement structure and per-prerequisite field scaffold
- [ ] 1.3 Create `overmind/golden_examples/prerequisite_gaps_GOLDEN_EXAMPLE.md` demonstrating at least one `present_in_repo`, one `scheduled_in_slices`, and one resolved-from-`unmet` prerequisite entry. Include at least one backend example (for example, a scheduled-job prerequisite) alongside a frontend example so the class taxonomy is exercised.
- [ ] 1.4 In `overmind/rules/prerequisite_gaps_rule.md`, specify that `slice_ref` values SHALL match the slice identifiers used in `implementation_slices.md` exactly and SHALL be referenceable in plan steps as the evidence token `slice/<slice_ref>`, matching the regex `slice/[A-Za-z0-9][A-Za-z0-9_.-]*`

## 2. Generator Script

- [ ] 2.1 Create `overmind/scripts/feature_prerequisite_gaps.sh` that accepts a feature path and reads `requirements_ears.md`, `technical_requirements.md`, and `implementation_slices.md` as inputs
- [ ] 2.2 Implement prerequisite derivation logic: for each EARS requirement, derive externally-invocable prerequisites (per the CRP-108 class taxonomy) from the WHEN/THEN conditions and check `user_reachable_surface` entries in `technical_requirements.md`. Internal service-to-service dependencies SHALL NOT be emitted into `prerequisite_gaps.md`.
- [ ] 2.3 Implement status assignment: `present_in_repo` when a `user_reachable_surface` match exists; `scheduled_in_slices` when a matching slice exists in `implementation_slices.md`; `unmet` otherwise
- [ ] 2.4 Ensure script fails with a clear error message when any required input file (`requirements_ears.md`, `technical_requirements.md`, `implementation_slices.md`) is absent

## 3. Quality Helper for prerequisite_gaps.md

- [ ] 3.1 Create `overmind/scripts/helper/check_prerequisite_gaps_quality.sh` that accepts a `prerequisite_gaps.md` path
- [ ] 3.2 Implement: reject any entry with `status: unmet` and print the failing requirement and prerequisite name
- [ ] 3.3 Implement: require a non-empty `evidence` field for every `present_in_repo` entry
- [ ] 3.4 Implement: require a non-empty `slice_ref` for every `scheduled_in_slices` entry
- [ ] 3.5 Implement: print `quality gate passed` and exit 0 when all checks pass
- [ ] 3.6 Implement deterministic literal-extraction cross-check in `check_prerequisite_gaps_quality.sh`: parse `/...` URL paths, HTTP method+path pairs, CLI command tokens, and scheduled-job identifiers from `requirements_ears.md`; fail when any literal is absent from both `prerequisite_gaps.md` prerequisite entries and the `user_reachable_surface` subfield set in `technical_requirements.md`, printing the failing literal and its source requirement id

## 4. Extend Implementation Plan Quality Gate

- [ ] 4.1 Update `overmind/scripts/helper/check_implementation_plan_quality.sh` to read `prerequisite_gaps.md` from the feature path as a required sibling artifact
- [ ] 4.2 Extend the evidence-token validator in `check_implementation_plan_quality.sh` (currently accepts `gap/TECH_REQ-*` and `comp/*` at the token-format branch around lines 501–521) to also accept `slice/<id>` tokens matching the regex `slice/[A-Za-z0-9][A-Za-z0-9_.-]*`; register these as valid evidence-token formats alongside the existing two families
- [ ] 4.3 Add cross-check: collect `slice_ref` values from all `scheduled_in_slices` entries in `prerequisite_gaps.md`; fail with a named quality gate failure when any collected `slice_ref` is not present as a `slice/<slice_ref>` token in at least one plan step's `#### Evidence:` line, naming the uncovered `slice_ref` and its source requirement in the failure message
- [ ] 4.4 Emit a helper failure (exit code 2) when `prerequisite_gaps.md` is absent, consistent with how other missing sibling artifacts are handled

## 5. E2E Orchestrator Integration

- [ ] 5.1 Insert `"8.1.5"` into the `PHASE_IDS` array in `project_add_feature_e2e.sh` between `"8.1"` and `"8.2"`
- [ ] 5.2 Insert `"false"` into the `PHASE_OPTIONAL` array at the matching index
- [ ] 5.3 Add the step label `"Prerequisite Gap Trace"` for phase `8.1.5` in the label-lookup function
- [ ] 5.4 Add script name `feature_prerequisite_gaps.sh` for phase `8.1.5` in the script-name-lookup function
- [ ] 5.5 Add resume alias entries for `8.1.5`, `prerequisite-gap-trace`, and `prerequisite-gaps` in the resume-step normalization logic
- [ ] 5.6 Update the `--resume` help text to include `8.1.5` in the list of valid step identifiers

## 6. Progress Scanner and Definition Template

- [ ] 6.1 Update `overmind/scripts/project_mgmt/init_progress_scanner.sh` to detect `prerequisite_gaps.md` as the completion artifact for Step `8.1.5` and to recognize the step-name string `"run prerequisite gap trace"` for scanner-based step identification
- [ ] 6.2 Add a `step_number: 8.1.5` block to `overmind/templates/init_progress_definition_TEMPLATE.yaml` between the `8.1` and `8.2` blocks with `step_name: "Run Prerequisite Gap Trace"` and `finished_only_if_artefacts_present: prerequisite_gaps.md`

## 7. Plan Generator Context Input

- [ ] 7.1 Update `overmind/scripts/feature_implementation_plan.sh` to accept `prerequisite_gaps.md` as an additional context input so the plan generator is aware of which prerequisites are `scheduled_in_slices`, and to emit the evidence token `slice/<slice_ref>` on each plan step that covers a scheduled prerequisite (keeping the generator and `check_implementation_plan_quality.sh` in sync on the token format)

## 8. Setup Script Staging

- [ ] 8.1 Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` to stage `feature_prerequisite_gaps.sh` and `check_prerequisite_gaps_quality.sh` to the project `.commands/` directory
- [ ] 8.2 Update `overmind/scripts/project_mgmt/project_setup_update_project.sh` to propagate the same two scripts on project update

## 9. Documentation

- [ ] 9.1 Add a Step `8.1.5` node to `overmind/init_progress_definition_sequence_diagram.md` between the `8.1` and `8.2` alt blocks, showing input artifacts and output `prerequisite_gaps.md`
- [ ] 9.2 Update `overmind/README.md` to document Step `8.1.5`, its purpose, inputs, output, and gate condition

## 10. Tests

- [ ] 10.1 Create `tests/ai_scripts/check_prerequisite_gaps_quality_tests.sh` covering: all-resolved passes, unmet entry fails, missing evidence fails, missing slice_ref fails, slice_ref not resolving to an existing slice fails, missing input file fails, literal URL path in `requirements_ears.md` absent from both `prerequisite_gaps.md` and `user_reachable_surface` fails, backend scheduled-job identifier missing from both sources fails
- [ ] 10.2 Add Step `8.1.5` detection cases to `tests/ai_scripts/init_progress_scanner_tests.sh`: artifact present → finished, artifact absent after 8.1 → next step is 8.1.5
- [ ] 10.3 Add `scheduled_in_slices` prerequisite coverage cases to `tests/ai_scripts/check_implementation_plan_quality_tests.sh`: `slice/<id>` token accepted as valid evidence-token format, uncovered `slice_ref` fails, all covered passes, absent `prerequisite_gaps.md` emits helper failure, malformed `slice/<id>` token (regex violation) fails with invalid evidence token format
