# E2E Orchestrator Migration — 1. Current `project_add_feature_e2e.sh` Functional Inventory

Source: `overmind/scripts/project_mgmt/project_add_feature_e2e.sh` (3,451 lines) plus its hard dependency `overmind/scripts/project_mgmt/init_progress_scanner.sh` (1,102 lines). This inventory groups every responsibility the script owns today so that nothing implemented is lost in the migration. It deliberately stays at behavior level, not line level; the SDD change for each slice re-derives exact details from the source before deleting it.

Companion docs: `02_responsibility_translation_map.md`, `03_target_architecture.md`, `04_migration_plan.md`.

---

## A. Entry, Workspace, and Project Resolution

| Behavior | Details that must survive |
|---|---|
| CLI surface | `--path <project-folder>` (optional), `--resume <step>` (optional), `--help`. No other flags. |
| Staged-runtime guard | Must run from `<asdlc>/.commands/`; parent must contain `asdlc_metadata.yaml`. That parent is the runtime root; all paths are runtime-root-relative. |
| Project discovery | Children of `<runtime>/projects/` that contain `init_progress_definition.yaml`, sorted. Exactly one → auto-select with notice. Multiple → interactive numbered menu with `q` to finish (clean exit 0). Zero → hard error. |
| Project path validation | `--path` value must resolve inside the workspace and point at a folder containing `init_progress_definition.yaml`. |
| Definition metadata reads | `project_type_code` and `project_classes` are parsed from the `meta_info:` block of `init_progress_definition.yaml` (awk-based YAML slicing, quote-stripping, list and inline-array forms). `class_repo_paths` per-class `state:` values (`ready` vs anything else) are parsed the same way. |

## B. Feature-Start Pre-Flight (runs once per invocation, before phases)

Note: these are project-level lifecycle operations (they act only when class repo states change, which is rare) bolted onto every feature run. In the target design they separate into their own project-level flow — see `03_target_architecture.md ## Decisions` — but every behavior below must survive there.

| Behavior | Details that must survive |
|---|---|
| Deferred class repo attach | For every class in `class_repo_paths` whose `state` is not `ready`, prompt the operator to attach an existing repo path ("policy C: repo becomes authoritative; blueprint consulted only for subsystems absent from the repo"). Blank keeps it deferred. Exactly one retry on failed attach. Attach goes through `common_libs/persist_class_repo_attach.sh`. |
| Reconciliation transaction guard | Before the first attach/reconcile write, if the project folder is a git worktree it must be clean, otherwise hard fail. Non-git projects pass through. |
| Contract reconciliation | Every `ready` class missing a `.contract_reconciled_<class>` marker is reconciled in **one** interactive model session (`project_contract_reconciliation.sh --path <abs> --class <c> ...`, operator stdin forwarded). Markers are written only after the whole session succeeds, so a failure retries the full set next run. Attach prompts all complete before reconciliation starts (design decision D10). |
| Reconciliation commit unit | After reconciliation: verify with `git status` that only owned paths changed (`init_progress_definition.yaml`, `common_contract_definition.md`, the new markers). Unexpected changes → delete the markers, print the diff, hard fail. Otherwise offer `Commit reconciliation results? [y/N]`; on yes, commit exactly the owned paths and verify the worktree is clean after; on no, stop the run cleanly ("results were not committed"). |

## C. Feature Selection and Persistent State

| Behavior | Details that must survive |
|---|---|
| State file | `<project>/.project_add_feature_e2e_state.env`, single key `feature_path=`. Loaded at start; values that no longer resolve to a directory inside the workspace are reported as stale and ignored. Written whenever a feature is scaffolded or selected. |
| Feature discovery | Child directories of the project folder; for each, run the scanner and keep the canonical last `next step: ...` line. `next step: none` = finished; anything else = unfinished (path + status line kept for the menu). |
| New-vs-continue flow | If unfinished features exist: menu `1) Start a new feature / 2) Continue an existing unfinished feature`, then a numbered unfinished-feature menu showing each feature's next-step line. Constraints: `--resume` other than `3` forbids "start new"; `--resume 3` forbids "continue". Special case: `--resume 8.4` with a valid cached feature path and no unfinished features re-opens the completed cached feature for the optional semantic review. `--resume` (non-3) with no unfinished features and no cache → hard error with guidance. |
| Scaffold capture (phase 3) | Runs `.commands/feature_br_scaffold.sh --path <project>` (itself deterministic: prompts operator for feature ID/title, creates the feature folder from template). The e2e tees its output and extracts the created feature path from the `Created feature folder:` line (fallback: `Updated .../feature_br_summary.md`), canonicalizes it, persists it to the state file. |

## D. Sequencing Engine

| Behavior | Details that must survive |
|---|---|
| Phase map | Ordered phases `3, 4.1, 4.2, 5, 5.1, 6, 7, 7.1, 8, 8.1, 8.2, 8.3, 8.4`; optional: `5.1`, `7.1`, `8.4`. Human labels per phase (used in prompts/messages). |
| Scanner as source of truth | `init_progress_scanner.sh --path <feature>` computes the next step from artifacts + `init_progress_definition.yaml` (project-type- and class-aware). The e2e parses the canonical final `next step: <num> (<name>)` line. |
| Project-prereq guard | If the scanner returns a step before `3` (project init incomplete), fail with step-specific guidance: `1.1` → run `init_project_stack_blueprints.sh`, `2` → run `init_common_contract_definition.sh`, otherwise generic "complete step N first". Dotted-numeric step comparison logic supports this. |
| Scanner-step → phase mapping | Numeric mapping (including legacy `4` → `5`) plus name-substring fallbacks for renamed steps. |
| `--resume` → phase mapping | Accepts numbers and aliases (`scaffold`, `ears`, `contract-delta`, `prerequisite-gaps`, `semantic-review`, legacy numerics `4/5/6`, etc.). |
| Linear run loop | From start phase to end of map. Optional phase declined → skip if a later required phase exists, else finish cleanly. Any phase failure → restart guidance printing the exact rerun command (`.commands/project_add_feature_e2e.sh --path <p> --resume <phase>`) and exit 1. |
| Flow-control protocol | Internal return codes: `0` continue, `10` optional-skipped, `20` user stopped / stdin closed (exit 0), `30` finished after declined optional with nothing required left (exit 0), `40` phase execution failed (exit 1). |
| Checkpoint commits | Best-effort `git add -A && git commit -m "Checkpoint: ..."` on the runtime root **before** phases `5.1`, `7.1`, `8.4` and **after** `8.4` (success or clean skip). Failures never block the run. |

