> **Executor instructions — read first.**
> 1. Read `design.md` in this folder before starting; tasks cite its decisions as (D1)…(D9).
> 2. Each numbered section is **one vertical slice** — an isolated, independently reviewable increment. Execute sections in order; inside a section, execute tasks in order. Finish the whole slice (behavior + its test + any docs it introduces) before starting the next.
> 3. The **last task in each slice is its test**. A slice is done only when that test passes (`bash tests/ai_scripts/<name>` from the repo root). Do not move on with a red slice.
> 4. Plain shell only for `.sh` files. Do not add new CLI flags to existing scripts. New helper scripts use the argument forms written in the task.
> 5. All literal strings in backticks must be used exactly as written.
> 6. Sections marked **DO NOT EXECUTE** (Phase 2, Worker Coordination, and the REMOVED slices §14 and §16) are umbrella-record only.
>
> Ordering rationale: the model is fixed in docs first (§1) so it cannot drift mid-implementation; shared helpers (§2, §3) land before their consumers; each later slice threads one data-model element through its consumers and proves it with a co-located test.

## 1. Target model — docs, sequence diagram, data model (no behavior change)

Goal: write the per-class / evidence-chain / concurrency model down first, so every later slice has a fixed reference. No script behavior changes in this slice.

- [x] 1.1 Update `overmind/init_progress_definition_sequence_diagram.md`: in the **feature** phase, replace the `alt Type A / Type B/C` branches around steps `4.1`, `6`, `7`, `8`, `8.1`, `8.3` with per-class gating on `class_repo_paths[<class>].state`. Render step `7`'s evidence resolution as the chain `repo scan → in-flight feature promises → blueprint (planned) → placeholder`. Add a concurrency note that committed sibling plans are read as promises and that all repo scans read the upstream-synchronized default branch only. In the **init** phase, annotate that `project_type_code` is init-time bookkeeping that feature steps no longer read. (D1, D3, D7)
- [x] 1.2 Update `overmind/templates/init_progress_definition_TEMPLATE.yaml` data model: document the `meta_info.class_repo_paths.<class>` shape with subfields `state`, `path`, `policy`. In the `finished_only_if_conditions_meet` blocks of steps `4.1`, `6`, and `7`, replace project-type wording with per-class wording ("classes with `state: \"ready\"` are scanned; classes with a project stack blueprint use it as fallback evidence"). Add one sentence to step 1's conditions: `project_type_code records how the project started and is not read by feature-phase steps.` (D1, D2)
- [x] 1.3 Update `overmind/README.md` with the conceptual model (exact runtime strings are added later by the slices that introduce them): per-class transition lifecycle (D1); policy `C` semantics and the per-class `policy` field; the scanned-ref convention and operator merge/sync discipline — accepted work must be present on upstream default and the attached local repo must synchronize it before the next feature plans against it (D7); the promise tier (committed plans read by in-flight features), cross-feature `#### Depends on:` syntax, assignment holds, `feature_abandoned.marker`; `project_contract_reconciliation.sh` described as a stopgap (D6).
- [x] 1.4 Review: read the diagram and README against `design.md`; confirm no project-type gating remains in the feature-phase narrative. No automated test for this slice (docs only).

## 1a. Conceptual-model correction — collapse feature lifecycle to "exists = promise" (correction to §1)

> Correction slice. §1 is implemented and committed; do not rewrite it. This slice reconciles only the wording §1 wrote into `README.md` that the D7 simplification (serial planning; a feature is a promise the moment it has a plan; no abandoned concept) made stale. The sequence diagram and data model already say only "committed sibling plans are read as promises," which stays correct — leave them.

