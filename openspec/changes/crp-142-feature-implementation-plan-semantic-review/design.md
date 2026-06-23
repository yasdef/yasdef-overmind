## Context

Step 8.4 (Implementation Plan Semantic Review, optional) is still implemented as a bash orchestrator (`feature_implementation_plan_semantic_review.sh`) + rule (`implementation_plan_semantic_review_rule.md`) + awk gate helper (`check_implementation_plan_semantic_review_quality.sh`). CRP-141 completed migration of step 8.3 and already rewired step 8.4's cross-step reference to the plan gate onto the shared CLI, leaving step 8.4 as the last row in the migration table.

Step 8.4 differs from the earlier feature steps in three ways:

1. **Two mutable targets.** The model writes `implementation_plan_semantic_review.md` (the review ledger it owns) **and** patches `implementation_plan.md` when the operator selects findings to apply. The structural gate validates only the review ledger; the plan is re-validated by the already-migrated `gate implementation-plan` command whenever it is changed.
2. **Surface maps are read-only inputs.** `collect_applicable_surface_maps` requires the applicable `project_surface_struct_resp_map_{backend,frontend,mobile}.md` for each active repo class and `die`s if one is missing; those maps feed the review's operator-reachability and in-flight-sibling-overlap heuristics. They join the read-only manifest.
3. **Optional step.** Step 8.4 is the optional tail of the pipeline; the e2e phase can be declined at the pre-launch confirmation prompt (`run_phase_by_index` returns `20` on a closed input stream or `30` for an ordinary decline — 8.4 being the final phase, the `10` branch is unreachable — without launching a session, producing no review artifact), and its checkpoint-commit / decline pass-through must be preserved. These decline signals are distinct from a launched Codex session's exit code — a launched model exiting nonzero (including `30`) is a phase failure, not a decline. Because a *declined* phase legitimately produces no output, the output assertion is gated on a clean (`0`) launched-model exit (see D7).

Like step 8.3, step 8.4 has **no pre-session repo sync** (`feature_implementation_plan_semantic_review.sh` never calls `sync_ready_supported_repo_paths`) and **no capture module** (operator finding selection is collected live in the model session, not persisted to a capture artifact). This makes it structurally a **context** module + a **validate** module + a skill, with read-only guards in the e2e launcher — mirroring CRP-139/CRP-141.

The orchestrator's read-only input set is: `init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `prerequisite_gaps.md`, plus the applicable surface maps. Its two mutable targets are `implementation_plan.md` and `implementation_plan_semantic_review.md`; the gate target is `implementation_plan_semantic_review.md`.

## Goals / Non-Goals

**Goals:**
- Introduce `validate/plan-semantic-review.ts` porting all gate checks from `check_implementation_plan_semantic_review_quality.sh` one-for-one (required sections, meta keys, `review_status` enum, findings-ledger/`no_findings` consistency, per-finding required-field/enum checks, terminal-resolution-notes rules, `delivered_surface_consumption_unclear` REQ/NFR reference, `complete`-with-non-terminal rejection, `[UNFILLED]` rejection)
- Introduce `context/plan-semantic-review.ts` replacing the `build_prompt` + class-resolution + surface-map-collection logic from `feature_implementation_plan_semantic_review.sh`, emitting two mutable targets and both gate commands
- Add `overmind-plan-semantic-review` skill + assets to `packages/installer/_data/skills/`
- Register in `contextRegistry` and `gateRegistry` in `cli/run.ts`
- Add installer and setup/e2e wiring with read-only guards over the four base inputs plus applicable surface maps
- Delete all migrated bash, rule, helper, and the shell test file with no backward-compat shim

**Non-Goals:**
- No sync module (step 8.4 performs no pre-session repo sync)
- No capture module (no human-input artifact for this step)
- No `--class` parameter on gate or context (single shared pass, not per-class)
- No migration of worker assignment/readiness (`feature_assing_workers.sh`, `check_implementation_plan_readiness`) and no `.github`/`.agents` runner fan-out
- No TS orchestrator / state machine migration
- No change to the gate's intended content semantics: every structural and per-finding check is preserved. The empty/absent target split is stated explicitly (below) to match the earlier migrated gates

## Decisions

**D1 — New dedicated gate module, not a reuse**
Step 8.4's `implementation_plan_semantic_review.md` review-ledger format and checks are entirely different from the plan, slice, technical-requirements, prerequisite-gaps, or surface-map gates. `validate/plan-semantic-review.ts` ports the review-ledger check set from `check_implementation_plan_semantic_review_quality.sh` one-for-one, including section anchoring (`## 1. Document Meta`, `## 2. Review Guidance`, `## 3. Findings Ledger`), the `### Finding N -`/`### Finding N :` block boundary, the `parse_kv` list-item parsing, and the `is_unfilled`/`normalize_state`/`normalize_bool` helpers behavior-for-behavior. A thin shell-invocation wrapper is rejected because the migration goal is a clean TS replacement.

