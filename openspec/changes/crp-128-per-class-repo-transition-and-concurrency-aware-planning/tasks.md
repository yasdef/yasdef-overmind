> **Executor instructions — read first.**
> 1. Read `design.md` in this folder before starting; tasks cite its decisions as (D1)…(D9).
> 2. Each numbered section is **one vertical slice** — an isolated, independently reviewable increment. Execute sections in order; inside a section, execute tasks in order. Finish the whole slice (behavior + its test + any docs it introduces) before starting the next.
> 3. The **last task in each slice is its test**. A slice is done only when that test passes (`bash tests/ai_scripts/<name>` from the repo root). Do not move on with a red slice.
> 4. Plain shell only for `.sh` files. Do not add new CLI flags to existing scripts. New helper scripts use the argument forms written in the task.
> 5. All literal strings in backticks must be used exactly as written.
> 6. Sections marked **DO NOT EXECUTE** (Phase 2, Worker Coordination) are umbrella-record only.
>
> Ordering rationale: the model is fixed in docs first (§1) so it cannot drift mid-implementation; shared helpers (§2, §3) land before their consumers; each later slice threads one data-model element through its consumers and proves it with a co-located test.

## 1. Target model — docs, sequence diagram, data model (no behavior change)

Goal: write the per-class / evidence-chain / concurrency model down first, so every later slice has a fixed reference. No script behavior changes in this slice.

- [ ] 1.1 Update `overmind/init_progress_definition_sequence_diagram.md`: in the **feature** phase, replace the `alt Type A / Type B/C` branches around steps `4.1`, `6`, `7`, `8`, `8.1`, `8.3` with per-class gating on `class_repo_paths[<class>].state`. Render step `7`'s evidence resolution as the chain `repo scan → in-flight feature promises → blueprint (planned) → placeholder`. Add a concurrency note that committed sibling plans are read as promises and that all repo scans read the default branch only. In the **init** phase, annotate that `project_type_code` is init-time bookkeeping that feature steps no longer read. (D1, D3, D7)
- [ ] 1.2 Update `overmind/templates/init_progress_definition_TEMPLATE.yaml` data model: document the `meta_info.class_repo_paths.<class>` shape with subfields `state`, `path`, `policy`. In the `finished_only_if_conditions_meet` blocks of steps `4.1`, `6`, and `7`, replace project-type wording with per-class wording ("classes with `state: \"ready\"` are scanned; classes with a project stack blueprint use it as fallback evidence"). Add one sentence to step 1's conditions: `project_type_code records how the project started and is not read by feature-phase steps.` (D1, D2)
- [ ] 1.3 Update `overmind/README.md` with the conceptual model (exact runtime strings are added later by the slices that introduce them): per-class transition lifecycle (D1); policy `C` semantics and the per-class `policy` field; the scanned-ref convention and operator merge discipline — accepted work must be merged to the repo's default branch before the next feature plans against it (D7); the promise tier (committed plans read by in-flight features), cross-feature `#### Depends on:` syntax, assignment holds, `feature_abandoned.marker`; `project_contract_reconciliation.sh` described as a stopgap (D6).
- [ ] 1.4 Review: read the diagram and README against `design.md`; confirm no project-type gating remains in the feature-phase narrative. No automated test for this slice (docs only).

## 2. Plan-readiness helper (extract + reuse)

Goal: one reusable "is this plan finished enough to be a promise / assignable" predicate, proven in isolation. Consumers in §3, §13, §14 depend on it.

- [ ] 2.1 Create `overmind/scripts/helper/check_implementation_plan_readiness.sh` taking one argument `--feature_path <abs path>`. Move the existing plan-parse logic (the awk `fail_readiness` checks: at least one `### Step` block; every step has exactly one `#### Repo:` with a supported class) out of `overmind/scripts/feature_assing_workers.sh` into this helper. Exit 0 when the plan parses, non-zero with the existing error text otherwise.
- [ ] 2.2 Update `overmind/scripts/feature_assing_workers.sh` to call the new helper for its readiness check. Behavior must be unchanged.
- [ ] 2.3 Test: new `tests/ai_scripts/check_implementation_plan_readiness_tests.sh` — parseable plan exits 0; missing `#### Repo:` exits non-zero. Re-run `tests/ai_scripts/feature_assign_workers_to_implementation_plan_tests.sh` to confirm assigner behavior is unchanged. Add `check_implementation_plan_readiness_tests.sh` to the test-command list in `CLAUDE.md`.