- [x] 1a.1 In `README.md`, "Evidence resolution chain (D3)" section, the **In-flight feature promises** bullet: replace "committed sibling plans (features whose `implementation_plan.md` passes the readiness predicate)" with "any sibling feature folder that holds an `implementation_plan.md` (planning is serial, so such a sibling has finished planning)". Keep the `(in-flight <feature-folder>)` tag wording.
- [x] 1a.2 In `README.md`, "Promise tier and concurrency (D7)" section: replace the five-state **Feature lifecycle** list with the simplified model — planning is serial (assumed, one operator at a time) and execution is concurrent; a feature is a promise the moment its folder holds an `implementation_plan.md`; implemented steps surface via repo scan and the rest stay promises (the per-row chain sorts it); there is no lifecycle state machine and no implementation-status analysis at planning time.
- [x] 1a.3 In the same section, delete the **`feature_abandoned.marker`** paragraph entirely and replace it with one sentence: a dead-but-undeleted feature folder keeps emitting promises and any dependent step stays held indefinitely; the operator's recourse is to delete the folder (there is no abandoned-feature concept — D7).
- [x] 1a.4 Review: confirm `README.md`, `init_progress_definition_sequence_diagram.md`, `init_progress_definition_data_model.md`, and `init_progress_definition_TEMPLATE.yaml` contain no "readiness predicate" promise-eligibility wording, no five-state feature lifecycle, and no `feature_abandoned.marker`. Docs-only slice; no automated test.

## 2. Plan-readiness helper (extract + reuse)

Goal: one reusable "is this plan finished enough to be assignable" predicate, proven in isolation. Consumer in §13 depends on it. (Originally also intended as promise eligibility for §3; the D7 simplification dropped that reuse — see §2a.)

- [x] 2.1 Create `overmind/scripts/helper/check_implementation_plan_readiness.sh` taking one argument `--feature_path <abs path>`. Move the existing plan-parse logic (the awk `fail_readiness` checks: at least one `### Step` block; every step has exactly one `#### Repo:` with a supported class) out of `overmind/scripts/feature_assing_workers.sh` into this helper. Exit 0 when the plan parses, non-zero with the existing error text otherwise.
- [x] 2.2 Update `overmind/scripts/feature_assing_workers.sh` to call the new helper for its readiness check. Behavior must be unchanged.
- [x] 2.3 Test: new `tests/ai_scripts/check_implementation_plan_readiness_tests.sh` — parseable plan exits 0; missing `#### Repo:` exits non-zero. Re-run `tests/ai_scripts/feature_assign_workers_to_implementation_plan_tests.sh` to confirm assigner behavior is unchanged. Add `check_implementation_plan_readiness_tests.sh` to the test-command list in `CLAUDE.md`.

## 2a. Plan-readiness helper — location + scope correction (correction to §2)

> Correction slice. §2 is implemented and committed; do not rewrite that section. This slice relocates the helper to its correct architectural home and corrects its reuse scope. **Architecture rule:** `overmind/scripts/helper/` holds scripts invoked **by models** (e.g. the quality gates, registered in `STAGED_HELPER_FILES`); scripts invoked **by high-level shell scripts** live in `overmind/scripts/common_libs/` (alongside `project_setup_common.sh`) and are registered in `STAGED_COMMAND_LIB_FILES`.

- [x] 2a.1 Relocate: §2 created the helper at `overmind/scripts/check_implementation_plan_readiness.sh` (flat) — wrong home, and currently in neither staging registry, so it would not be staged to a deployed machine (tests pass only because they run from the repo). It is invoked by `feature_assing_workers.sh` (a high-level script), so move it to `overmind/scripts/common_libs/check_implementation_plan_readiness.sh`, add `"check_implementation_plan_readiness.sh"` to `STAGED_COMMAND_LIB_FILES` in `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`, and update `feature_assing_workers.sh` to resolve it from the `common_libs` directory (the same staged location used for `project_setup_common.sh`). Update the path reference in `tests/ai_scripts/check_implementation_plan_readiness_tests.sh`. This is the canonical pattern: every later slice that creates a high-level-invoked helper (§3, §4, §9) places it in `overmind/scripts/common_libs/` and registers it the same way.
- [x] 2a.2 Scope-of-reuse correction: the helper is the **assignment-time** readiness gate only (§13). It is **not** reused as promise eligibility — under the simplified D7 a sibling emits promises merely by holding an `implementation_plan.md` (§3), with no readiness check. Do not wire `check_implementation_plan_readiness.sh` into `list_committed_sibling_features.sh` or any promise-tier consumer.
- [x] 2a.3 Verify: `overmind/scripts/common_libs/check_implementation_plan_readiness.sh` exists and is executable, is listed in `STAGED_COMMAND_LIB_FILES`, and nothing remains at the old flat path; `feature_assing_workers.sh` still calls it for its own readiness check; `bash tests/ai_scripts/check_implementation_plan_readiness_tests.sh` and `bash tests/ai_scripts/feature_assign_workers_to_implementation_plan_tests.sh` pass.

