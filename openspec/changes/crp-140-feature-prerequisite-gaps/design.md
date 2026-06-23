## Context

Step 8.2 (Prerequisite Gaps) is still implemented as a bash orchestrator (`feature_prerequisite_gaps.sh`) + rule (`prerequisite_gaps_rule.md`) + awk gate helper (`check_prerequisite_gaps_quality.sh`). CRP-139 completed migration of step 8.1, leaving step 8.2 as the next row in the migration table.

Step 8.2 shares steps 8/8.1's single-shared-artifact shape and adds three cross-cutting behaviors that must survive the migration:

1. **Pre-session repo sync.** `feature_prerequisite_gaps.sh` calls `sync_ready_supported_repo_paths` (via `class_repo_paths_collect_ready_paths` + `sync_repo_to_default_branch.sh`) to `git pull --rebase` every ready `backend`/`frontend`/`mobile` repo before the model session. Per the settled D7 repo-sync boundary in the architecture overview, this write-side sync becomes `overmind sync prerequisite-gaps <feature-path>`, called by the shell orchestrator before the session — exactly like `sync/contract-delta.ts`.
2. **Sibling in-flight plan sources.** The orchestrator runs `list_committed_sibling_features.sh` to find sibling feature folders that already contain `implementation_plan.md`, binds each as a read-only ground-truth source for `scheduled_in_feature <feature-folder>/<step-id>` decisions, and snapshots them for immutability. The shared `listCommittedSiblingFeatures` primitive (already used by `context/contract-delta.ts` and `context/surface-map.ts`) provides this.
3. **Two-part gate + literal cross-check.** `check_prerequisite_gaps_quality.sh` runs three passes: per-prerequisite structural/semantic validation (`validate_prerequisite_gaps`), an EARS literal cross-check (`run_literal_cross_check`), and a `slice_ref` format check (`validate_slice_refs_in_slices`). All three port one-for-one to `validate/prerequisite-gaps.ts`.

There is no capture module: all upstream inputs (`requirements_ears.md`, `technical_requirements.md`, `implementation_slices.md`, sibling plans) are in place before step 8.2 runs.

## Goals / Non-Goals

**Goals:**
- Introduce `validate/prerequisite-gaps.ts` porting all gate checks from `check_prerequisite_gaps_quality.sh` one-for-one (per-prerequisite validation, EARS literal cross-check, `slice_ref` format check)
- Introduce `context/prerequisite-gaps.ts` replacing the `build_prompt` + class-resolution + sibling-plan-discovery logic from `feature_prerequisite_gaps.sh`
- Introduce `sync/prerequisite-gaps.ts` porting `sync_ready_supported_repo_paths`
- Add `overmind-prerequisite-gaps` skill + assets to `packages/installer/_data/skills/`
- Register in `contextRegistry`, `gateRegistry`, and `syncRegistry` in `cli/run.ts`
- Add installer and setup/e2e wiring with read-only guards
- Delete all migrated bash, rule, helper, and shell test files with no backward-compat shim

**Non-Goals:**
- No capture module (no human-input artifact for this step)
- No `--class` parameter on gate, context, or sync (single shared output, not per-class)
- No changes to steps 8.3–8.4 (implementation plan, semantic review)
- No TS orchestrator / state machine migration
- No `.github`/`.agents` runner fan-out
- No change to the gate's content semantics: `unmet` entries still fail; the per-prerequisite status/surface_kind/surface_identity/evidence/slice_ref rules, the EARS literal cross-check logic, the `slice_ref` format rule, and `scheduled_in_feature` semantics are all preserved one-for-one. Two runtime-precondition behaviors are intentionally **strengthened** (not relaxed), each documented below: (a) missing `requirements_ears.md`/`technical_requirements.md` become hard exit-`2` preconditions rather than a silently-skipped cross-check (D3), and (b) the empty-target check rejects whitespace-only content, not just zero-byte files (empty/absent parity note). These are additive strengthenings; no legacy check is removed or weakened.

## Decisions

**D1 — New dedicated gate module, not a reuse**
Step 8.2's `prerequisite_gaps.md` format and checks are entirely different from the slice, technical-requirements, or surface-map gates. `check_prerequisite_gaps_quality.sh` contains three awk passes plus a shell-level literal cross-check with non-trivial extraction (EARS URL/route/endpoint literal harvesting and containment matching). `validate/prerequisite-gaps.ts` ports this check set one-for-one, including the extraction helpers behavior-for-behavior.

Alternatives considered: a thin wrapper around the existing shell helper — rejected because the migration goal is a clean TS replacement, not a shell-invocation shim.