## 3. Committed-siblings lister (promise eligibility)

Goal: the single source of "which sibling features currently emit promises," proven in isolation. Implements promise eligibility (D7): a feature emits promises only when planning is fully finished. Depends on §2.

- [ ] 3.1 Create `overmind/scripts/helper/list_committed_sibling_features.sh` taking `--feature_path <abs path>`. It prints, one per line, the folder names of sibling feature folders under the same `projects/<project-id>/` that: (a) are not the current feature folder, (b) contain `implementation_plan.md`, (c) do not contain a file named `feature_abandoned.marker`, (d) have at least one unchecked box `- [ ]` in `implementation_plan.md` (otherwise the feature is complete), (e) pass `check_implementation_plan_readiness.sh`. Empty output and exit 0 when none qualify.
- [ ] 3.2 Test: new `tests/ai_scripts/list_committed_sibling_features_tests.sh` — excludes self, abandoned-marker folders, fully-checked (complete) plans, and unparseable plans; includes a committed zero-steps-implemented sibling; empty output exit 0 when none. Add `list_committed_sibling_features_tests.sh` to the test-command list in `CLAUDE.md`.

## 4. Per-class attach (transition)

Goal: attach a deferred class to its now-scannable repo, end to end, from both entry points (D1, D2). Depends on §1's data model.

- [ ] 4.1 Create `overmind/scripts/helper/persist_class_repo_attach.sh` taking three positional arguments `<project-path> <class> <repo-path>`. It validates `<repo-path>` is an existing directory containing `.git`, resolves it to an absolute path, and persists into `<project-path>/init_progress_definition.yaml` under `meta_info.class_repo_paths.<class>`: `state: "ready"`, `path: "<abs path>"`, `policy: "C"`. Reuse the persistence approach already in `overmind/scripts/project_mgmt/project_setup_update_project.sh`.
- [ ] 4.2 Update `overmind/scripts/project_mgmt/project_setup_update_project.sh` to call `persist_class_repo_attach.sh` for its attach write (so both flows share one writer) and therefore also record `policy: "C"`.
- [ ] 4.3 Update `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`: before running the progress scanner, for each class in `meta_info.class_repo_paths` whose `state` is not `"ready"` and for which `<project-path>/project_stack_blueprint_<class>.md` exists, read `planned_repo_path` from that blueprint's §1 Meta. If that path is a directory containing `.git`, prompt exactly:
  `Class '<class>' blueprint declares planned repo path <path> and a scannable repository exists there. Attach it and switch this class to repo-backed (policy C: repo becomes authoritative; blueprint is consulted only for subsystems absent from the repo)? [y/n/other path]`
  On `y` call `persist_class_repo_attach.sh`; on `n` continue silently; on any other input treat it as an alternate repo path and validate+attach via the same helper; on invalid path re-prompt once then continue.
- [ ] 4.4 Test: extend `tests/ai_scripts/project_add_feature_e2e_tests.sh` — prompt fires for a deferred class with a scannable `planned_repo_path`; `n` leaves the class deferred; an alternate path attaches; a non-existent planned path stays silent; `policy: "C"` is persisted.

## 5. Per-class gating of scan-dependent steps

Goal: steps `4.1`, `6`, `7` gate on per-class `state`, never on `project_type_code` (D2). Depends on §4 (a class must be attachable to `ready`).

- [ ] 5.1 Update `overmind/scripts/feature_scan_repo_for_br.sh` (step `4.1`): find the existing project-type guard (search the script for `project_type`) and replace it with per-class gating — scan every class whose `class_repo_paths.<class>.state` is `"ready"`; skip non-ready classes; the step is a no-op only when no class is ready.
- [ ] 5.2 Update `overmind/scripts/feature_contract_delta.sh` (step `6`) the same way: per-class gating on `state: "ready"` replaces any `project_type` conditional (search for `project_type`).
- [ ] 5.3 Update `overmind/scripts/feature_repo_surface_and_exec_context.sh` (step `7`): remove remaining `project_type_code` branching (search for `project_type`). New rule per class: when `state` is `"ready"`, repo scan is the primary source; whenever `<project-path>/project_stack_blueprint_<class>.md` exists (any project type), bind it as the `Stack blueprint source:` fallback context line. Per-row precedence stays as in the rule file (§7).
- [ ] 5.4 Test: extend `tests/ai_scripts/init_scan_repo_for_br_tests.sh` and `tests/ai_scripts/init_feature_contract_delta_tests.sh` — a mixed-state project (one class `ready`, one deferred) scans only the ready class; no project-type dependence.