## 3. Sibling-promise lister (D7)

Goal: the single source of "which sibling features emit promises," proven in isolation. Under the simplified D7, promise emission is membership-only: planning is serial, so any sibling holding an `implementation_plan.md` has finished planning and is a promise — no readiness check, no completeness check, no abandoned concept. Depends on §1's data model.

- [x] 3.1 Create `overmind/scripts/common_libs/list_committed_sibling_features.sh` (common_libs, per §2a.1 — it is invoked by high-level scripts; add `"list_committed_sibling_features.sh"` to `STAGED_COMMAND_LIB_FILES` in `project_setup_first_init_machine.sh`) taking `--feature_path <abs path>`. It prints, one per line, the folder names of sibling feature folders under the same `projects/<project-id>/` that (a) are not the current feature folder and (b) contain `implementation_plan.md`. Nothing else is tested: implemented vs unimplemented is resolved per-row downstream by the evidence chain (repo scan wins), and there is no abandoned marker. Empty output and exit 0 when none qualify. Do not call `check_implementation_plan_readiness.sh` (see §2a.2).
- [x] 3.2 Test: new `tests/ai_scripts/list_committed_sibling_features_tests.sh` — excludes self; includes siblings with a plan whether zero-implemented, half-implemented, or fully-checked; excludes a sibling folder with no `implementation_plan.md`; empty output exit 0 when none. Add `list_committed_sibling_features_tests.sh` to the test-command list in `CLAUDE.md`.

## 4. Per-class attach (transition)

Goal: attach a deferred class to its now-scannable repo, end to end, from both entry points (D1, D2). Depends on §1's data model.

- [x] 4.1 Create `overmind/scripts/common_libs/persist_class_repo_attach.sh` (common_libs, per §2a.1 — invoked by high-level scripts; add `"persist_class_repo_attach.sh"` to `STAGED_COMMAND_LIB_FILES` in `project_setup_first_init_machine.sh`) taking three positional arguments `<project-path> <class> <repo-path>`. It validates `<repo-path>` is an existing directory containing `.git`, resolves it to an absolute path, and persists into `<project-path>/init_progress_definition.yaml` under `meta_info.class_repo_paths.<class>`: `state: "ready"`, `path: "<abs path>"`, `policy: "C"`. Reuse the persistence approach already in `overmind/scripts/project_mgmt/project_setup_update_project.sh`.
- [x] 4.2 Update `overmind/scripts/project_mgmt/project_setup_update_project.sh` to call `persist_class_repo_attach.sh` for its attach write (so both flows share one writer) and therefore also record `policy: "C"`.
- [x] 4.3 Update `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`: before running the progress scanner, for each class in `meta_info.class_repo_paths` whose `state` is not `"ready"` and for which `<project-path>/project_stack_blueprint_<class>.md` exists, read `planned_repo_path` from that blueprint's §1 Meta. If that path is a directory containing `.git`, prompt exactly:
  `Class '<class>' blueprint declares planned repo path <path> and a scannable repository exists there. Attach it and switch this class to repo-backed (policy C: repo becomes authoritative; blueprint is consulted only for subsystems absent from the repo)? [y/n/other path]`
  On `y` call `persist_class_repo_attach.sh`; on `n` continue silently; on any other input treat it as an alternate repo path and validate+attach via the same helper; on invalid path re-prompt once then continue.
- [x] 4.4 Test: extend `tests/ai_scripts/project_add_feature_e2e_tests.sh` — prompt fires for a deferred class with a scannable `planned_repo_path`; `n` leaves the class deferred; an alternate path attaches; a non-existent planned path stays silent; `policy: "C"` is persisted.

## 5. Per-class gating of scan-dependent steps

Goal: steps `4.1`, `6`, `7` gate on per-class `state`, never on `project_type_code` (D2). Depends on §4 (a class must be attachable to `ready`).

