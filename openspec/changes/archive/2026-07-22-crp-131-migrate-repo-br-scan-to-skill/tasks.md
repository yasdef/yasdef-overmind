## 0. Preflight & inventory (per migration playbook)

- [ ] 0.1 Follow `design_docs/to_skills_migration/step_by_step_migration_for_particular_step.md`. Fix the Section 0 inputs: `STEP_ID=4.1`, `STEP_KEY=repo-br-scan`, `SKILL_NAME=overmind-repo-br-scan`, `MODEL_PHASE=repo_analyse`, `OLD_SCRIPT/OLD_RULE/OLD_HELPER/OLD_TESTS` (the four files below), `TARGET_ARTIFACTS=feature_br_summary.md` (`## 1` meta + `## 13` only), `READ_ONLY_INPUTS=init_progress_definition.yaml` + ready repos, `CAPTURE_ARTIFACTS=none`
- [ ] 0.2 Read `.codex/skills/overmind-step-architecture/SKILL.md`, `.codex/skills/overmind-step-deployability/SKILL.md`, `overmind/init_progress_definition_sequence_diagram.md`, and `overmind/templates/init_progress_definition_TEMPLATE.yaml`; extract the old prompt, final response line, runtime path bindings, helper checks, and test scenarios into the playbook ownership inventory before implementing

## 1. asdlc-coordinator core: repo-sync module (repo-br-scan-skill)

- [ ] 1.1 Add a shared `packages/asdlc-coordinator/src/repo/` module porting `class_repo_paths_collect_ready_paths` from `common_libs/class_repo_paths.sh`: read `meta_info.class_repo_paths` from `init_progress_definition.yaml`, return `[{ class, path }]` for `state: ready` only, rejecting ready entries with empty/non-existent paths, resolving to real paths, and de-duplicating. Reuse/extend `parse/` for the `init_progress_definition.yaml` reader and add any new result shapes to `types/` (playbook §3.1–§3.2)
- [ ] 1.2 In the same `repo/` module, port `sync_repo_to_default_branch.sh` (D7): resolve the default branch (remote `HEAD` → main/master fallback → ambiguous block), require on-default-branch / clean tree / configured upstream, run `git pull --rebase`, and abort an in-progress rebase on failure (real git-dir resolution for linked worktrees). Preserve the exact `BLOCKED: ... (D7) — ...` messages
- [ ] 1.3 Keep the bash `common_libs/class_repo_paths.sh` and `common_libs/sync_repo_to_default_branch.sh` untouched (still used by un-migrated bash steps); the TS module is a parallel implementation

## 2. repo-br-scan validator (repo-br-scan-skill)

- [ ] 2.1 Implement `validate/repo-br-scan.ts` with parity to `check_business_context_filled_from_repo.sh`: `## 1. Document Meta` must contain `source_type` and `last_updated`, both filled, with `last_updated` as `YYYY-MM-DD`; `## 13. Existing-System Context` must be present, have at least one field, and have no `[UNFILLED]`/empty field value
- [ ] 2.2 Register `repo-br-scan` in the `gate` dispatch registry (`cli/run.ts`); leave `capture` unregistered for this step so `capture repo-br-scan` exits `2` (unknown step)
- [ ] 2.3 Confirm each failure path emits a distinct actionable `missing: ...` line (missing section, missing/unfilled `source_type`, missing/unfilled/mis-formatted `last_updated`, missing `## 13` section, no `## 13` fields, each `[UNFILLED]` `## 13` field)

## 3. repo-br-scan context builder (repo-br-scan-skill)

- [ ] 3.1 Implement `context/repo-br-scan.ts` with parity to `feature_scan_repo_for_br.sh`'s prompt context: resolve the feature path, require `feature_br_summary.md` (exit `2` if absent), resolve `init_progress_definition.yaml` from the nearest ancestor, collect ready repo paths, and emit one assembled context block (playbook §3.4 fields): workspace root, feature path, target artifact, **read-only inputs** (`init_progress_definition.yaml` + the listed repositories — scan only those, do not edit them), **allowed-write surface** (only `## 1. Document Meta` `last_updated`/`source_type` and `## 13. Existing-System Context`), repos-to-scan list `- <class>: <path>`, gate command `node .overmind/overmind.js gate repo-br-scan <feature-path>`, and skill-relative rule/asset references
- [ ] 3.2 In the context builder, sync each ready repo to its default branch (D7) before assembling; on any D7 block, exit `2` with the original `BLOCKED: ... (D7) — ...` message and assemble/emit nothing
- [ ] 3.3 Handle the no-ready-classes case: emit a no-op context block (exit `0`) instructing the model that repo scan is a no-op and to finish the step without editing
- [ ] 3.4 Reference assets with paths relative to the loaded skill directory (`assets/...`), never a hardcoded `.claude/skills/...` install path
- [ ] 3.5 Register `repo-br-scan` in the `context` dispatch registry (`cli/run.ts`)

## 4. Tests (port from bash)