## 6. First-attach contract reconciliation (stopgap, D6)

Goal: clear blueprint-era contract drift once, the first time a class attaches. Depends on §4.

- [ ] 6.1 Create `overmind/scripts/project_mgmt/project_contract_reconciliation.sh` taking `--path <asdlc/projects/<project-id>>`. This is a model-driven prompt step (copy the prompt-build/commit pattern from `overmind/scripts/init_common_contract_definition.sh`): bind `common_contract_definition.md` plus all ready repo paths; the model lists mismatches between the documented contract and the as-built API; the operator approves corrections interactively; approved corrections are written back and committed. Script header comment must contain exactly: `Stopgap (D6): clears blueprint-era contract drift once per class attach; ongoing drift is the feedback loop's job.`
- [ ] 6.2 Update `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`: immediately after a successful attach in task 4.3, if `<project-path>/.contract_reconciled_<class>` does not exist, run `project_contract_reconciliation.sh --path <project-path>` and then create the empty marker file `<project-path>/.contract_reconciled_<class>`.
- [ ] 6.3 Test: new `tests/ai_scripts/project_contract_reconciliation_tests.sh` — script binds the contract + ready repos into the prompt and applies only operator-approved corrections (follow the existing model-driven test pattern, e.g. `init_common_contract_definition_tests.sh`). Extend `tests/ai_scripts/project_add_feature_e2e_tests.sh` to assert reconciliation runs once, then the marker suppresses it on the next run. Add `project_contract_reconciliation_tests.sh` to the test-command list in `CLAUDE.md`.

## 7. Permanent evidence chain (surface rule, D3)

Goal: generalize the CRP-117 type-`A`-only fallback into the permanent per-class, per-layer chain.

- [ ] 7.1 Update `overmind/rules/feature_repo_surface_and_exec_context_rule.md`: replace the type-`A`-only fallback narrative with the permanent per-class, per-row resolution chain: repo scan → in-flight feature promises (§10) → blueprint (`(planned)` tag) → literal `<to be defined during implementation>`. One source per row; every non-repo source tagged. Add the demand-driven sentence: `The chain runs only for surfaces this feature's requirements touch; "absent" means this feature's need is not satisfied, never an inventory claim about the repo.`
- [ ] 7.2 Same rule file: blueprint evidence citations must append the blueprint's §1 `last_updated` value, format exactly: `project_stack_blueprint_<class>.md §<n> (last_updated: <YYYY-MM-DD>)`.
- [ ] 7.3 Same rule file: add one sentence: `A blueprint is never retired; it remains fallback evidence for unmaterialized layers for the life of the project.`
- [ ] 7.4 Test: extend `tests/ai_scripts/feature_repo_surface_and_exec_context_be_tests.sh` and `..._fe_tests.sh` — a repo-resolved row carries the real path; an unmaterialized layer resolves from the blueprint with `(planned)` and a dated citation.

## 8. Policy C divergence tagging (D5)

Goal: a materialized-but-divergent layer resolves from the repo silently with a passive tag.

- [ ] 8.1 Update `overmind/rules/feature_repo_surface_and_exec_context_rule.md`, `overmind/templates/project_surface_struct_resp_map_be_TEMPLATE.md`, and `..._fe_TEMPLATE.md`: define an optional single passive line allowed in any §3.x layer block, format exactly: `divergent_from_blueprint: §<n>` (the blueprint §3 section the materialized layer diverges from). It is written when the layer is materialized in the repo but does not match the blueprint's §3 bindings; the row still resolves from the repo (policy `C`, D5). Never required, never prompts, never blocks.
- [ ] 8.2 Verify `overmind/scripts/helper/check_feature_repo_surface_and_exec_context_be_quality.sh` and `..._fe_quality.sh` do not fail when a `divergent_from_blueprint:` line is present (fix only if they do).
- [ ] 8.3 Test: extend `tests/ai_scripts/feature_repo_surface_and_exec_context_be_tests.sh` and `..._fe_tests.sh` — a `divergent_from_blueprint: §<n>` line passes the quality gate.

## 9. Merged-truth scan discipline (committed default branch, D7)

Goal: all planning scans read the **committed default branch only** — not the working tree. A ready class repo that is off its default branch *or* has uncommitted changes is refused, never scanned, so worker branches and uncommitted edits are invisible to planning (`proposal.md:27` "SHALL read the default branch only"; `design.md:65`). This is a precondition gate, not a product-judgment gate — reading a worker branch or dirty worktree would silently corrupt merged-truth evidence, so it is the one place enforcement is correct.