- [x] 5.1 Update `overmind/scripts/feature_scan_repo_for_br.sh` (step `4.1`): find the existing project-type guard (search the script for `project_type`) and replace it with per-class gating — scan every class whose `class_repo_paths.<class>.state` is `"ready"`; skip non-ready classes; the step is a no-op only when no class is ready.
- [x] 5.2 Update `overmind/scripts/feature_contract_delta.sh` (step `6`) the same way: per-class gating on `state: "ready"` replaces any `project_type` conditional (search for `project_type`).
- [x] 5.3 Update `overmind/scripts/feature_repo_surface_and_exec_context.sh` (step `7`): remove remaining `project_type_code` branching (search for `project_type`). New rule per class: when `state` is `"ready"`, repo scan is the primary source; whenever `<project-path>/project_stack_blueprint_<class>.md` exists (any project type), bind it as the `Stack blueprint source:` fallback context line. Per-row precedence stays as in the rule file (§7).
- [x] 5.4 Test: extend `tests/ai_scripts/init_scan_repo_for_br_tests.sh` and `tests/ai_scripts/init_feature_contract_delta_tests.sh` — a mixed-state project (one class `ready`, one deferred) scans only the ready class; no project-type dependence.

## 6. First-attach contract reconciliation (stopgap, D6)

Goal: clear blueprint-era contract drift once, the first time a class attaches. Depends on §4.

- [x] 6.1 Create `overmind/scripts/project_mgmt/project_contract_reconciliation.sh` taking `--path <asdlc/projects/<project-id>>`. This is a model-driven prompt step (copy the prompt-build/commit pattern from `overmind/scripts/init_common_contract_definition.sh`): bind `common_contract_definition.md` plus all ready repo paths; the model lists mismatches between the documented contract and the as-built API; the operator approves corrections interactively; approved corrections are written back and committed. Script header comment must contain exactly: `Stopgap (D6): clears blueprint-era contract drift once per class attach; ongoing drift is the feedback loop's job.`
- [x] 6.2 Update `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`: immediately after a successful attach in task 4.3, if `<project-path>/.contract_reconciled_<class>` does not exist, run `project_contract_reconciliation.sh --path <project-path>` and then create the empty marker file `<project-path>/.contract_reconciled_<class>`.
- [x] 6.3 Test: new `tests/ai_scripts/project_contract_reconciliation_tests.sh` — script binds the contract + ready repos into the prompt and applies only operator-approved corrections (follow the existing model-driven test pattern, e.g. `init_common_contract_definition_tests.sh`). Extend `tests/ai_scripts/project_add_feature_e2e_tests.sh` to assert reconciliation runs once, then the marker suppresses it on the next run. Add `project_contract_reconciliation_tests.sh` to the test-command list in `CLAUDE.md`.

## 6a. Class-repo-path coherence invariant (state ↔ path) — follow-up (hardens §4)

> Follow-up slice placed after §6 because §1–§6 (and §1a, §2a) are implemented and committed. It is the consolidated follow-up for the coherence invariant and bundles every change that touches an already-shipped artifact. Additive only — no behavior change to §1–§6 on coherent inputs. project_type_code stays orthogonal (D1). Architecture (§2a): the validator is script-invoked → common_libs; `class_repo_paths.sh` is already a staged lib (`STAGED_COMMAND_LIB_FILES`), so no staging-registry change.
>
> Known gap recorded, not fixed here (operator decision: attach-only enforcement): project creation's `validate_repo_path` (`overmind/scripts/common_libs/project_setup_common.sh`) accepts any non-empty directory for a "ready" class, so a born-B/C class can be ready without a `.git` repo while the scan steps assume `.git`. This slice enforces coherence only at the attach writer and does not retro-validate creation output; tightening creation to require `.git` (and updating its tests) is deferred to a future slice.