**D2 — Gate takes the feature path and derives the review artifact**
`overmind gate plan-semantic-review <feature-path>` derives the target `implementation_plan_semantic_review.md` from the feature directory, consistent with the other single-path gate commands (CRP-141 D2). The legacy helper took the review-artifact path directly; the migrated verb takes the feature path and derives the ledger, so the gate command is uniform with `gate implementation-plan <feature-path>`. The gate reads only the review ledger — it does not parse the plan or any sibling input (the legacy helper never did either).

**Empty vs. absent target artifact (parity note):** the legacy helper `helper_fail`s (exit `2`) when the target file is absent, and exits `1` (content failure) for an empty target — its empty check is `grep -q '[^[:space:]]'`, which already rejects **whitespace-only** content, not just zero-byte files. `validate/plan-semantic-review.ts` keeps the absent → `2` split exactly and preserves the whitespace-only → `1` behavior (no strengthening needed here, unlike the step-8.3 gate which had a `-s` zero-byte-only check). Missing target path argument → `2`; awk runtime failure → `2`; content failures → `1`.

**D3 — `init_progress_definition.yaml` / `requirements_ears.md` / `technical_requirements.md` / `prerequisite_gaps.md` and the applicable surface maps are hard context preconditions (exit 2)**
The legacy orchestrator's `ensure_required_files` guaranteed all inputs existed before the model ran, and `collect_applicable_surface_maps` `die`d when an active repo class lacked its surface map. `context/plan-semantic-review.ts` makes these explicit hard preconditions exiting `2` with an actionable message naming the missing file (or the active class whose surface map is absent). This preserves the effective legacy behavior and prevents launching the model without a required input. (The gate itself does not re-check these — only the review ledger it validates — matching the legacy split where the orchestrator preflighted inputs and the helper validated only the ledger.)