- [ ] 4.1 Port `check_business_context_filled_from_repo.sh` cases to TS tests for `validate/repo-br-scan` (valid + each invalid field), including a golden-example-based valid case
- [ ] 4.2 Add CLI-level tests asserting exit codes `0/1/2` and message format for `overmind gate repo-br-scan`
- [ ] 4.3 Add context tests via `overmind context repo-br-scan`: ready-path collection (ready-only, mixed-state, dedupe), assembled-block parity (repos list + gate command), skill-relative asset paths, and the no-ready no-op block
- [ ] 4.4 Add git-fixture context tests porting the D7 block scenarios from `init_scan_repo_for_br_tests.sh` (non-default branch, master-vs-remote-main, ambiguous local default, dirty tree, no upstream, pull --rebase failure with rebase aborted, linked-worktree rebase failure) — each exits `2` with the matching `BLOCKED: ... (D7)` message and leaves the artifact untouched
- [ ] 4.5 Add a successful-sync context test (upstream change pulled before the repos-to-scan block is emitted)
- [ ] 4.6 Run `npm test` and confirm green

## 5. overmind-repo-br-scan skill (repo-br-scan-skill)

- [ ] 5.1 Create `packages/installer/_data/skills/overmind-repo-br-scan/SKILL.md` following the playbook §4.5 structure: frontmatter (`name`, `description` trigger); purpose paragraph; `Required Invocation` (no capture command — note capture is N/A for this step); exact context command; allowed-write artifact list (only `## 1. Document Meta` `last_updated`/`source_type` and `## 13. Existing-System Context`); exact gate command; gate exit-code handling; the final response line; `Assets` with skill-relative paths; the inlined `repo_br_scan_rule.md` (evidence discipline, no-invention/traceability, contradiction handling, the strict `## 13` repository-block format contract); a runtime path binding section; and quality criteria. State the read-only discipline for everything outside the allowed-write surface
- [ ] 5.2 Add `assets/feature_br_summary_TEMPLATE.md` and `assets/feature_br_summary_GOLDEN_EXAMPLE.md`
- [ ] 5.3 In `SKILL.md`, instruct the model-owned loop: run `node .overmind/overmind.js context repo-br-scan <feature-path>` → if it reports a no-op, finish → otherwise enrich `## 1`/`## 13` from repository evidence → run `node .overmind/overmind.js gate repo-br-scan <feature-path>` after every write/repair → handle `0` finish / `1` repair-and-rerun / `2` stop-and-ask. State that `context` may block on a D7-unsynced repo and the model must stop and ask the user when it does. Include the exact final response line `Repo scan phase to enrich BR is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase` here as the single source — the e2e launcher relies on this skill-owned line and does not duplicate it

## 6. Installer + setup (multi-skill; runner-skill-installation)

- [ ] 6.1 Generalize `packages/installer/src/init.ts` from a single `SKILL_NAME` to a list of packaged skills (`overmind-task-to-br`, `overmind-repo-br-scan`); install each into `.codex/skills/` and `.claude/skills/`, keep `.overmind/overmind.js` as the only CLI, and return metadata covering every installed skill path (retain the existing `skillPath` compatibility field)
- [ ] 6.2 Update `packages/installer/test/init.test.ts` to assert both skills are installed under both runners with `SKILL.md` + `assets/`, that no runner skill folder contains a CLI copy, and that install fails before writing any runner target when a packaged skill payload is incomplete (missing `SKILL.md` or `assets/`)
- [ ] 6.3 Generalize `stage_runner_skills` in `project_setup_first_init_machine.sh` to stage both skills for the supported runners (fresh setup + update repair), with the same missing-source preflight per skill
- [ ] 6.4 Remove staging of the migrated `feature_scan_repo_for_br.sh` command, `repo_br_scan_rule.md` rule, and `check_business_context_filled_from_repo.sh` helper from `project_setup_first_init_machine.sh`; add their staged names to the obsolete-cleanup so update mode removes stale copies
- [ ] 6.5 Update `tests/ai_scripts/project_setup_asdlc_tests.sh`: assert both skills are staged for Codex + Claude on fresh setup and update repair; assert update mode preserves `.overmind/overmind.js`; assert the migrated command/rule/helper are no longer staged and are removed from an existing workspace on update; assert setup fails when a canonical skill source/payload is missing

## 7. e2e orchestrator wiring (repo-br-scan-skill)