## E. Per-Phase Model Session Launcher (the repeated ~130-line pattern, 13×)

Common pattern for every skill phase:

1. **Preconditions**: installed skill exists (`.codex/skills/overmind-<step>/SKILL.md`), shared CLI exists (`.overmind/overmind.js`), step-specific input artifacts exist.
2. **Repo sync (D7)** for repo-touching steps only — `node .overmind/overmind.js sync <step> <feature>` before the session: `4.1` repo-br-scan, `6` contract-delta, `7` surface-map (per class), `8.2` prerequisite-gaps. Sync failure → stop with resume guidance.
3. **Model config**: look up the phase row in `.setup/models.md` (`phase | command | model | extra args...`); command must be `codex`; binary must exist.
4. **Read-only-input discovery** (phases 6, 7, 8, 8.1, 8.2, 8.3, 8.4): pre-run `node .overmind/overmind.js context <step> <feature>`, parse `- read_only_input:` lines, assert each file exists.
5. **Prompt assembly**: small prompt = load skill + runtime bindings (workspace root, cwd, feature path, target artifacts, CLI path) + exact capture/context/gate commands + "model owns the gate loop". Never contains skill-owned final-response lines.
6. **Launch**: run `codex -m <model> <extra args> <prompt>` from the runtime root; capture exit code without tripping `set -e`.
7. **Deterministic post-run guards** (must never be downgraded to advisory skill text — see `design_docs/to_skills_migration/step_by_step_migration_for_particular_step.md ## 2. Ownership Rules`):
   - Read-only-input immutability: snapshot before, `cmp` after, hard fail on drift. Steps 5/5.1 protect `feature_br_summary.md`; 6, 7, 8, 8.1, 8.2, 8.3, 8.4 protect every context-declared read-only input; 7.1 protects `.setup/external_sources.yaml` and `init_progress_definition.yaml` including no-create and no-delete assertions.
   - Required-output-produced: e.g. `user_br_input.md` + `missing_br_data.md` (4.1 task-to-br), `requirements_ears_review.md` (5.1), `feature_contract_delta.md` (6), per-class surface map (7), `technical_requirements.md` (8), `implementation_slices.md` (8.1), `prerequisite_gaps.md` (8.2), `implementation_plan.md` (8.3), `implementation_plan_semantic_review.md` (8.4).

Phase-specific composition on top of the pattern:

- **4.1**: repo-br-scan session runs only if some `class_repo_paths` entry has `state: ready` (otherwise announced skip); task-to-BR session always runs after.
- **4.2**: br-clarification session, then the deterministic `node .overmind/overmind.js readiness br-clarification <feature>` check; either failure stops with resume guidance.
- **7 (per-class loop)**: active classes come from `project_classes` (fallback: backend/frontend/mobile); completed = per-class surface-map artifact exists. Interactive menu: analyze one pending class now / refresh status / move forward. Class selection by number or name. Each class run is a separate surface-map session with `--class`. Moving forward with pending classes prints which classes remain.
- **y/n confirmation** before phases 4.2, 5, 5.1, 6, 7.1, 8, 8.1, 8.2, 8.3, 8.4 showing the phase label and command; declining a required phase stops the run; declining an optional phase skips it (4.1 and 7 have their own interaction shapes instead).

## F. Scanner (`init_progress_scanner.sh`) responsibilities consumed here

The scanner is a read-only compute over `init_progress_definition.yaml` + artifact existence: project- and feature-scope step records, project-type filtering (`project_type_code`), per-class expansion (`project_classes`), feature-folder heading resolution, rendered checklist output, and the canonical `next step: <num> (<name>)` line. The e2e consumes: per-feature unfinished status, next-step computation, and project-init-incomplete detection.

**Known defect (operator-confirmed 2026-07-03):** the current scanner does not report steps precisely as declared in `init_progress_definition.yaml` — some steps are joined together, some omitted. The e2e's `map_scanner_step_to_phase` remapping (legacy numerics, name-substring fallbacks) exists to absorb this drift. Therefore the scanner's step-reporting behavior is **not** a parity target; only its output contract (checklist + `next step:` line) is. Decision recorded in `03_target_architecture.md ## Decisions`: a new definition-as-spec scanner replaces it entirely in this effort.

## G. Explicitly Out of Scope of the E2E Today (unchanged by this migration)

- Worker registration/assignment (`project_register_worker.sh`, worker assignment scripts) — separate cross-cutting item in `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md ## 4. Steps → Skills`.
- Setup/staging (`project_setup_first_init_machine.sh`) — `packages/installer` owns the future; staging keeps copying the transitional shell until the plan's cleanup slice.
- Project init steps 1.1 / 2.3 skills — not yet migrated; the orchestrator only needs to *detect* their incompleteness and point at them.