- [x] 6a.1 Add `class_repo_paths_validate_coherence <definition-path> [<class>]` to `overmind/scripts/common_libs/class_repo_paths.sh` (reuse `class_repo_paths_extract_entries`). With no `<class>` it validates every entry; with `<class>` it validates only that class. Rules per `meta_info.class_repo_paths.<class>`: `state: "ready"` ⟹ `path` non-empty and resolves to an existing directory containing `.git`; `state: "deferred"` ⟹ `path` empty or absent; any other `state` value is an error; if `policy` is present it must be `B` or `C` (absence is allowed — born-ready classes carry none per the data model). Exit 0 when coherent; otherwise exit non-zero printing the offending class and reason. Read-only; never writes.
- [x] 6a.2 Write-time guard (attach-only, scoped): at the end of `overmind/scripts/common_libs/persist_class_repo_attach.sh`, after the existing write, call `class_repo_paths_validate_coherence <definition-path> <class>` for the just-attached class; on non-zero, fail with the validator's message. Leave persist's existing pre-write `.git`/directory checks and all write logic unchanged (the guard confirms the written record through the one canonical rule).
- [x] 6a.3 Fixture hygiene: in `tests/ai_scripts/project_contract_reconciliation_tests.sh`, change the deferred `frontend` entry in `write_project_definition` to carry no `path` (empty), so the fixture models a coherent deferred class. (Reconciliation does not call the validator, so this is hygiene, not a pass/fail fix.)
- [x] 6a.4 Test: new `tests/ai_scripts/class_repo_paths_coherence_tests.sh` — ready+valid `.git` repo passes; ready+empty-path fails; ready+path-not-a-directory fails; ready+directory-without-`.git` fails; deferred+no-path passes; deferred+non-empty-path fails; unknown-state fails; `policy: "X"` fails while `policy: "C"` passes; scoped single-class mode validates only the named class. Re-run `tests/ai_scripts/project_setup_update_project_tests.sh`, `tests/ai_scripts/project_add_feature_e2e_tests.sh`, and `tests/ai_scripts/project_contract_reconciliation_tests.sh` to confirm coherent inputs are unaffected. Add `class_repo_paths_coherence_tests.sh` to the test-command list in `CLAUDE.md`.

## 7. Permanent evidence chain (surface rule, D3)

Goal: generalize the CRP-117 type-`A`-only fallback into the permanent per-class, per-layer chain.

- [x] 7.1 Update `overmind/rules/feature_repo_surface_and_exec_context_rule.md`: replace the type-`A`-only fallback narrative with the permanent per-class, per-row resolution chain: repo scan → in-flight feature promises (§10) → blueprint (`(planned)` tag) → literal `<to be defined during implementation>`. One source per row; every non-repo source tagged. Add the demand-driven sentence: `The chain runs only for surfaces this feature's requirements touch; "absent" means this feature's need is not satisfied, never an inventory claim about the repo.`
- [x] 7.2 Same rule file: blueprint evidence citations must append the blueprint's §1 `last_updated` value, format exactly: `project_stack_blueprint_<class>.md §<n> (last_updated: <YYYY-MM-DD>)`.
- [x] 7.3 Same rule file: add one sentence: `A blueprint is never retired; it remains fallback evidence for unmaterialized layers for the life of the project.`
- [x] 7.4 Test: extend `tests/ai_scripts/feature_repo_surface_and_exec_context_be_tests.sh` and `..._fe_tests.sh` — a repo-resolved row carries the real path; an unmaterialized layer resolves from the blueprint with `(planned)` and a dated citation.

## 8. Policy C divergence tagging (D5)

Goal: a materialized-but-divergent layer resolves from the repo silently with a passive tag.

- [x] 8.1 Update `overmind/rules/feature_repo_surface_and_exec_context_rule.md`, `overmind/templates/project_surface_struct_resp_map_be_TEMPLATE.md`, and `..._fe_TEMPLATE.md`: define an optional single passive bullet field allowed in `project_surface_struct_resp_map_<class>.md ## 3. Key Parts of Repo and Their Responsibilities` layer blocks, format exactly: `- divergent_from_blueprint: §<n>` (the `project_stack_blueprint_<class>.md ## 3. Layer Bindings` subsection the materialized layer diverges from). It is written when the layer is materialized in the repo but does not match the blueprint's layer bindings; the row still resolves from the repo (policy `C`, D5). Never required, never prompts, never blocks.
- [x] 8.2 Verify `overmind/scripts/helper/check_feature_repo_surface_and_exec_context_be_quality.sh` and `..._fe_quality.sh` do not fail when a `- divergent_from_blueprint:` field is present (fix only if they do).
- [x] 8.3 Test: extend `tests/ai_scripts/feature_repo_surface_and_exec_context_be_tests.sh` and `..._fe_tests.sh` — a `- divergent_from_blueprint: §<n>` field passes the quality gate.

## 9. Remote-synced merged-truth scan discipline (upstream default branch, D7)