**D2 — Gate reads sibling artifacts at runtime (same directory-based discovery as the shell helper)**
`overmind gate prerequisite-gaps <feature-path>` derives the target `prerequisite_gaps.md`, `requirements_ears.md`, and `technical_requirements.md` from the feature directory by ascending from the feature path, matching the bash helper's positional-argument set (`<prerequisite_gaps.md> <requirements_ears.md> <technical_requirements.md>`). The `gateRegistry` dispatch passes the feature path; the gate derives the trio from it. This keeps the gate command simple (`overmind gate prerequisite-gaps <feature-path>`) and consistent with the other single-path gate commands.

**D3 — `requirements_ears.md` and `technical_requirements.md` are hard gate preconditions (exit 2)**
The legacy helper's `run_literal_cross_check` skipped the cross-check when either file was absent (`if [[ ! -f ... ]]; then return 0`). However, the legacy orchestrator's `ensure_required_files` guaranteed both files existed before the model ran, so in practice the cross-check always ran. `validate/prerequisite-gaps.ts` makes this explicit: it treats `requirements_ears.md` and `technical_requirements.md` as hard preconditions and exits `2` when either is absent, matching the implementation-slices gate's "Required sibling artifact not found for quality check" behavior. This preserves the effective legacy behavior (cross-check always runs) and prevents a silently-skipped cross-check, an intentional strengthening of read-only-input rigor rather than a removed check.

**Empty vs. absent target artifact (parity note):** the legacy helper exits `2` (`helper_fail`) only when the target file is absent, and exits `1` (content failure) for an empty target. Note the legacy empty check is `[[ ! -s "$target_path" ]]`, which is true only for a **zero-byte** file — a whitespace-only file passes it. `validate/prerequisite-gaps.ts` keeps the absent → `2` split exactly, but **strengthens** the empty check to reject whitespace-only content (`/\S/` test), consistent with the implementation-slices gate migrated in CRP-139. This is an intentional, documented deviation (a stricter emptiness check, never a removed check), not strict `-s` parity: absent target → `2`, empty-or-whitespace-only target → `1`.

**D4 — No per-class invocation; context bundles all inputs in one call**
The bash orchestrator resolves all active classes in one run, requires at least one supported repo class (`backend`/`frontend`/`mobile`), silently skips `infrastructure`, and fails project-class resolution (`fail_project_classes_undefined`, exit 1) on any unrecognized class. The context module follows the same approach in a single `overmind context prerequisite-gaps <feature-path>` call: it emits the feature sibling artifacts and each sibling in-flight `implementation_plan.md` in one read-only manifest and binding block. Any unsupported project class fails resolution with exit `2`.

**D5 — Sibling in-flight plans are guarded read-only inputs**
`context/prerequisite-gaps.ts` lists each committed sibling `implementation_plan.md` (from `listCommittedSiblingFeatures`) in the read-only manifest so the model is instructed not to modify them, and the e2e launcher snapshots and `cmp`-asserts each unchanged. This ports the orchestrator's `collect_in_flight_plan_sources` + `prepare_readonly_inputs` + `ensure_readonly_inputs_unchanged` behavior. When no committed sibling feature has an `implementation_plan.md`, the manifest simply omits them and this is not an error (matches `render_in_flight_context_lines` "none").

**D6 — Pre-session repo sync becomes `overmind sync prerequisite-gaps`, filtered to supported classes**
The orchestrator's `sync_ready_supported_repo_paths` becomes `sync/prerequisite-gaps.ts` + `syncRepoToDefaultBranch`, registered in `syncRegistry`. The e2e launcher runs `overmind sync prerequisite-gaps <feature-path>` before the model session and treats a blocked repo (wrong branch/dirty tree) as a phase precondition failure — mirroring the D7 boundary. The model-invoked `context`/`gate` commands never write to external repos.

Unlike a blind mirror of `sync/contract-delta.ts`, this sync **must not** sync unsupported classes. The legacy `class_repo_paths_collect_ready_paths "$definition_path" "backend,frontend,mobile"` applied a class filter **before** the ready/path-existence checks, so a ready `infrastructure` repo (or one with a missing path) was skipped, not synced and not errored. The current shared `collectReadyRepoPaths(definitionPath)` has no class filter and would throw on / sync any ready class. To port this faithfully, add an optional `supportedClasses?: string[]` parameter to `collectReadyRepoPaths` that filters entries by class before the ready/path validation (default undefined = no filter, preserving existing `contract-delta`/`surface-map` callers), and have `syncPrerequisiteGapsStep` pass `["backend", "frontend", "mobile"]`. A test SHALL prove a ready `infrastructure` repo — including one whose path does not exist — is neither synced nor treated as an error.