- [ ] 9.1 Create `overmind/scripts/helper/check_repo_on_default_branch.sh` taking one positional argument `<repo-path>`. Resolve the repo's default branch (`main` or `master`, whichever the repo has) and enforce two preconditions: (a) `git -C <repo-path> rev-parse --abbrev-ref HEAD` equals the default branch; (b) `git -C <repo-path> status --porcelain` is empty (no staged, unstaged, or untracked changes). If (a) fails, print exactly `BLOCKED: <repo-path> is not on its default branch; planning reads merged truth only (D7) — check out the default branch and rerun` to stderr and exit non-zero. If (a) holds but (b) fails, print exactly `BLOCKED: <repo-path> has uncommitted changes; planning reads committed merged truth only (D7) — commit or stash and rerun` to stderr and exit non-zero. When both hold, print nothing and exit 0. No worktree/checkout side effects on the operator's repo.
- [ ] 9.2 Update `feature_scan_repo_for_br.sh`, `feature_contract_delta.sh`, `feature_repo_surface_and_exec_context.sh`, and `feature_prerequisite_gaps.sh`: before scanning any ready repo path, call `check_repo_on_default_branch.sh <path>`; on non-zero, stop the step for that run with the helper's message and produce no partial artifact. Because the gate guarantees a clean default-branch worktree, the files these steps read off `<path>` equal committed merged truth. Re-running after the repo is on a clean default branch proceeds normally.
- [ ] 9.3 Test: in `tests/ai_scripts/init_scan_repo_for_br_tests.sh`, a ready class repo on a non-default branch makes the step stop with the exact `BLOCKED:` not-on-default message and write no artifact; a repo on `main`/`master` but with an uncommitted change stops with the exact `BLOCKED:` uncommitted-changes message; a clean repo on `main`/`master` scans normally.

## 10. Promise tier — surface-map binding (D7)

Goal: in-flight sibling plans become an evidence tier in the surface step. Depends on §3, §7.

- [ ] 10.1 Update `overmind/scripts/feature_repo_surface_and_exec_context.sh`: call `list_committed_sibling_features.sh`; for each returned folder, bind a read-only context line `In-flight plan source: <folder>/implementation_plan.md` into the prompt. Update `overmind/rules/feature_repo_surface_and_exec_context_rule.md` (the §7.1 chain): rows resolved from a sibling plan carry the tag `(in-flight <feature-folder>)` and evidence cites `<feature-folder>/implementation_plan.md step <step-id>`.
- [ ] 10.2 Test: extend `tests/ai_scripts/feature_repo_surface_and_exec_context_be_tests.sh` and `..._fe_tests.sh` — a row resolved from a committed sibling plan is tagged `(in-flight <folder>)`.

## 11. Promise tier — prerequisite gaps (D7)

Goal: step `8.2` learns the cross-feature classification. Depends on §3.

- [ ] 11.1 Update `overmind/rules/prerequisite_gaps_rule.md`, `overmind/templates/prerequisite_gaps_TEMPLATE.md`, and `overmind/scripts/feature_prerequisite_gaps.sh` (step `8.2`): add the classification value `scheduled_in_feature <feature-folder>/<step-id>` alongside `present_in_repo`, `scheduled_in_slices`, `unmet`. The script binds sibling plans via `list_committed_sibling_features.sh`. The quality gate continues to reject only `unmet`.
- [ ] 11.2 Update `overmind/scripts/helper/check_prerequisite_gaps_quality.sh` to accept the new classification value as valid.
- [ ] 11.3 Test: extend `tests/ai_scripts/init_feature_prerequisite_gaps_tests.sh` — a sibling-committed surface classifies as `scheduled_in_feature <folder>/<step-id>`, not `unmet`; the quality gate accepts it.

## 12. Promise tier — pending contract deltas (D7)

Goal: step `6` reads in-flight sibling contract deltas as evidence, reporting (not resolving) overlaps. Depends on §3.

- [ ] 12.1 Update `overmind/scripts/feature_contract_delta.sh`: for each folder from `list_committed_sibling_features.sh` that contains `feature_contract_delta.md`, bind it as a read-only context line `Pending contract delta source: <folder>/feature_contract_delta.md`. Add one paragraph to `overmind/rules/feature_contract_delta_rule.md`: pending sibling deltas are evidence of in-flight contract claims; the delta must not silently contradict them — overlaps are reported, not resolved, at this step.
- [ ] 12.2 Test: extend `tests/ai_scripts/init_feature_contract_delta_tests.sh` — with a committed sibling holding `feature_contract_delta.md`, the `Pending contract delta source: <folder>/feature_contract_delta.md` context line is bound into the prompt.