Goal: all planning scans read the **upstream-synchronized default branch only** — not worker branches, not dirty local worktrees, and not stale local default branches. Before a ready class repo is scanned, Overmind synchronizes the attached local repo's default branch from its configured upstream using `git pull --rebase`; if synchronization cannot complete, the repo is refused and never scanned. Worker branches and uncommitted edits remain invisible to planning, and accepted work counts as merged truth only after it is present on upstream default and the attached local repo has synchronized it. This is a precondition gate, not a product-judgment gate — reading a worker branch, dirty worktree, or stale local default branch would silently corrupt merged-truth evidence, so it is the one place enforcement is correct.

- [x] 9.1 Create `overmind/scripts/common_libs/sync_repo_to_default_branch.sh` (common_libs, per §2a.1 — invoked by high-level scripts; add `"sync_repo_to_default_branch.sh"` to `STAGED_COMMAND_LIB_FILES` in `project_setup_first_init_machine.sh`) taking one positional argument `<repo-path>`. Resolve the repo's default branch independently of the current checkout: prefer a configured remote default from `refs/remotes/<remote>/HEAD`; when no remote default is available, fall back to local branch detection only if exactly one of `main` or `master` exists; if both local branches exist and no remote default is configured, print exactly `BLOCKED: <repo-path> default branch is ambiguous; both main and master exist and no remote default is configured (D7) — configure the default branch and rerun` to stderr and exit non-zero. Enforce/synchronize in this order: (a) `<repo-path>` is a git repository; (b) `git -C <repo-path> rev-parse --abbrev-ref HEAD` equals the resolved default branch; (c) `git -C <repo-path> status --porcelain` is empty before synchronization; (d) the resolved default branch has an upstream configured; (e) run `git -C <repo-path> pull --rebase`; (f) `git -C <repo-path> status --porcelain` is empty after synchronization. If (b) fails, print exactly `BLOCKED: <repo-path> is not on its default branch; planning reads upstream-synchronized merged truth only (D7) — check out the default branch and rerun` to stderr and exit non-zero. If (c) fails, print exactly `BLOCKED: <repo-path> has uncommitted changes; planning syncs and reads committed merged truth only (D7) — commit or stash and rerun` to stderr and exit non-zero. If (d) fails, print exactly `BLOCKED: <repo-path> default branch has no upstream; planning cannot sync merged truth (D7) — configure upstream and rerun` to stderr and exit non-zero. If (e) fails, abort any interrupted rebase left by this helper-triggered `git pull --rebase`, then print exactly `BLOCKED: <repo-path> could not sync default branch with git pull --rebase; planning cannot read merged truth (D7) — resolve the repo and rerun` to stderr and exit non-zero. If (f) fails, print exactly the same sync-failure `BLOCKED:` message and exit non-zero. When synchronization succeeds, print nothing and exit 0. No checkout/switch side effects on the operator's repo are allowed; `git rebase --abort` is allowed only as cleanup of this helper's failed `git pull --rebase` attempt.
- [x] 9.2 Update `feature_scan_repo_for_br.sh`, `feature_contract_delta.sh`, `feature_repo_surface_and_exec_context.sh`, and `feature_prerequisite_gaps.sh`: before scanning any ready repo path, call `sync_repo_to_default_branch.sh <path>`; on non-zero, stop the step for that run with the helper's message and produce no partial artifact. Because the helper guarantees a clean, upstream-synchronized default-branch worktree, the files these steps read off `<path>` equal current merged truth. Re-running after the repo is on a clean default branch with upstream configured and pull/rebase succeeds proceeds normally.
- [x] 9.3 Test: in `tests/ai_scripts/init_scan_repo_for_br_tests.sh`, a ready class repo on a non-default branch makes the step stop with the exact `BLOCKED:` not-on-default message and write no artifact; a repo on `main`/`master` but with an uncommitted change stops with the exact `BLOCKED:` uncommitted-changes message; a default branch with no upstream stops with the exact no-upstream message; a pull/rebase failure stops with the exact sync-failure message and writes no artifact; a clean repo on `main`/`master` with upstream configured pulls/rebases successfully, scans the synchronized content, and writes the expected artifact.

## 10. Promise tier — surface-map binding (D7)

Goal: in-flight sibling plans become an evidence tier in the surface step. Depends on §3, §7.

