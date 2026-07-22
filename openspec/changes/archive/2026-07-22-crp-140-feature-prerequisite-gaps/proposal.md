## Why

CRP-139 completed migration of step 8.1 (implementation slices), leaving **step 8.2 — "Prerequisite gaps"** → `overmind-prerequisite-gaps` as the next row in the migration table (`design_docs/to_skills_migration/migration_to_skill_architecture_overview.md` Steps→Skills). It is still implemented as bash: `feature_prerequisite_gaps.sh` (model orchestrator) + `prerequisite_gaps_rule.md` (rule) + `check_prerequisite_gaps_quality.sh` (gate helper). This change migrates that step to the agent-skill + TypeScript-core pattern proven by CRP-129→139.

Step 8.2 produces one **shared** `prerequisite_gaps.md` artifact per feature: a per-EARS-requirement trace of externally-invocable prerequisites, each classified as `present_in_repo`, `scheduled_in_slices`, `scheduled_in_feature <feature-folder>/<step-id>`, or `unmet`. It gates step 8.3 (implementation plan) on zero `unmet` entries and keeps required missing operator-facing surfaces explicitly identifiable for downstream slice/plan preservation checks. Like steps 8 and 8.1, it runs once and covers all active repo classes in a single pass; it does not loop per class.

Step 8.2 differs from step 8.1 in three cross-cutting ways that this change must preserve:
1. **Pre-session repo sync** — the orchestrator syncs every ready supported repo class (`backend`/`frontend`/`mobile`) to its default branch before the model session (`sync_ready_supported_repo_paths`). This maps to a new `sync/prerequisite-gaps.ts` handler registered in `syncRegistry`, mirroring `sync/contract-delta.ts`.
2. **Sibling in-flight plan sources** — the orchestrator discovers committed sibling features that already have `implementation_plan.md` (`list_committed_sibling_features.sh`) and binds each as a read-only ground-truth source for `scheduled_in_feature <feature-folder>/<step-id>` status. This maps to the existing shared `listCommittedSiblingFeatures` primitive already reused by `context/contract-delta.ts` and `context/surface-map.ts`.
3. **Two-part gate with an EARS literal cross-check** — `check_prerequisite_gaps_quality.sh` validates each prerequisite block's status/surface_kind/surface_identity/evidence/slice_ref rules, then runs a literal cross-check (every URL/route/endpoint literal in `requirements_ears.md` must appear in a prerequisite entry or a `user_reachable_surface` in `technical_requirements.md`), then a `slice_ref` format check. All three port one-for-one to `validate/prerequisite-gaps.ts`.

There is no capture module: all upstream inputs (`requirements_ears.md`, `technical_requirements.md`, `implementation_slices.md`, sibling plans) are in place before step 8.2 runs.

## What Changes