## 13. Cross-feature assignment gate (D7)

Goal: the plan's `#### Depends on:` learns cross-feature syntax, and assignment deterministically holds steps whose cross-feature dependencies are not complete-and-merged. Depends on §2, §3.

- [ ] 13.1 Update `overmind/templates/implementation_plan_TEMPLATE.md` and `overmind/rules/implementation_plan_rule.md`: `#### Depends on:` entries containing a `/` are cross-feature references with format exactly `<feature-folder>/<step-id>` (example: `0003_customer_accounts/3.2`); entries without `/` remain same-feature step ids. Update the template's Format Rules line for `#### Depends on:` accordingly.
- [ ] 13.2 Update `overmind/scripts/feature_assing_workers.sh`: when a step's `#### Depends on:` contains a cross-feature entry `<feature-folder>/<step-id>`: resolve `../<feature-folder>/implementation_plan.md` relative to the feature folder. The dependency is **complete** when that file exists, contains a `### Step <step-id>` block, and every checklist box in that block is `- [x]`. If the sibling folder contains `feature_abandoned.marker`, write exactly `#### Assigned: hold: depends on <feature-folder>/<step-id> (feature abandoned)`. If not complete, write exactly `#### Assigned: hold: depends on <feature-folder>/<step-id>`. Holds are reported in the final summary the same way as the existing class-availability issues. Re-running the script re-evaluates every hold (idempotent).
- [ ] 13.3 Test: extend `tests/ai_scripts/feature_assign_workers_to_implementation_plan_tests.sh` — an incomplete cross-feature dependency → exact hold text; an abandoned sibling → exact abandoned hold text; a completed-and-checked dependency → normal assignment; re-running flips a hold to an assignment after the dependency completes.

## 14. Cross-feature collision check (D7)

Goal: a mechanical collision detector that runs at the plan-commit moment, checked against **existing promises and merged truth** (`proposal.md:29`, `design.md:71`). Depends on §3.

- [ ] 14.1 Create `overmind/scripts/helper/check_cross_feature_collisions.sh` taking `--feature_path <abs path>`. Mechanical token comparison, no model call. Extract the current feature's tokens: `user_reachable_surface` tokens from its `project_surface_struct_resp_map_*.md` §4 rows, and endpoint/surface tokens from its `feature_contract_delta.md`. Compare those tokens for exact-string matches against **two sources**:
  - **Promises** — the same artifacts (`project_surface_struct_resp_map_*.md` §4, `feature_contract_delta.md`) of every folder returned by `list_committed_sibling_features.sh`. Each match is one line, format exactly: `concurrently_touched_by: <feature-folder> — <token>`.
  - **Merged truth** — exact-string presence of the token in the **committed default-branch tree** of each ready `class_repo_paths.<class>.path`, read via `git -C <repo-path> grep -F -e <token> <default-branch>` (searches tracked files at the committed ref only — never the worktree, untracked files, or `.git/`/build dirs; §9 already guarantees the repo is on a clean default branch). Each match is one line, format exactly: `already_in_merged_truth: <class> — <token>`.
  Surface-map matches (both sources) go under heading `## Surface overlaps`; contract-delta/endpoint matches (both sources) go under `## Contract conflicts`. Write `cross_feature_collisions.md` into the feature folder; write it with only the two headings when there are no matches. Always exit 0.
- [ ] 14.2 Update `overmind/scripts/feature_implementation_plan.sh` (step `8.3`): after its quality gate passes, run `check_cross_feature_collisions.sh --feature_path <feature-path>` (this is the plan-commit moment, D7).
- [ ] 14.3 Test: new `tests/ai_scripts/check_cross_feature_collisions_tests.sh` — an exact-token surface overlap and an exact-token contract conflict from a committed sibling each produce their `concurrently_touched_by:` line under the correct heading; a token already present on a ready repo's default branch produces its `already_in_merged_truth:` line under the correct heading; no siblings and no merged matches → a headings-only file, exit 0. Add `check_cross_feature_collisions_tests.sh` to the test-command list in `CLAUDE.md`.

## 15. Collision consumption (e2e prompt + semantic review)