- [x] 10.1 Update `overmind/scripts/feature_repo_surface_and_exec_context.sh`: call `list_committed_sibling_features.sh`; for each returned folder, bind a read-only context line `In-flight plan source: <folder>/implementation_plan.md` into the prompt. Update `overmind/rules/feature_repo_surface_and_exec_context_rule.md` (the §7.1 chain): rows resolved from a sibling plan carry the tag `(in-flight <feature-folder>)` and evidence cites `<feature-folder>/implementation_plan.md step <step-id>`.
- [x] 10.2 Test: extend `tests/ai_scripts/feature_repo_surface_and_exec_context_be_tests.sh` and `..._fe_tests.sh` — a row resolved from a committed sibling plan is tagged `(in-flight <folder>)`.

## 11. Promise tier — prerequisite gaps (D7)

Goal: step `8.2` learns the cross-feature classification. Depends on §3.

- [x] 11.1 Update `overmind/rules/prerequisite_gaps_rule.md`, `overmind/templates/prerequisite_gaps_TEMPLATE.md`, and `overmind/scripts/feature_prerequisite_gaps.sh` (step `8.2`): add the classification value `scheduled_in_feature <feature-folder>/<step-id>` alongside `present_in_repo`, `scheduled_in_slices`, `unmet`. The script binds sibling plans via `list_committed_sibling_features.sh`. The quality gate continues to reject only `unmet`.
- [x] 11.2 Update `overmind/scripts/helper/check_prerequisite_gaps_quality.sh` to accept the new classification value as valid.
- [x] 11.3 Test: extend `tests/ai_scripts/init_feature_prerequisite_gaps_tests.sh` — a sibling-committed surface classifies as `scheduled_in_feature <folder>/<step-id>`, not `unmet`; the quality gate accepts it.

## 12. Promise tier — pending contract deltas (D7)

Goal: step `6` reads in-flight sibling contract deltas as evidence, reporting (not resolving) overlaps. Depends on §3.

- [x] 12.1 Update `overmind/scripts/feature_contract_delta.sh`: for each folder from `list_committed_sibling_features.sh` that contains `feature_contract_delta.md`, bind it as a read-only context line `Pending contract delta source: <folder>/feature_contract_delta.md`. Add one paragraph to `overmind/rules/feature_contract_delta_rule.md`: pending sibling deltas are evidence of in-flight contract claims; the delta must not silently contradict them — overlaps are reported, not resolved, at this step.
- [x] 12.2 Test: extend `tests/ai_scripts/init_feature_contract_delta_tests.sh` — with a committed sibling holding `feature_contract_delta.md`, the `Pending contract delta source: <folder>/feature_contract_delta.md` context line is bound into the prompt.

## 13. Cross-feature assignment gate + zero-sibling assignment regression (D7)

Goal: the plan's `#### Depends on:` learns cross-feature syntax, and assignment deterministically holds steps whose cross-feature dependencies are not complete-and-merged. Depends on §2.

- [x] 13.1 Update `overmind/templates/implementation_plan_TEMPLATE.md`, `overmind/rules/implementation_plan_rule.md`, and `overmind/scripts/helper/check_implementation_plan_quality.sh`: `#### Depends on:` entries containing a `/` are cross-feature references with format exactly `<feature-folder>/<step-id>` (example: `0003_customer_accounts/3.2`); entries without `/` remain same-feature step ids. Update the template's Format Rules line for `#### Depends on:` accordingly, and teach the implementation-plan quality gate to validate cross-feature reference format without applying the same-feature `seen_steps` check.
- [x] 13.2 Update `overmind/scripts/feature_assing_workers.sh`: when a step's `#### Depends on:` contains a cross-feature entry `<feature-folder>/<step-id>`: resolve `../<feature-folder>/implementation_plan.md` relative to the feature folder. The dependency is **complete** when that file exists, contains a `### Step <step-id>` block, and every checklist box in that block is `- [x]`. If not complete, write exactly `#### Assigned: hold: depends on <feature-folder>/<step-id>`. (There is no abandoned-feature special case — D7; a dependency on a dead-but-undeleted folder simply never completes and stays held.) Holds are reported in the final summary the same way as the existing class-availability issues. Re-running the script re-evaluates every hold (idempotent).
- [x] 13.3 Test: extend `tests/ai_scripts/feature_assign_workers_to_implementation_plan_tests.sh` and `tests/ai_scripts/check_implementation_plan_quality_tests.sh` — an incomplete cross-feature dependency → exact hold text; a completed-and-checked dependency → normal assignment; re-running flips a hold to an assignment after the dependency completes; with zero sibling plans, assignment adds no cross-feature holds; the quality gate accepts valid cross-feature dependency references.

