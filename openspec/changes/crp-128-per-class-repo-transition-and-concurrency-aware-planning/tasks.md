> **Executor instructions — read first.**
> 1. Read `design.md` in this folder before starting; tasks cite its decisions as (D1)…(D9).
> 2. Execute sections in order; inside a section, execute tasks in order. One task = one focused change.
> 3. Plain shell only for `.sh` files. Do not add new CLI flags to existing scripts. New helper scripts use the argument forms written in the task.
> 4. Sections 6 and 7 are **not for execution** — read their banners.
> 5. After finishing each of sections 1–5, run the tests listed for it in section 9 before moving on.
> 6. All literal strings in backticks must be used exactly as written.

## 1. Shared Helpers

- [ ] 1.1 Create `overmind/scripts/helper/check_implementation_plan_readiness.sh` taking one argument `--feature_path <abs path>`. Move the existing plan-parse logic (the awk `fail_readiness` checks: at least one `### Step` block; every step has exactly one `#### Repo:` with a supported class) out of `overmind/scripts/feature_assing_workers.sh` into this helper. Exit 0 when the plan parses, non-zero with the existing error text otherwise.
- [ ] 1.2 Update `overmind/scripts/feature_assing_workers.sh` to call the new helper for its readiness check. Behavior must be unchanged — run `bash tests/ai_scripts/feature_assign_workers_to_implementation_plan_tests.sh` to confirm.
- [ ] 1.3 Create `overmind/scripts/helper/list_committed_sibling_features.sh` taking `--feature_path <abs path>`. It prints, one per line, the folder names of sibling feature folders under the same `projects/<project-id>/` that: (a) are not the current feature folder, (b) contain `implementation_plan.md`, (c) do not contain a file named `feature_abandoned.marker`, (d) have at least one unchecked box `- [ ]` in `implementation_plan.md` (otherwise the feature is complete), (e) pass `check_implementation_plan_readiness.sh`. Empty output and exit 0 when none qualify. This implements promise eligibility (D7): a feature emits promises only when planning is fully finished.
- [ ] 1.4 Create `overmind/scripts/helper/check_repo_on_default_branch.sh` taking one positional argument `<repo-path>`. If `git -C <repo-path> rev-parse --abbrev-ref HEAD` is neither `main` nor `master`, print exactly `WARN: <repo-path> is not on its default branch; planning reads merged truth only (D7)` to stderr. Always exit 0 (warn-only, never blocks).

## 2. Per-Class Transition (D1, D2, D6)

- [ ] 2.1 Create `overmind/scripts/helper/persist_class_repo_attach.sh` taking three positional arguments `<project-path> <class> <repo-path>`. It validates `<repo-path>` is an existing directory containing `.git`, resolves it to an absolute path, and persists into `<project-path>/init_progress_definition.yaml` under `meta_info.class_repo_paths.<class>`: `state: "ready"`, `path: "<abs path>"`, `policy: "C"`. Reuse the persistence approach already in `overmind/scripts/project_mgmt/project_setup_update_project.sh`.
- [ ] 2.2 Update `overmind/scripts/project_mgmt/project_setup_update_project.sh` to call `persist_class_repo_attach.sh` for its attach write (so both flows share one writer) and therefore also record `policy: "C"`.
- [ ] 2.3 Update `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`: before running the progress scanner, for each class in `meta_info.class_repo_paths` whose `state` is not `"ready"` and for which `<project-path>/project_stack_blueprint_<class>.md` exists, read `planned_repo_path` from that blueprint's §1 Meta. If that path is a directory containing `.git`, prompt exactly:
  `Class '<class>' blueprint declares planned repo path <path> and a scannable repository exists there. Attach it and switch this class to repo-backed (policy C: repo becomes authoritative; blueprint is consulted only for subsystems absent from the repo)? [y/n/other path]`
  On `y` call `persist_class_repo_attach.sh`; on `n` continue silently; on any other input treat it as an alternate repo path and validate+attach via the same helper; on invalid path re-prompt once then continue.