**D4 — No per-class invocation; context bundles all inputs in one call; zero supported repo classes is allowed (legacy parity)**
The bash orchestrator resolves all active classes in one run, silently skips `infrastructure`, `die`s on any unrecognized class, and collects the applicable surface map for each active repo class. Critically, it does **not** require at least one supported repo class: `resolve_project_classes` never fails on an empty `ACTIVE_REPO_CLASSES`, `collect_applicable_surface_maps` simply requires no surface maps, and `render_active_repo_class_lines` renders `- none`. `context/plan-semantic-review.ts` preserves this exactly — it accepts zero supported repo classes (emitting active repo classes `none` and an empty applicable-surface-map manifest), silently skips `infrastructure`, and fails resolution with exit `2` only for an unrecognized project class. (This intentionally differs from CRP-141's step-8.3 context, which required at least one supported repo class, because the step-8.4 orchestrator has no such requirement; preserving legacy 8.4 behavior avoids an undocumented strengthening.) The context module emits the read-only inputs (including any applicable surface maps) and the two mutable targets in one binding block. Note the legacy unrecognized-class path is `die` (exit `1`); the migrated context maps it to the context-command runtime-precondition convention exit `2`, consistent with the sibling migrated context commands.

**D5 — Two mutable targets, both gate commands surfaced**
Unlike every earlier feature step, step 8.4 mutates two artifacts. The context block therefore lists `implementation_plan.md` **and** `implementation_plan_semantic_review.md` as allowed writes, and surfaces two gate commands: (a) `node .overmind/overmind.js gate plan-semantic-review <feature-path>` — the review-ledger gate — and (b) `node .overmind/overmind.js gate implementation-plan <feature-path>` — the plan gate. Per the migration guide's "run the gate after every write or repair" invariant (and to match sibling migrations), `SKILL.md` instructs the model to run `gate plan-semantic-review` after every write or repair of `implementation_plan_semantic_review.md` — including the initial findings ledger written before pausing for operator input — and to run `gate implementation-plan` after every write or repair of `implementation_plan.md` (the plan gate necessarily only runs when the plan was actually patched). Both stay model-invoked; the e2e launcher runs neither. The literal success and failure final-response lines live only in `SKILL.md` (not in the e2e prompt), per the guide; `SKILL.md` carries the full apply-selected-findings loop and the two-gate discipline.

**D6 — No sync module and no capture module**
`feature_implementation_plan_semantic_review.sh` has no `sync_ready_supported_repo_paths` call and no human-input capture. This change adds neither `sync/plan-semantic-review.ts` nor `capture/plan-semantic-review.ts`, and registers only `contextRegistry` + `gateRegistry`. The e2e launcher does not run `overmind sync` for phase 8.4. This mirrors CRP-139/CRP-141.

**D7 — E2e read-only guard snapshots exactly the context manifest (no launcher-side class resolution); output assertion is gated on a clean exit**
Following the established migrated-launcher pattern (`run_implementation_plan_skill`), `run_plan_semantic_review_skill` invokes `overmind context plan-semantic-review <feature-path>` **once** and snapshots **exactly** the read-only inputs the context command emits as `- read_only_input: <path>` lines (parsed with `sed -n 's/^- read_only_input: //p'`). It does **not** independently resolve active classes or applicable surface-map paths in the launcher: that parsing/path logic is owned by `context/plan-semantic-review.ts`, and duplicating it in bash risks divergence that could leave a real read-only input unguarded (the exact failure mode the read-only `cmp` guard exists to prevent). Because step 8.4's read-only manifest is dynamic (the surface-map set depends on active classes), sourcing it from the single context call — rather than a hardcoded list — is what keeps the guard and the model's bound inputs in lockstep. This still ports the orchestrator's `prepare_readonly_inputs`/`snapshot_readonly_inputs`/`ensure_readonly_inputs_unchanged` intent (the four base inputs plus applicable surface maps), but with a single authoritative source. It does **not** guard `implementation_plan.md` (a mutable target the step may legitimately patch), and it does not run either gate.

**Exit-path ordering (decline signal vs. launched-session failure).** Phase 8.4 is optional. Two distinct exit families must not be conflated:

- **Pre-launch decline/skip**, owned by `run_phase_by_index`: when the operator declines the optional phase at the confirmation prompt, `run_phase_by_index` returns `20` (input stream closed) or, for an ordinary decline, `30` — *before any Codex session is launched*. No session runs, no review artifact is produced (legitimately), no guard runs, and no output is asserted. `30` is generated **only** on this pre-launch path. Because 8.4 is the **final** phase, `has_later_required_phase` is always false, so an ordinary decline returns `30`; the `10` "later required phase remains" branch is unreachable for 8.4. The reachable decline outcomes are therefore exactly `{20, 30}`.
- **Launched-session outcome**, owned by `run_plan_semantic_review_skill`: once a Codex session is launched, the model's exit code is captured under `set +e`. The function then applies this order on every exit path: (1) always run the read-only `cmp` guards first — a read-only-input corruption failure takes precedence over every other outcome (corruption wins, even on double-failure); (2) if the model exited **nonzero**, return that nonzero exit unchanged so `run_phase_by_index` maps any launched-command nonzero exit to phase failure (`PHASE_EXECUTION_FAILED_RC = 40`) — a launched Codex exit of `30` is a model failure, **not** the decline signal, and must never be treated as a clean top-level exit; (3) assert `implementation_plan_semantic_review.md` was produced only after a clean (`0`) model exit.

Conflating a launched Codex `30` with the pre-launch decline would silently mask a model failure, so the skill function never re-interprets the model exit as a decline. The existing before/after phase-8.4 checkpoint commits and the pre-launch decline (`20`/`30` for this final phase) pass-through in `run_phase_by_index` are preserved.

**D8 — Delete the single shell test suite in the same change, after a recorded parity sweep**
`init_feature_implementation_plan_semantic_review_tests.sh` (the only step-8.4 shell test; it covers both the orchestrator and the helper) is superseded by the TS tests for the gate and context modules plus the e2e-runner tests. Per the migration guide (Preflight Inventory + Preserve Instruction Quality), a recorded responsibility inventory and comparison table are produced **before** deleting any legacy file, and any `missing` row blocks deletion (tasks Section 10). Both **`CLAUDE.md` and `AGENTS.md`** list this test suite in their canonical test commands and must both have the reference removed (they are separate, independently maintained files — `AGENTS.md` is not a symlink). `README.md` and the migration overview doc are updated in the same change.

**D9 — Clean-break deletion with no downstream rewire needed**
Step 8.4 is the last row in the migration table and CRP-141 already rewired its reference to the plan gate onto the shared CLI. `check_implementation_plan_semantic_review_quality.sh` has no other consumer (it is only run by `feature_implementation_plan_semantic_review.sh`, which is deleted). Deleting the whole step-8.4 bash surface therefore requires no compatibility shim and leaves no dangling reference. The alternative — staging the bash helper until "later" — is rejected because there is no later step for it and it would leave a divergent second source of the review gate.

## Risks / Trade-offs

**[Risk] The per-finding validation encodes a matrix of required fields, enum checks, and conditional resolution-notes/requirement-reference rules that is easy to port subtly wrong** → Ported field-for-field and branch-for-branch with per-rule TS tests: each failure (missing section, missing/unfilled meta key, invalid `review_status`, `no_findings` inconsistency in both directions, missing/unfilled finding field, invalid `severity`/`finding_type`/`state`, terminal `delivered_surface_consumption_unclear`/`repo_scaffold_readiness_unclear` with empty `resolution_notes`, `delivered_surface_consumption_unclear` without a REQ/NFR ref, `complete` with non-terminal findings, `[UNFILLED]` present) has a dedicated exit-`1` test, plus a passing findings-present fixture and a passing `no_findings: true` fixture.

**[Risk] Two mutable targets could let the migrated skill lose the "run the plan gate only when the plan changed, always run the review gate" discipline the legacy prompt encoded** → `SKILL.md` states the two-gate discipline explicitly and the context block surfaces both commands; a context test asserts both gate commands appear, and an e2e test asserts the launcher runs neither gate itself.

**[Risk] The e2e launcher must guard the read-only inputs while leaving `implementation_plan.md` mutable — an over-broad `cmp` guard would fail every legitimate apply-findings run** → `run_plan_semantic_review_skill` snapshots only the four base inputs plus applicable surface maps and never snapshots `implementation_plan.md`; an e2e test asserts a phase pass when only `implementation_plan.md` changes and a phase fail when a read-only input (e.g. `technical_requirements.md` or a surface map) is mutated.

**[Risk] A missing surface map for an active repo class must fail before launching the model (legacy `collect_applicable_surface_maps` `die`)** → `context/plan-semantic-review.ts` exits `2` naming the active class whose surface map is absent; a context test covers it.

## Migration Plan

1. Add `packages/asdlc-coordinator/src/validate/plan-semantic-review.ts` + export + register in `gateRegistry`
2. Add TS tests covering all gate exit-`1` and exit-`2` scenarios ported from the helper (sections, meta keys, review_status, findings-ledger consistency, per-finding checks, `[UNFILLED]`)
3. Add `packages/asdlc-coordinator/src/context/plan-semantic-review.ts` + export + register in `contextRegistry`
4. Add TS tests covering context path resolution, read-only manifest (incl. surface maps), mutable targets, active-class resolution, both gate commands, and missing-surface-map exit `2`
5. Add `packages/installer/_data/skills/overmind-plan-semantic-review/SKILL.md` + `assets/` (review template + golden example)
6. Add `overmind-plan-semantic-review` to `PACKAGED_SKILLS` in `packages/installer/src/init.ts`
7. Update `project_setup_first_init_machine.sh`: add skill to `SKILL_NAMES`, remove old bash/rule/helper and flat template/golden-example staging constants, add the command to `OBSOLETE_STAGED_COMMAND_FILES`
8. Update `project_add_feature_e2e.sh`: replace phase-8.4 legacy bash call with `run_plan_semantic_review_skill` following the `run_implementation_plan_skill` pattern — invoke `context plan-semantic-review` once and snapshot exactly its `- read_only_input:` manifest (no launcher-side class/surface-map resolution); do not guard the plan; apply the D7 exit-path ordering (guards always run and corruption wins; return any launched-model nonzero exit — including `30` — to `run_phase_by_index` for mapping to phase failure; assert output only on a clean `0` exit); no sync, no gate; preserve checkpoint commits and the pre-launch decline (`20`/`30`) pass-through
9. Update `tests/ai_scripts/project_add_feature_e2e_tests.sh` to cover the new phase-8.4 skill path, including a launched-model-nonzero (incl. `30`) → phase-failure case and a pre-launch decline no-output case
10. Record the parity inventory + comparison table (guide Preflight/Preserve) and confirm no `missing` row before any deletion
11. Delete `feature_implementation_plan_semantic_review.sh`, `implementation_plan_semantic_review_rule.md`, `check_implementation_plan_semantic_review_quality.sh`, `init_feature_implementation_plan_semantic_review_tests.sh`
12. Remove all deleted file references from staging arrays and from **both `CLAUDE.md` and `AGENTS.md`** test listings, docs, README
13. Mark step 8.4 done in `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md`
14. Run verification: `npm test --workspace packages/asdlc-coordinator`, `npm test --workspace packages/installer`, `bash tests/ai_scripts/project_add_feature_e2e_tests.sh`, `bash tests/ai_scripts/project_setup_asdlc_tests.sh`

Rollback: no backward-compat shim. Reverting the commits restores the old bash path.

## Open Questions

None — design settled.
