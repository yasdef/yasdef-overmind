## Context

Step 8.3 (Implementation Plan) is still implemented as a bash orchestrator (`feature_implementation_plan.sh`) + rule (`implementation_plan_rule.md`) + awk gate helper (`check_implementation_plan_quality.sh`). CRP-140 completed migration of step 8.2, leaving step 8.3 as the next row in the migration table.

Step 8.3 shares steps 8/8.1/8.2's single-shared-artifact shape. Unlike step 8.2 (CRP-140), it has **two fewer cross-cutting behaviors**:

1. **No pre-session repo sync.** `feature_implementation_plan.sh` never calls `sync_ready_supported_repo_paths`; it only resolves classes, snapshots read-only inputs, launches the model, and asserts the output was produced + read-only inputs unchanged. There is no `sync/implementation-plan.ts` module.
2. **No capture module.** All upstream inputs (`requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, `implementation_slices.md`, `prerequisite_gaps.md`) are in place before step 8.3 runs.

This makes step 8.3 structurally identical to CRP-139 (implementation-slices): a **context** module + a **validate** module + a skill, with read-only guards in the e2e launcher. The distinguishing feature is the **size and density of the gate**: `check_implementation_plan_quality.sh` (≈35 KB) derives four catalogs from three read-only inputs before running a per-step + whole-plan awk validator. All of it must port one-for-one to `validate/implementation-plan.ts`.

The orchestrator's read-only input set is six files: `init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, `implementation_slices.md`, `prerequisite_gaps.md`. The single target output is `implementation_plan.md`.

## Goals / Non-Goals

**Goals:**
- Introduce `validate/implementation-plan.ts` porting all gate checks from `check_implementation_plan_quality.sh` one-for-one (four catalog extractors, per-step structural/semantic checks, whole-plan coverage checks including the canonical-surface preservation matcher)
- Introduce `context/implementation-plan.ts` replacing the `build_prompt` + class-resolution logic from `feature_implementation_plan.sh`
- Add `overmind-implementation-plan` skill + assets to `packages/installer/_data/skills/`
- Register in `contextRegistry` and `gateRegistry` in `cli/run.ts`
- Add installer and setup/e2e wiring with read-only guards
- Delete all migrated bash, rule, helper, and shell test files with no backward-compat shim

**Non-Goals:**
- No sync module (step 8.3 performs no pre-session repo sync)
- No capture module (no human-input artifact for this step)
- No `--class` parameter on gate or context (single shared output, not per-class)
- No migration of step 8.4's own semantic-review gate/rule/skill, and no changes to worker assignment/readiness. Step 8.4's **cross-step reference to the step-8.3 plan gate** is rewired to the new CLI (see D8) because deleting the bash helper would otherwise break the still-bash step 8.4 — this is wiring only, not a migration of step 8.4 itself
- No TS orchestrator / state machine migration
- No `.github`/`.agents` runner fan-out
- No change to the gate's intended content semantics: every per-step and whole-plan check is preserved. Four runtime-precondition/structural behaviors are intentionally **strengthened** (not relaxed), each documented below: (a) an absent `prerequisite_gaps.md` becomes a hard exit-`2` precondition (matching the legacy helper's bare `exit 2`, made explicit with an actionable message) (D3), (b) the empty-target check rejects whitespace-only content, not just zero-byte files (empty/absent parity note), (c) a duplicate non-empty `#### Evidence:` declaration on a step is rejected uniformly (D9 — legacy tolerated an empty first `#### Evidence:` line followed by a filled one), and (d) scheduled `slice_ref` extraction is independent of field order within its prerequisite block (D10). These are additive strengthenings; no intended coverage check is removed or weakened.

## Decisions

**D1 — New dedicated gate module, not a reuse**
Step 8.3's `implementation_plan.md` format and checks are entirely different from the slice, technical-requirements, prerequisite-gaps, or surface-map gates. `check_implementation_plan_quality.sh` is the largest gate in the pipeline: four catalog extractors (`extract_meta_project_classes`, `extract_requirement_refs`, `extract_technical_evidence_catalog`, and two prerequisite extractors for scheduled slice_refs and required missing surfaces) plus a dense per-step + whole-plan awk validator (`validate_content`) including a canonical-surface fuzzy matcher (`canonical_surface`/`has_surface_terms`/`looks_supporting_only`/`surface_matches`). `validate/implementation-plan.ts` ports this check set one-for-one, including the extraction and canonicalization helpers behavior-for-behavior.

Alternatives considered: a thin wrapper around the existing shell helper — rejected because the migration goal is a clean TS replacement, not a shell-invocation shim.