- [ ] 2.4 Update `overmind/scripts/feature_scan_repo_for_br.sh` (step `4.1`): find the existing project-type guard (search the script for `project_type`) and replace it with per-class gating — scan every class whose `class_repo_paths.<class>.state` is `"ready"`; skip non-ready classes; the step is a no-op only when no class is ready.
- [ ] 2.5 Update `overmind/scripts/feature_contract_delta.sh` (step `6`) the same way: per-class gating on `state: "ready"` replaces any `project_type` conditional (search for `project_type`).
- [ ] 2.6 Update `overmind/scripts/feature_repo_surface_and_exec_context.sh` (step `7`): remove remaining `project_type_code` branching (search for `project_type`). New rule per class: when `state` is `"ready"`, repo scan is the primary source; whenever `<project-path>/project_stack_blueprint_<class>.md` exists (any project type), bind it as the `Stack blueprint source:` fallback context line. Per-row precedence stays as in the rule file (task 3.1).
- [ ] 2.7 Update `overmind/templates/init_progress_definition_TEMPLATE.yaml`: in the `finished_only_if_conditions_meet` blocks of steps `4.1`, `6`, and `7`, replace project-type wording with per-class wording ("classes with `state: \"ready\"` are scanned; classes with a project stack blueprint use it as fallback evidence"). Add one sentence to step 1's conditions: `project_type_code records how the project started and is not read by feature-phase steps.` (D1)
- [ ] 2.8 Create `overmind/scripts/project_mgmt/project_contract_reconciliation.sh` taking `--path <asdlc/projects/<project-id>>`. This is a model-driven prompt step (copy the prompt-build/commit pattern from `overmind/scripts/init_common_contract_definition.sh`): bind `common_contract_definition.md` plus all ready repo paths; the model lists mismatches between the documented contract and the as-built API; the operator approves corrections interactively; approved corrections are written back and committed. Script header comment must contain exactly: `Stopgap (D6): clears blueprint-era contract drift once per class attach; ongoing drift is the feedback loop's job.`
- [ ] 2.9 Update `project_add_feature_e2e.sh`: immediately after a successful attach in task 2.3, if `<project-path>/.contract_reconciled_<class>` does not exist, run `project_contract_reconciliation.sh --path <project-path>` and then create the empty marker file `<project-path>/.contract_reconciled_<class>`.

## 3. Permanent Evidence Chain & Policy C (D3, D5)

- [ ] 3.1 Update `overmind/rules/feature_repo_surface_and_exec_context_rule.md`: replace the type-`A`-only fallback narrative with the permanent per-class, per-row resolution chain: repo scan → in-flight feature promises (task 4.1) → blueprint (`(planned)` tag) → literal `<to be defined during implementation>`. One source per row; every non-repo source tagged. Add the demand-driven sentence: `The chain runs only for surfaces this feature's requirements touch; "absent" means this feature's need is not satisfied, never an inventory claim about the repo.`
- [ ] 3.2 Same rule file: blueprint evidence citations must append the blueprint's §1 `last_updated` value, format exactly: `project_stack_blueprint_<class>.md §<n> (last_updated: <YYYY-MM-DD>)`.
- [ ] 3.3 Same rule file plus `overmind/templates/project_surface_struct_resp_map_be_TEMPLATE.md` and `..._fe_TEMPLATE.md`: define an optional single line allowed in any §3.x layer block, format exactly: `divergence_note: diverges from project_stack_blueprint_<class>.md §<n> — <short reason>`. It is written when the layer is materialized in the repo but does not match the blueprint's §3 bindings; the row still resolves from the repo (policy `C`, D5). Never required, never prompts, never blocks.
- [ ] 3.4 Verify `overmind/scripts/helper/check_feature_repo_surface_and_exec_context_be_quality.sh` and `..._fe_quality.sh` do not fail when a `divergence_note:` line is present (fix only if they do).
- [ ] 3.5 Same rule file: add one sentence: `A blueprint is never retired; it remains fallback evidence for unmaterialized layers for the life of the project.`

## 4. Promise Tier (D7)