## 14. Cross-feature collision check — REMOVED (D7 simplification)

> **DO NOT EXECUTE — removed by the D7 simplification.** Serial planning makes the feature being planned see every sibling promise during normal planning, so there is no mutually-blind window for a commit-moment detector to cover. Overlaps now surface inline: surface-map rows from a sibling are tagged `(in-flight <feature-folder>)` (§10) and raised as step `8.4` findings (§15); contract overlaps are reported at step `6` (§12). No `check_cross_feature_collisions.sh`, no `cross_feature_collisions.md`, no `check_cross_feature_collisions_tests.sh`; `feature_implementation_plan.sh` (step `8.3`) gains no collision call.

## 15. Overlap surfacing in step 8.4 + zero-sibling review regression (D7)

Goal: surface overlaps with sibling promises become step `8.4` product-fit findings. No dedicated collisions file and no e2e contract-conflict prompt — contract overlaps are already reported at step `6` (§12), and surface overlaps are already tagged in the surface map (§10), which is an existing read-only input to step `8.4`. Depends on §10.

- [x] 15.1 Update `overmind/rules/implementation_plan_semantic_review_rule.md`: the step `8.4` review reads the surface maps (already bound as read-only inputs) and raises each row tagged `(in-flight <feature-folder>)` as a product-fit finding (apply/reject with resolution notes, existing pattern). Nothing here hard-blocks.
- [x] 15.2 Test: extend `tests/ai_scripts/init_feature_implementation_plan_semantic_review_tests.sh` — a surface map containing an `(in-flight <feature-folder>)` row causes step `8.4` to raise it as a finding; with no `(in-flight <feature-folder>)` rows, the review adds no in-flight overlap finding.

## 16. Abandoned-feature marker — REMOVED (D7 simplification)

> **DO NOT EXECUTE — removed by the D7 simplification.** There is no abandoned-feature concept: a sibling is a promise while its folder holds an `implementation_plan.md`, and a dead feature is retired by deleting its folder (the operator's responsibility). No `feature_abandoned.marker` and no abandon menu option.

## 17. Docs & maintenance reconciliation (final pass)

- [x] 17.1 Re-read `README.md` against the now-built exact strings (attach prompt, hold texts, evidence tags including `(in-flight <feature-folder>)`, `scheduled_in_feature <feature-folder>/<step-id>`, `divergent_from_blueprint:` tag) and reconcile any wording that drifted from §1.3 and §1a. There is no contract-conflict prompt and no `feature_abandoned.marker` to document (§14/§15/§16 simplification).
- [x] 17.2 Confirm the `CLAUDE.md` test-command list contains every new test file and no removed one: present — `check_implementation_plan_readiness_tests.sh`, `list_committed_sibling_features_tests.sh`, `project_contract_reconciliation_tests.sh`; absent — `check_cross_feature_collisions_tests.sh` (its slice was removed). (Maintenance rule in `CLAUDE.md`.)

## 18. Phase 2 — Policy B (extracted follow-up)

> **DO NOT EXECUTE.** Phase 2 scope, pending operator decision; kept here so the umbrella record is complete (D5, D8). Likely split into its own CRP.

- [ ] 18.1 Interactive divergence-review finding type on the step `8.4` pattern; bounded criteria: §2 stack choices and §3 archetypes only, never style.
- [ ] 18.2 Two-state resolution only: blueprint edit, or scheduled alignment step. No waiver registry.
- [ ] 18.3 Retroactive blueprint authoring for born-`B` projects.
- [ ] 18.4 Revisit parked question: `B` as project type vs per-class config flag.

## 19. Worker Coordination (extracted follow-up)

> **COORDINATION ONLY — DO NOT IMPLEMENT IN THIS REPO.** These land in the yasdef worker repository (D4).

- [ ] 19.1 Specify the `already_satisfied` worker step outcome (worker records why; step closes without work) and hand it to the worker project.