**D7 — Delete both shell test suites in the same change**
Both `init_feature_prerequisite_gaps_tests.sh` (orchestrator-level tests) and `check_prerequisite_gaps_quality_tests.sh` (helper tests) are superseded by the TS tests for the gate, context, and sync modules. Both are deleted once TS tests cover the behavior. `CLAUDE.md` is updated in the same change.

## Risks / Trade-offs

**[Risk] The `validate_prerequisite_gaps` awk pass encodes a dense matrix of status × surface_kind × surface_identity × evidence × slice_ref rules that is easy to port subtly wrong** → Ported rule-for-rule with per-rule TS tests: each invalid combination (unmet, missing/invalid surface_kind, missing/invalid status, missing evidence per status, missing/invalid slice_ref, surface_identity presence/absence rules, transport_or_internal_execution_gap rejection) has a dedicated exit-`1` test, plus a passing multi-status fixture.

**[Risk] The EARS literal cross-check extraction (`extract_ears_literals`) uses three regex passes — HTTP-verb paths, backtick-wrapped `/paths`, and bare `/path` tokens — that could drift** → The three extraction passes and the `sort -u` dedupe are ported behavior-for-behavior; TS tests reuse fixtures from `check_prerequisite_gaps_quality_tests.sh` covering a literal covered by a prerequisite entry, a literal covered only by a `user_reachable_surface`, and an uncovered literal (exit `1`).

**[Risk] The literal cross-check degrades to a no-op when requirements/technical files are absent in the legacy helper, but D3 promotes them to hard preconditions** → This is an intentional, documented deviation (D3): effective legacy behavior (orchestrator guaranteed presence) is preserved and made explicit; tests assert exit `2` when either precondition file is absent.

**[Risk] `slice_ref` format check could be lost or applied outside `scheduled_in_slices`** → `validate_slice_refs_in_slices` only checks `slice_ref` format when `status == scheduled_in_slices` and `slice_ref` is filled; this scoping is preserved with tests for a malformed `slice_ref` (exit `1`) and a valid one (no error).

**[Risk] Sync writes to external repos from a model-owned command** → Sync is a deterministic pre-session primitive invoked by the shell orchestrator (`overmind sync`), never by the model session; `context`/`gate` are read-only. This matches D7 in the overview and `sync/contract-delta.ts`.

## Migration Plan

1. Add `packages/asdlc-coordinator/src/validate/prerequisite-gaps.ts` + export + register in `gateRegistry`
2. Add TS tests covering all gate exit-`1` and exit-`2` scenarios ported from `check_prerequisite_gaps_quality_tests.sh`, including both cross-check branches and the `slice_ref` format check
3. Add `packages/asdlc-coordinator/src/context/prerequisite-gaps.ts` + export + register in `contextRegistry`
4. Add `packages/asdlc-coordinator/src/sync/prerequisite-gaps.ts` + export + register in `syncRegistry`
5. Add TS tests covering context path resolution, read-only manifest entries (incl. sibling plans), active-class resolution, gate command emission, and sync ready-repo/blocked behavior
6. Add `packages/installer/_data/skills/overmind-prerequisite-gaps/SKILL.md` + `assets/` (template + golden example)
7. Add `overmind-prerequisite-gaps` to `PACKAGED_SKILLS` in `packages/installer/src/init.ts`
8. Update `project_setup_first_init_machine.sh`: add skill to `SKILL_NAMES`, remove old bash/rule/helper and flat template/golden-example staging constants
9. Update `project_add_feature_e2e.sh`: replace phase-8.2 legacy bash call with `run_prerequisite_gaps_skill`; run `overmind sync prerequisite-gaps` pre-session; add pre-session read-only snapshots and post-session `cmp` guards; assert output was produced
10. Update `tests/ai_scripts/project_add_feature_e2e_tests.sh` to cover the new phase-8.2 skill path
11. Delete `feature_prerequisite_gaps.sh`, `prerequisite_gaps_rule.md`, `check_prerequisite_gaps_quality.sh`, `init_feature_prerequisite_gaps_tests.sh`, `check_prerequisite_gaps_quality_tests.sh`
12. Remove all deleted file references from staging arrays, `CLAUDE.md` test listings, docs, README
13. Mark step 8.2 done in `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md`
14. Run verification: `npm test --workspace packages/asdlc-coordinator`, `npm test --workspace packages/installer`, `bash tests/ai_scripts/project_add_feature_e2e_tests.sh`, `bash tests/ai_scripts/project_setup_asdlc_tests.sh`

Rollback: no backward-compat shim. Reverting the commits restores the old bash path.

## Open Questions

None — design settled.