- [ ] 7.1 Add `run_repo_br_scan_skill` + `build_repo_br_scan_prompt` to `project_add_feature_e2e.sh` (mirroring `run_task_to_br_skill`/`build_task_to_br_prompt`), driving `overmind-repo-br-scan` via a Codex session using the `repo_analyse` model phase (constants for `MODELS_FILE`, the model phase, the skill file path, and `.overmind/overmind.js`; reuse `load_model_config`; require `MODEL_CMD=codex`; run Codex from the ASDLC runtime root). The prompt MUST be a thin launcher containing only: "load and follow the `overmind-repo-br-scan` skill", runtime root + working directory + feature path + target artifact paths, the `.overmind/overmind.js` path, and the exact `context`/`gate repo-br-scan` commands. It MUST NOT restate skill-owned semantic instructions — the final response line, the gate exit-code handling, and the editable-write surface live only in `SKILL.md` (single source of truth). Check the skill file + `.overmind/overmind.js` exist before launching; capture the model exit code without leaking `set -e`; do not run the gate from the shell runner; print restart guidance that resumes at step 4.1 on failure
- [ ] 7.2 Rewire phase 4.1: when a class repo path is ready, run `run_repo_br_scan_skill` (replacing the deleted `feature_scan_repo_for_br.sh` invocation), then run `run_task_to_br_skill`; when no class is ready, keep the repo-scan no-op and still run the task-to-BR skill. Remove `feature_scan_repo_for_br.sh` from `phase_scripts`
- [ ] 7.3 Confirm `build_task_to_br_prompt` already follows the single-source rule (its final response line lives only in `overmind-task-to-br/SKILL.md`, not in the prompt) and give `build_repo_br_scan_prompt` the same thin-launcher shape
- [ ] 7.4 Update `tests/ai_scripts/project_add_feature_e2e_tests.sh`: phase 4.1 with a ready class drives a `repo-br-scan` Codex session then the task-to-BR session; update expected log lines (replace `feature_scan_repo_for_br.sh --feature_path ...` with the `repo-br-scan` Codex session marker) and the no-ready-class path. Assert the `repo-br-scan` prompt tells the model to load/follow the skill and includes the exact context/gate commands, and assert it does NOT restate the final response line; assert the orchestrator still advances when the Codex stub emits the skill-owned final line; assert the task-to-BR skill still runs after the scan no-ops when no class is ready

## 8. Parity gate + smoke + clean-break removal

- [ ] 8.1 Complete the playbook §5 old→new instruction-parity table (`OLD_SCRIPT` + `OLD_RULE` vs `SKILL.md` + context/gate): every row `kept`/`changed` with a reason, no `missing` row. Scrub stale ordering phrasing; confirm evidence-discipline, no-invention, contradiction-handling, the `## 1`/`## 13` editable-surface allow-list, read-only inputs, the gate-after-every-write instruction, and the final response line all survive
- [ ] 8.2 Manual smoke in a temporary ASDLC workspace (playbook §11): `npm run build` → install/stage → confirm `.overmind/overmind.js`, `.codex/skills/overmind-repo-br-scan/SKILL.md`, and `.claude/skills/overmind-repo-br-scan/SKILL.md` exist → seed `feature_br_summary.md` + one ready git repo + `init_progress_definition.yaml` → `context repo-br-scan` (sync + assemble) → `gate repo-br-scan` against the incomplete artifact returns `1` → enrich `## 1`/`## 13` → `gate repo-br-scan` returns `0` → launch the skill and confirm the final response line, without other upstream steps
- [ ] 8.3 Delete `overmind/scripts/feature_scan_repo_for_br.sh`
- [ ] 8.4 Delete `overmind/rules/repo_br_scan_rule.md`
- [ ] 8.5 Delete `overmind/scripts/helper/check_business_context_filled_from_repo.sh`
- [ ] 8.6 Delete `tests/ai_scripts/init_scan_repo_for_br_tests.sh` and remove its entry from `CLAUDE.md`'s test list
- [ ] 8.7 Confirm `common_libs/class_repo_paths.sh` and `common_libs/sync_repo_to_default_branch.sh` are retained and still referenced by their remaining bash consumers
- [ ] 8.8 Confirm no remaining references to the four deleted files in scripts/docs/tests (grep `feature_scan_repo_for_br`, `repo_br_scan_rule`, `check_business_context_filled_from_repo`, `init_scan_repo_for_br_tests`)

## 9. Documentation

- [ ] 9.1 Update `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md`: step-4.1 row shows both `overmind-task-to-br` and `overmind-repo-br-scan`; the CRP-130 implemented/deferred note lists both installed skills
- [ ] 9.2 Update `README.md` / `QUICKRUN.md`: runtime workspace stages `.overmind/overmind.js` plus `overmind-task-to-br` and `overmind-repo-br-scan` skill folders for Codex + Claude; phase 4.1 runs repo-scan then task-to-BR skill sessions
- [ ] 9.3 Confirm `overmind/init_progress_definition_sequence_diagram.md` and `overmind/templates/init_progress_definition_TEMPLATE.yaml` need no change (step 4.1 is not renumbered or re-ordered); update only the step-4.1 annotation if it names the migrated bash script rather than the skill (per the overmind-step-architecture source-of-truth rule)

## 10. Verification (playbook §10)

- [ ] 10.1 Run `npm test --workspace packages/asdlc-coordinator` (after the core/validator/context/repo changes)
- [ ] 10.2 Run `npm test --workspace packages/installer` (after the installer skill-payload/install changes)
- [ ] 10.3 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh` (after setup staging changes)
- [ ] 10.4 Run `bash tests/ai_scripts/project_add_feature_e2e_tests.sh` (after the e2e skill-launch change)
- [ ] 10.5 Run any other focused setup/update shell suite touched by this change
- [ ] 10.6 Run `git diff --check`
- [ ] 10.7 Run `openspec validate crp-131-migrate-repo-br-scan-to-skill --strict`