**D2 — Gate reads sibling artifacts at runtime (same directory-based discovery as the shell helper)**
`overmind gate implementation-plan <feature-path>` derives the target `implementation_plan.md`, and from its directory the siblings `requirements_ears.md`, `technical_requirements.md`, `prerequisite_gaps.md`, and the parent project's `init_progress_definition.yaml` — matching the bash helper's `target_dir`/`project_dir` derivation. The `gateRegistry` dispatch passes the feature path; the gate derives the rest from it. This keeps the gate command simple (`overmind gate implementation-plan <feature-path>`) and consistent with the other single-path gate commands. (Note: the gate does not read `feature_contract_delta.md` or `implementation_slices.md` — those are model-facing planning inputs the orchestrator marks read-only but the helper never parses; the context/e2e read-only manifest still lists them.)

**D3 — `prerequisite_gaps.md` (and `requirements_ears.md`/`technical_requirements.md`/`init_progress_definition.yaml`) are hard gate preconditions (exit 2)**
The legacy helper `helper_fail`s (exit 2) when `requirements_ears.md`, `technical_requirements.md`, or `init_progress_definition.yaml` is absent, and bare-`exit 2`s when `prerequisite_gaps.md` is absent. `validate/implementation-plan.ts` makes all four explicit hard preconditions exiting `2` with an actionable message naming the missing file. This preserves the effective legacy behavior (the orchestrator's `ensure_required_files` guaranteed all inputs existed before the model ran) and prevents a silently-skipped derivation, an intentional strengthening of read-only-input rigor rather than a removed check.

**Empty vs. absent target artifact (parity note):** the legacy helper `helper_fail`s (exit `2`) when the target file is absent, and exits `1` (content failure) for an empty target. Note the legacy empty check is `[[ ! -s "$target_path" ]]`, which is true only for a **zero-byte** file — a whitespace-only file passes it. `validate/implementation-plan.ts` keeps the absent → `2` split exactly, but **strengthens** the empty check to reject whitespace-only content (`/\S/` test), consistent with the implementation-slices and prerequisite-gaps gates migrated in CRP-139/CRP-140. This is an intentional, documented deviation (a stricter emptiness check, never a removed check), not strict `-s` parity: absent target → `2`, empty-or-whitespace-only target → `1`.

**D4 — No per-class invocation; context bundles all inputs in one call**
The bash orchestrator resolves all active classes in one run, requires at least one supported repo class (`backend`/`frontend`/`mobile`), silently skips `infrastructure`, and fails project-class resolution (`fail_project_classes_undefined`, exit 1) on any unrecognized class. The context module follows the same approach in a single `overmind context implementation-plan <feature-path>` call: it emits the six read-only inputs in one manifest and binding block. Any unsupported project class fails resolution with exit `2`.

**D5 — No sync module and no capture module**
Unlike CRP-140, `feature_implementation_plan.sh` has no `sync_ready_supported_repo_paths` call and no human-input capture. This change therefore adds neither `sync/implementation-plan.ts` nor `capture/implementation-plan.ts`, and registers only `contextRegistry` + `gateRegistry`. The e2e launcher does not run `overmind sync` for phase 8.3. This mirrors CRP-139 exactly.

**D6 — Catalog extraction is ported behavior-for-behavior, section-anchored**
`extract_technical_evidence_catalog` is section-sensitive: `## 4. Requirement Coverage and Gaps` yields `req_all`/`req_unresolved` `gap/TECH_REQ-*` tokens keyed by `gap_status: fully_implemented` / `gap_to_close: no remaining gap|none|n/a`; `## 5. Impacted Components` yields `comp_all`/`comp_unresolved` `comp/<slug>` tokens (slug via the `slugify` rule) and `repo_unresolved` repos keyed by `repo:` + `gap_to_close`. `extract_requirement_refs` harvests `REQ-*`/`NFR-*` ids **only from `###` heading lines** — the awk block is guarded by `/^###[[:space:]]+/`, so it matches `### Requirement N` / `### NFR N` headings and any `(REQ|NFR)-N` tokens that appear *inline within those heading lines*; `REQ-*`/`NFR-*` tokens that appear only in requirement **body** text (bullets, prose) are ignored. The port preserves this heading-only scope exactly. The two prerequisite extractors harvest scheduled `slice_ref`s (`status: scheduled_in_slices`, filled `slice_ref`) and required missing surfaces (`surface_kind: required_missing_user_reachable_surface` with `status ∈ {scheduled_in_slices, unmet}` and a filled `surface_identity`). Except for the intentional scheduled-slice field-order strengthening in D10, these extractors preserve the legacy selection rules. Dedicated TS unit tests cover both extractors.

**D7 — Delete both shell test suites in the same change**
Both `init_feature_implementation_plan_tests.sh` (orchestrator-level tests) and `check_implementation_plan_quality_tests.sh` (helper tests) are superseded by the TS tests for the gate and context modules. Both are deleted once TS tests cover the behavior. `CLAUDE.md` is updated in the same change. The un-migrated `check_implementation_plan_readiness_tests.sh` and `feature_assign_workers_to_implementation_plan_tests.sh` (worker assignment/readiness, a separate concern) remain.

**D8 — Rewire step 8.4's plan-gate reference to the new gate CLI, then delete the bash helper**
Step 8.4 (`feature_implementation_plan_semantic_review.sh`, still bash) is the only remaining consumer of `check_implementation_plan_quality.sh`: it lists the helper in `ensure_required_files` and exposes it to the model as the "Implementation plan quality gate command" (`.helper/check_implementation_plan_quality.sh <plan-path>`) so the semantic-review model can re-validate the plan. It does **not** execute the helper from the orchestrator (the only orchestrator-run gate in 8.4 is its own semantic-review helper). Deleting `check_implementation_plan_quality.sh` and unstaging it therefore breaks step 8.4 at startup.

Because the plan-gate logic now lives in `validate/implementation-plan.ts` behind `node .overmind/overmind.js gate implementation-plan <feature-path>`, the fix is to rewire step 8.4's cross-step reference to that CLI command rather than retain a duplicate bash helper. Concretely: **replace** the `IMPLEMENTATION_PLAN_QUALITY_GATE_HELPER` required-file entry with an `OVERMIND_CLI_FILE` (`.overmind/overmind.js`) entry in `ensure_required_files`, and change the model-facing "Implementation plan quality gate command" to `node .overmind/overmind.js gate implementation-plan <feature-path>`. Preflighting the CLI matters: the legacy orchestrator preflighted the helper precisely because it hands it to the model in the prompt; swapping the referenced dependency without swapping the preflight would let step 8.4 launch the model with an unusable gate command when `.overmind/overmind.js` is missing. This keeps the reference model-invoked (rule 4 compliant), removes the last consumer of the bash helper, and preserves the clean-break deletion. This is wiring only — step 8.4's own semantic-review gate, rule, template, golden example, and skill migration are deferred to the step-8.4 change.

Alternative considered: retain `check_implementation_plan_quality.sh` staged until step 8.4 migrates. Rejected because it leaves two divergent sources of the plan gate (bash helper + TS validator) live simultaneously and violates the clean-break "no old helper references remain" definition of done; the TS gate is already the single source of truth once this change lands.

**D9 — Duplicate `#### Evidence:` declaration is rejected uniformly (documented strengthening)**
Legacy's per-field duplicate detection uses the field's parsed value as its presence marker (`if (current_evidence != "")`). Empty `#### Depends on:` and `#### Preserved Surface:` values fail through their explicit inline checks; an empty `#### Repo:` fails through the active-class and allowed-value checks before also failing the end-of-step missing-field check. `#### Evidence:` is the exception: its handler has no inline empty-value check (only the end-of-step check catches a still-empty Evidence), so legacy tolerates an empty `#### Evidence:` line followed by a second, filled `#### Evidence:` line. No legacy test exercises this path. `validate/implementation-plan.ts` rejects any second `#### Evidence:` declaration on a step (treating Evidence like the other single-declaration fields), an intentional, documented structural strengthening. A single empty `#### Evidence:` value emits only the legacy-equivalent "missing evidence" diagnostic; an empty `#### Repo:` preserves the legacy active-class, allowed-value, and missing-field diagnostics without an additional generic empty-value message.

**D10 — Scheduled `slice_ref` extraction is field-order independent (documented strengthening)**
The legacy awk extractor emitted a `slice_ref` only when it encountered that line after `status: scheduled_in_slices` in the same `#### Prerequisite:` block. The TypeScript extractor parses the complete block first, then selects a filled, non-`none` `slice_ref` when the block status is `scheduled_in_slices`. This intentionally removes an incidental line-order dependency: a scheduled prerequisite creates the same plan coverage obligation whether `slice_ref` appears before or after `status`. The canonical template still places `status` first. A focused extractor test locks the order-independent behavior.

## Risks / Trade-offs

**[Risk] The `validate_content` awk pass encodes a very large matrix of per-step structural rules, dependency-edge rules, evidence-token rules, and whole-plan coverage checks that is easy to port subtly wrong** → Ported rule-for-rule with per-rule TS tests: each failure (missing/duplicate Repo/Depends on/Evidence/Preserved Surface, non-active/invalid repo, out-of-order/duplicate step id, missing heading ref, unknown heading ref, <3 bullets, missing plan/review bullet, empty/duplicate/unknown/invalid evidence token, no valid evidence token, invalid/duplicate/empty/self-or-later dependency, `[UNFILLED]`, no steps, uncovered required repo, uncovered requirement id, uncovered unresolved req/comp token, uncovered scheduled slice_ref, unpreserved or coordination-only required surface) has a dedicated exit-`1` test, plus a passing multi-step multi-repo fixture.

**[Risk] The canonical-surface matcher (`canonical_surface`/`surface_matches`/`has_surface_terms`/`looks_supporting_only`) uses layered gsub normalization + token-scoring that could drift** → The normalization substitutions, the specific/content token scoring, the weak-content-token set, and the supporting-only heuristic are ported substitution-for-substitution and branch-for-branch; TS tests reuse fixtures covering a preserved surface that matches by canonical token, a non-operator-facing preserved surface (exit `1`), a supporting-only step marking a preserved surface (exit `1`), and a required surface covered only by a coordination step (exit `1`).

**[Risk] The technical evidence catalog is section-anchored (`## 4.`/`## 5.`) and status-keyed; mis-sectioning would misclassify unresolved tokens** → `extract_technical_evidence_catalog` is ported with the exact section triggers, `flush_requirement`/`flush_component` boundaries, `slugify`, and `is_no_remaining_gap`/`gap_status` resolution rules, with unit tests over a fixture exercising resolved vs. unresolved requirements and components across both sections.

**[Risk] `prerequisite_gaps.md` absence degrades to a bare `exit 2` in the legacy helper with no message; D3 makes it an explicit actionable precondition** → This is an intentional, documented deviation (D3): effective legacy behavior (orchestrator guaranteed presence) is preserved and made explicit; tests assert exit `2` naming the missing file.

**[Risk] The e2e launcher must guard six read-only inputs, one more than smaller steps** → `run_implementation_plan_skill` snapshots all six (`init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, `implementation_slices.md`, `prerequisite_gaps.md`) and `cmp`-asserts each byte-unchanged after the session on every exit path, porting the orchestrator's `prepare_readonly_inputs`/`snapshot_readonly_inputs`/`ensure_readonly_inputs_unchanged` exactly.

## Migration Plan

1. Add `packages/asdlc-coordinator/src/validate/implementation-plan.ts` + export + register in `gateRegistry`
2. Add TS tests covering all gate exit-`1` and exit-`2` scenarios ported from `check_implementation_plan_quality_tests.sh`, including all four catalog extractors, per-step checks, and whole-plan coverage checks
3. Add `packages/asdlc-coordinator/src/context/implementation-plan.ts` + export + register in `contextRegistry`
4. Add TS tests covering context path resolution, read-only manifest entries, active-class resolution, and gate command emission
5. Add `packages/installer/_data/skills/overmind-implementation-plan/SKILL.md` + `assets/` (template + golden example)
6. Add `overmind-implementation-plan` to `PACKAGED_SKILLS` in `packages/installer/src/init.ts`
7. Update `project_setup_first_init_machine.sh`: add skill to `SKILL_NAMES`, remove old bash/rule/helper and flat template/golden-example staging constants
8. Update `project_add_feature_e2e.sh`: replace phase-8.3 legacy bash call with `run_implementation_plan_skill`; add pre-session read-only snapshots and post-session `cmp` guards; assert output was produced (no sync)
9. Update `tests/ai_scripts/project_add_feature_e2e_tests.sh` to cover the new phase-8.3 skill path
10. Delete `feature_implementation_plan.sh`, `implementation_plan_rule.md`, `check_implementation_plan_quality.sh`, `init_feature_implementation_plan_tests.sh`, `check_implementation_plan_quality_tests.sh`
11. Remove all deleted file references from staging arrays, `CLAUDE.md` test listings, docs, README
12. Mark step 8.3 done in `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md`
13. Run verification: `npm test --workspace packages/asdlc-coordinator`, `npm test --workspace packages/installer`, `bash tests/ai_scripts/project_add_feature_e2e_tests.sh`, `bash tests/ai_scripts/project_setup_asdlc_tests.sh`

Rollback: no backward-compat shim. Reverting the commits restores the old bash path.

## Open Questions

None — design settled.