- New skill `packages/installer/_data/skills/overmind-prerequisite-gaps/SKILL.md` with `prerequisite_gaps_rule.md` inlined; `assets/` with the template and golden example
- New context module `packages/asdlc-coordinator/src/context/prerequisite-gaps.ts` — resolves feature path + project root, reads active project classes from `init_progress_definition.yaml` (accepts `backend`/`frontend`/`mobile`/`infrastructure`; requires at least one supported repo class), discovers committed sibling in-flight `implementation_plan.md` sources via `listCommittedSiblingFeatures`, and emits the deterministic context block with the read-only input manifest (`init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `implementation_slices.md`, and each sibling `implementation_plan.md`), target artifact path (`prerequisite_gaps.md`), active repo classes, skill-relative asset references, and exact gate command
- New sync module `packages/asdlc-coordinator/src/sync/prerequisite-gaps.ts` — syncs every ready `backend`/`frontend`/`mobile` repo path to its default branch before the session (ports `sync_ready_supported_repo_paths`), reusing `collectReadyRepoPaths` + `syncRepoToDefaultBranch`; registered in `syncRegistry`
- New gate module `packages/asdlc-coordinator/src/validate/prerequisite-gaps.ts` — ports every check from `check_prerequisite_gaps_quality.sh`: (a) per-`#### Prerequisite:` validation — `surface_kind` present and ∈ {`required_missing_user_reachable_surface`, `present_user_reachable_surface`, `transport_or_internal_execution_gap`}, `status` present and ∈ {`present_in_repo`, `scheduled_in_slices`, `scheduled_in_feature <feature-folder>/<step-id>`, `unmet`}, any `unmet` fails, `present_in_repo` requires evidence, `scheduled_in_slices` requires evidence + non-`none` `slice_ref`, `scheduled_in_feature` requires evidence + `slice_ref: none`, `required_missing_user_reachable_surface` requires a filled operator-facing `surface_identity` and status ∈ {unmet, scheduled_in_slices, scheduled_in_feature}, `present_user_reachable_surface` requires `present_in_repo` status + `surface_identity: none`, and `transport_or_internal_execution_gap` is rejected as an emitted entry; (b) EARS literal cross-check — every URL/route/endpoint literal extracted from `requirements_ears.md` must appear in some prerequisite entry (`evidence`/`slice_ref`) or a `user_reachable_surface` value in `technical_requirements.md`; (c) `slice_ref` format check — a `scheduled_in_slices` `slice_ref` must match `[A-Za-z0-9][A-Za-z0-9_.-]*`; exits `0` on pass, `1` with actionable messages on content failures, `2` on runtime failures (missing target/sibling artifacts)
- No capture module: step 8.2 has no human-input artifact; all inputs are already present when the step runs
- Register `prerequisite-gaps` in `contextRegistry`, `gateRegistry`, and `syncRegistry` in `packages/asdlc-coordinator/src/cli/run.ts`
- Export from `packages/asdlc-coordinator/src/context/index.ts`, `validate/index.ts`, and `sync/index.ts`
- Add TS tests in `packages/asdlc-coordinator` covering context output correctness (path resolution, read-only manifest including sibling plans, active classes, gate command), sync behavior (ready-repo sync, blocked precondition), and all gate scenarios (exit `0`, every exit `1` content failure incl. cross-check + slice_ref, exit `2` runtime failures)
- Add `overmind-prerequisite-gaps` to `PACKAGED_SKILLS` in `packages/installer/src/init.ts`
- Update `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`: replace the legacy phase-8.2 bash invocation with a `run_prerequisite_gaps_skill` function (same Codex skill pattern as phases 8/8.1); run `overmind sync prerequisite-gaps` before the session; snapshot read-only inputs (incl. sibling plans) before session and `cmp`-assert each unchanged after, assert `prerequisite_gaps.md` was produced
- Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`: add `overmind-prerequisite-gaps` to `SKILL_NAMES`, remove legacy script/rule/helper and flat template/golden-example staging references for the old bash
- Update `tests/ai_scripts/project_add_feature_e2e_tests.sh` to cover the skill invocation for phase 8.2
- Delete `overmind/scripts/feature_prerequisite_gaps.sh`
- Delete `overmind/rules/prerequisite_gaps_rule.md`
- Delete `overmind/scripts/helper/check_prerequisite_gaps_quality.sh`
- Delete `tests/ai_scripts/init_feature_prerequisite_gaps_tests.sh`
- Delete `tests/ai_scripts/check_prerequisite_gaps_quality_tests.sh`
- Remove all deleted file references from setup staging arrays, test listings (`CLAUDE.md`), docs, and README
- Mark step 8.2 done in `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md`

## Capabilities

### New Capabilities

- `prerequisite-gaps`: Skill and TS context + sync + gate primitives for step 8.2 (shared feature prerequisite gap trace). Covers the model-invokable `overmind context prerequisite-gaps`, `overmind sync prerequisite-gaps`, and `overmind gate prerequisite-gaps` commands, the inlined rule, all gate checks ported from the bash helper (per-prerequisite validation, EARS literal cross-check, and `slice_ref` format check), and all TS tests proving context output, sync behavior, and gate exit codes.

### Modified Capabilities

- `runner-skill-installation`: Extended to additionally install/stage `overmind-prerequisite-gaps` across supported runners (Codex + Claude), plus clean-break removal of the migrated step-8.2 bash command, rule, helper, and both test suites from ASDLC setup staging.

## Impact

- **New:** `packages/asdlc-coordinator/src/context/prerequisite-gaps.ts`, `packages/asdlc-coordinator/src/sync/prerequisite-gaps.ts`, `packages/asdlc-coordinator/src/validate/prerequisite-gaps.ts`, `packages/installer/_data/skills/overmind-prerequisite-gaps/` (SKILL.md + two assets), and matching TS tests
- **Modified:** `packages/asdlc-coordinator/src/cli/run.ts` (register in context + gate + sync registries), `context/index.ts`, `validate/index.ts`, `sync/index.ts`, `packages/installer/src/init.ts`, `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`, `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`, `tests/ai_scripts/project_add_feature_e2e_tests.sh`, `CLAUDE.md`, docs, README
- **Deleted:** `overmind/scripts/feature_prerequisite_gaps.sh`, `overmind/rules/prerequisite_gaps_rule.md`, `overmind/scripts/helper/check_prerequisite_gaps_quality.sh`, `tests/ai_scripts/init_feature_prerequisite_gaps_tests.sh`, `tests/ai_scripts/check_prerequisite_gaps_quality_tests.sh`
- **Retained:** shared libs (`class_repo_paths.sh`, `sync_repo_to_default_branch.sh`, `list_committed_sibling_features.sh`), surface quality helpers, and all downstream un-migrated step assets (steps 8.3–8.4)
- **No new runtime dependency**; still requires built bundled CLI from `npm run build`
- **Out of scope:** the cross-step TS orchestrator; migrating setup/e2e shell to TS; steps 8.3 (implementation plan), 8.4 (semantic review)