- [ ] 4.1 Update `overmind/scripts/feature_repo_surface_and_exec_context.sh`: call `list_committed_sibling_features.sh`; for each returned folder, bind a read-only context line `In-flight plan source: <folder>/implementation_plan.md` into the prompt. Update the rule file (same as task 3.1's chain): rows resolved from a sibling plan carry the tag `(in-flight <feature-folder>)` and evidence cites `<feature-folder>/implementation_plan.md step <step-id>`.
- [ ] 4.2 Update `overmind/rules/prerequisite_gaps_rule.md`, `overmind/templates/prerequisite_gaps_TEMPLATE.md`, and `overmind/scripts/feature_prerequisite_gaps.sh` (step `8.2`): add the classification value `scheduled_in_feature <feature-folder>/<step-id>` alongside `present_in_repo`, `scheduled_in_slices`, `unmet`. The script binds sibling plans via `list_committed_sibling_features.sh`. The quality gate continues to reject only `unmet`.
- [ ] 4.3 Update `overmind/scripts/helper/check_prerequisite_gaps_quality.sh` (exact filename: locate via `tests/ai_scripts/check_prerequisite_gaps_quality_tests.sh`) to accept the new classification value as valid.
- [ ] 4.4 Update `overmind/templates/implementation_plan_TEMPLATE.md` and `overmind/rules/implementation_plan_rule.md`: `#### Depends on:` entries containing a `/` are cross-feature references with format exactly `<feature-folder>/<step-id>` (example: `0003_customer_accounts/3.2`); entries without `/` remain same-feature step ids. Update the template's Format Rules line for `#### Depends on:` accordingly.
- [ ] 4.5 Update `overmind/scripts/feature_contract_delta.sh`: for each folder from `list_committed_sibling_features.sh` that contains `feature_contract_delta.md`, bind it as read-only context line `Pending contract delta source: <folder>/feature_contract_delta.md`. Add one paragraph to `overmind/rules/feature_contract_delta_rule.md`: pending sibling deltas are evidence of in-flight contract claims; the delta must not silently contradict them — overlaps are reported, not resolved, at this step.
- [ ] 4.6 Update `feature_scan_repo_for_br.sh`, `feature_contract_delta.sh`, `feature_repo_surface_and_exec_context.sh`, and `feature_prerequisite_gaps.sh`: before scanning any ready repo path, call `check_repo_on_default_branch.sh <path>` (warn-only, from task 1.4).

## 5. Assignment Gate & Collision Check (D7)

- [ ] 5.1 Update `overmind/scripts/feature_assing_workers.sh`: when a step's `#### Depends on:` contains a cross-feature entry `<feature-folder>/<step-id>`: resolve `../<feature-folder>/implementation_plan.md` relative to the feature folder. The dependency is **complete** when that file exists, contains a `### Step <step-id>` block, and every checklist box in that block is `- [x]`. If the sibling folder contains `feature_abandoned.marker`, write exactly `#### Assigned: hold: depends on <feature-folder>/<step-id> (feature abandoned)`. If not complete, write exactly `#### Assigned: hold: depends on <feature-folder>/<step-id>`. Holds are reported in the final summary the same way as the existing class-availability issues. Re-running the script re-evaluates every hold (idempotent).
- [ ] 5.2 Create `overmind/scripts/helper/check_cross_feature_collisions.sh` taking `--feature_path <abs path>`. Mechanical token comparison, no model call: extract `user_reachable_surface` tokens from the current feature's `project_surface_struct_resp_map_*.md` §4 rows and endpoint/surface tokens from its `feature_contract_delta.md`; compare for exact-string matches against the same artifacts of every folder returned by `list_committed_sibling_features.sh`. Write `cross_feature_collisions.md` into the feature folder; each finding is one line, format exactly: `concurrently_touched_by: <feature-folder> — <token>`, with surface-map matches under heading `## Surface overlaps` and delta matches under `## Contract conflicts`. Write the file with only headings when there are no matches. Always exit 0.
- [ ] 5.3 Update `overmind/scripts/feature_implementation_plan.sh` (step `8.3`): after its quality gate passes, run `check_cross_feature_collisions.sh --feature_path <feature-path>` (this is the plan-commit moment, D7).
- [ ] 5.4 Update `project_add_feature_e2e.sh`: after step `8.3` completes, if `cross_feature_collisions.md` has any line under `## Contract conflicts`, print those lines and prompt `Contract conflicts with in-flight features detected. Continue anyway? [y/n]`; on `n`, stop before step `8.4`. Surface overlaps are not prompted here.
- [ ] 5.5 Update `overmind/rules/implementation_plan_semantic_review_rule.md`: when `cross_feature_collisions.md` exists and has findings, the step `8.4` review must read it and raise each `## Surface overlaps` line as a product-fit finding (apply/reject with resolution notes, existing pattern).
- [ ] 5.6 Update `project_add_feature_e2e.sh`: in the existing unfinished-feature selection menu, add option `mark a feature abandoned`; on selection, write `<feature-folder>/feature_abandoned.marker` containing one line `abandoned: <YYYY-MM-DD> — <operator-entered reason>`. Folders with this marker are excluded from the "continue a feature" list.
- [ ] 5.7 Degenerate-case check (D7): with zero committed siblings, confirm by test run that sections 4–5 add no context lines, no holds, and an empty-headings `cross_feature_collisions.md` — behavior otherwise identical to pre-CRP.

## 6. Phase 2 — Policy B

> **DO NOT EXECUTE.** Phase 2 scope, pending operator decision; kept here so the umbrella record is complete (D5, D8). Likely split into its own CRP.

- [ ] 6.1 Interactive divergence-review finding type on the step `8.4` pattern; bounded criteria: §2 stack choices and §3 archetypes only, never style.
- [ ] 6.2 Two-state resolution only: blueprint edit, or scheduled alignment step. No waiver registry.
- [ ] 6.3 Retroactive blueprint authoring for born-`B` projects.
- [ ] 6.4 Revisit parked question: `B` as project type vs per-class config flag.

## 7. Worker Coordination

> **COORDINATION ONLY — DO NOT IMPLEMENT IN THIS REPO.** These land in the yasdef worker repository (D4).

- [ ] 7.1 Specify the `already_satisfied` worker step outcome (worker records why; step closes without work) and hand it to the worker project.

## 8. Docs & Maintenance

- [ ] 8.1 Update `overmind/README.md`: per-class transition lifecycle (D1); policy `C` semantics and the policy field; the scanned-ref convention and the operator merge discipline — accepted work must be merged to the repo's default branch before the next feature plans against it (D7); promise tier, cross-feature `Depends on:` syntax, assignment holds, `feature_abandoned.marker`; `project_contract_reconciliation.sh` described as a stopgap (D6).
- [ ] 8.2 Update `CLAUDE.md`: add every new test file from section 9 to the test command list (maintenance rule in `CLAUDE.md`).

## 9. Tests

Run each file with `bash tests/ai_scripts/<name>` from the repo root. Extend existing files where named; create new files where named.

- [ ] 9.1 New `tests/ai_scripts/check_implementation_plan_readiness_tests.sh`: parseable plan exits 0; missing `#### Repo:` exits non-zero; run after section 1.
- [ ] 9.2 New `tests/ai_scripts/list_committed_sibling_features_tests.sh`: excludes self, abandoned-marker folders, fully-checked (complete) plans, and unparseable plans; includes a committed zero-steps-implemented sibling; empty output exit 0 when none. Run after section 1.
- [ ] 9.3 Extend `tests/ai_scripts/project_add_feature_e2e_tests.sh`: prompt fires for deferred class with scannable `planned_repo_path`; `n` leaves class deferred; alternate path attaches; non-existent planned path stays silent; `policy: "C"` persisted; reconciliation runs once then marker suppresses it; abandoned-menu writes the marker and the folder leaves the continue list. Run after sections 2 and 5.
- [ ] 9.4 Extend `tests/ai_scripts/init_scan_repo_for_br_tests.sh` and `tests/ai_scripts/init_feature_contract_delta_tests.sh`: mixed-state project (one class `ready`, one deferred) scans only the ready class; no project-type dependence. Run after section 2.
- [ ] 9.5 Extend `tests/ai_scripts/feature_repo_surface_and_exec_context_be_tests.sh` and `..._fe_tests.sh`: repo row real path; unmaterialized layer resolves from blueprint with `(planned)` and dated citation; `divergence_note:` line passes quality; in-flight promise row tagged `(in-flight <folder>)`. Run after sections 3 and 4.
- [ ] 9.6 Extend `tests/ai_scripts/init_feature_prerequisite_gaps_tests.sh`: sibling-committed surface classifies `scheduled_in_feature <folder>/<step-id>`, not `unmet`; quality gate accepts it. Run after section 4.
- [ ] 9.7 Extend `tests/ai_scripts/feature_assign_workers_to_implementation_plan_tests.sh`: incomplete cross-feature dependency → exact hold text; abandoned sibling → exact abandoned hold text; completed-and-checked dependency → normal assignment; re-run flips a hold to an assignment after the dependency completes. Run after section 5.
- [ ] 9.8 New `tests/ai_scripts/check_cross_feature_collisions_tests.sh`: exact-token surface overlap and contract conflict each produce their one-line finding under the correct heading; no siblings → headings-only file, exit 0. Run after section 5.
- [ ] 9.9 New `tests/ai_scripts/project_contract_reconciliation_tests.sh`: script binds contract + ready repos into the prompt and applies only operator-approved corrections (follow the existing model-driven test pattern, e.g. `init_common_contract_definition_tests.sh`). Run after section 2.