Goal: surface overlaps become step `8.4` findings; contract conflicts become an immediate e2e prompt. Neither hard-blocks. Depends on §14.

- [ ] 15.1 Update `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`: after step `8.3` completes, if `cross_feature_collisions.md` has any line under `## Contract conflicts`, print those lines and prompt `Contract conflicts with in-flight features detected. Continue anyway? [y/n]`; on `n`, stop before step `8.4`. Surface overlaps are not prompted here.
- [ ] 15.2 Update `overmind/scripts/feature_implementation_plan_semantic_review.sh` (step `8.4`): in `prepare_readonly_inputs`, when `<feature-path>/cross_feature_collisions.md` exists, add it to the read-only inputs bound into the prompt (alongside the existing project-definition / requirements / technical-requirements / prerequisite-gaps / surface-map inputs) so the review can actually read it. It stays read-only — include it in the snapshot/unchanged check. Without this, the rule change in 15.3 has no file to read.
- [ ] 15.3 Update `overmind/rules/implementation_plan_semantic_review_rule.md`: when `cross_feature_collisions.md` exists and has findings, the step `8.4` review must read it and raise each `## Surface overlaps` line as a product-fit finding (apply/reject with resolution notes, existing pattern).
- [ ] 15.4 Test: extend `tests/ai_scripts/project_add_feature_e2e_tests.sh` — when `cross_feature_collisions.md` has a `## Contract conflicts` line, the continue prompt fires before step `8.4`; `n` stops the run before `8.4`. Extend `tests/ai_scripts/init_feature_implementation_plan_semantic_review_tests.sh` — when `cross_feature_collisions.md` is present, it is bound as a read-only input to step `8.4`.

## 16. Abandoned-feature marker

Goal: the operator can mark a feature abandoned; abandoned folders leave the continue list and turn cross-feature dependents into abandoned holds (§13). Depends on §13.

- [ ] 16.1 Update `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`: in the existing unfinished-feature selection menu, add option `mark a feature abandoned`; on selection, write `<feature-folder>/feature_abandoned.marker` containing one line `abandoned: <YYYY-MM-DD> — <operator-entered reason>`. Folders with this marker are excluded from the "continue a feature" list.
- [ ] 16.2 Test: extend `tests/ai_scripts/project_add_feature_e2e_tests.sh` — the abandoned-menu option writes the marker and the folder leaves the continue list.

## 17. Degenerate-case verification (serial operation, D7)

Goal: confirm the design is strictly additive — with zero committed siblings, nothing changes versus pre-CRP.

- [ ] 17.1 With zero committed siblings (and no merged-truth token overlaps), confirm by test run that §10–§16 add no context lines, no holds, and produce an empty-headings `cross_feature_collisions.md` — behavior otherwise identical to pre-CRP. Cover this in `tests/ai_scripts/feature_repo_surface_and_exec_context_be_tests.sh`, `feature_assign_workers_to_implementation_plan_tests.sh`, and `check_cross_feature_collisions_tests.sh`.

## 18. Docs & maintenance reconciliation (final pass)

- [ ] 18.1 Re-read `overmind/README.md` against the now-built exact strings (attach prompt, hold texts, contract-conflict prompt, evidence tags, `divergent_from_blueprint:` tag) and reconcile any wording that drifted from §1.3.
- [ ] 18.2 Confirm the `CLAUDE.md` test-command list contains every new test file: `check_implementation_plan_readiness_tests.sh`, `list_committed_sibling_features_tests.sh`, `check_cross_feature_collisions_tests.sh`, `project_contract_reconciliation_tests.sh` (maintenance rule in `CLAUDE.md`).

## 19. Phase 2 — Policy B

> **DO NOT EXECUTE.** Phase 2 scope, pending operator decision; kept here so the umbrella record is complete (D5, D8). Likely split into its own CRP.

- [ ] 19.1 Interactive divergence-review finding type on the step `8.4` pattern; bounded criteria: §2 stack choices and §3 archetypes only, never style.
- [ ] 19.2 Two-state resolution only: blueprint edit, or scheduled alignment step. No waiver registry.
- [ ] 19.3 Retroactive blueprint authoring for born-`B` projects.
- [ ] 19.4 Revisit parked question: `B` as project type vs per-class config flag.

## 20. Worker Coordination

> **COORDINATION ONLY — DO NOT IMPLEMENT IN THIS REPO.** These land in the yasdef worker repository (D4).

- [ ] 20.1 Specify the `already_satisfied` worker step outcome (worker records why; step closes without work) and hand it to the worker project.
