## Context

Step 8.1 (Implementation Slices) is still implemented as a bash orchestrator (`feature_implementation_slices.sh`) + rule (`implementation_slices_rule.md`) + awk gate helper (`check_implementation_slices_quality.sh`). CRP-138 completed migration of step 8, leaving step 8.1 as the next row in the migration table.

Step 8.1 shares step 8's shape and differs from it in the gate:
1. **Multi-class context bundle** — like step 8 (and unlike step 7), step 8.1 runs once and produces a single `implementation_slices.md` that spans all active repo classes. The context module resolves each surface-map class's map and passes all of them, plus the three feature-level sibling artifacts, as read-only inputs in one context block. There is no `--class` parameter.
2. **Slice-shaped gate with an optional prerequisite-gap cross-check** — `check_implementation_slices_quality.sh` validates a four-section slice document (`## 1. Document Meta`, `## 2. Slice Planning Guardrails`, `## 3. Slice Candidates`, `## 4. Handoff To Ordered Plan`), twelve section-1 meta keys, per-slice field/evidence/checklist rules, coordination-slice `signal_ref` gating, operator-facing-surface preservation, and forbidden lifecycle boilerplate. It reads `init_progress_definition.yaml` (active classes) at validation time, and — **only when `prerequisite_gaps.md` exists** — reads it to extract required missing operator-facing surfaces and enforces that each is covered by some slice's `preserved_operator_surface` via semantic `surface_matches` matching. This entire check set ports one-for-one to `validate/implementation-slices.ts`.

There is no capture module: all upstream inputs (`requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, surface maps) are in place before step 8.1 runs.

## Goals / Non-Goals

**Goals:**
- Introduce `validate/implementation-slices.ts` porting all gate checks from `check_implementation_slices_quality.sh` one-for-one, including the optional `prerequisite_gaps.md` surface-coverage cross-check and the semantic `surface_matches`/`canonical_surface` matching
- Introduce `context/implementation-slices.ts` replacing the `build_prompt` + class/surface-map-resolution logic from `feature_implementation_slices.sh`
- Add `overmind-implementation-slices` skill + assets to `packages/installer/_data/skills/`
- Register in `contextRegistry` and `gateRegistry` in `cli/run.ts`
- Add installer and setup/e2e wiring with read-only guards
- Delete all migrated bash, rule, helper, and shell test files with no backward-compat shim

**Non-Goals:**
- No capture module (no human-input artifact for this step)
- No `--class` parameter on gate or context (single shared output, not per-class)
- No changes to steps 8.2–8.4 (prerequisite gaps, implementation plan, semantic review)
- No TS orchestrator / state machine migration
- No `.github`/`.agents` runner fan-out
- No behavior change to the gate: coordination slices stay optional; absence of coordination slices remains valid; the prerequisite-gap surface cross-check stays conditional on the file's presence

## Decisions

**D1 — New dedicated gate module, not a reuse**
Step 8.1 requires its own gate because the slice-document format and checks are entirely different from the technical-requirements or surface-map gates. The `check_implementation_slices_quality.sh` awk logic is substantial and includes non-trivial semantic surface matching (`canonical_surface` synonym folding + token-overlap `surface_matches`). The `validate/implementation-slices.ts` ports this check set one-for-one, including the helper functions verbatim in behavior.

Alternatives considered: a thin wrapper around the existing shell helper — rejected because the migration goal is a clean TS replacement, not a shell-invocation shim.

**D2 — Gate reads sibling artifacts at runtime (same directory-based discovery as the shell helper)**
The gate resolves `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, and `prerequisite_gaps.md` from the feature directory, and `init_progress_definition.yaml` from the parent project directory, by ascending from the `implementation_slices.md` target path (feature dir → parent project dir), matching the bash helper's `target_dir` / `project_dir` derivation. The `gateRegistry` dispatch passes the feature path; the gate derives siblings from it. Exit `2` if `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, or `init_progress_definition.yaml` is absent (all four are hard preconditions in the helper).

Alternatives considered: passing all paths explicitly as CLI args — rejected to keep the gate command simple (`overmind gate implementation-slices <feature-path>`) and match the pattern of other single-path gate commands.

**D3 — `prerequisite_gaps.md` is an optional gate input, preserved as conditional**
The bash helper reads `prerequisite_gaps.md` **only if it exists** (`if [[ -f "$prerequisite_gaps_path" ]]`). When present, it extracts required missing operator-facing surfaces (prerequisite blocks whose `status` is `scheduled_in_slices`/`unmet` and `surface_kind` is `required_missing_user_reachable_surface`, with a filled `surface_identity`) and enforces that each is semantically covered by some slice's non-`none` `preserved_operator_surface`. Step 8.2 (prerequisite gaps) is not yet migrated, so on a first slice run `prerequisite_gaps.md` may be absent and this cross-check is skipped; on a re-run after 8.2 it activates. `validate/implementation-slices.ts` preserves this exact conditionality — absence of `prerequisite_gaps.md` is not a gate failure.

Alternatives considered: making `prerequisite_gaps.md` a hard precondition — rejected because it would break the first-pass ordering (slices run before prerequisite gaps) and diverge from the shell helper.

Because the gate consumes `prerequisite_gaps.md` to enforce required-surface coverage, this change **strengthens** the legacy behavior by treating `prerequisite_gaps.md` as a guarded read-only input **when it is already present**: the context module lists it in the read-only manifest and the e2e launcher snapshots and `cmp`-asserts it unchanged. The legacy orchestrator's `prepare_readonly_inputs` did not snapshot it, so a model could in principle have mutated it to weaken the cross-check; the guard closes that gap. This is an intentional, documented deviation from strict one-for-one parity (an added deterministic guard, never a removed check), consistent with the migration guide's emphasis on preserving/strengthening read-only-input immutability. Its absence is never an error.

**Empty vs. absent target artifact (parity note):** the legacy helper exits `1` (content failure) for an empty/whitespace-only `implementation_slices.md` and exits `2` (helper failure) only when the target file is absent. `validate/implementation-slices.ts` preserves this split exactly: absent target → `2`, empty target → `1`.

**D4 — No per-class invocation; context module bundles all surface maps in one call**
The bash orchestrator resolves all active classes in one run (`collect_applicable_surface_maps`) and emits all surface map paths in the same prompt, requiring at least one supported surface-map class. The context module follows the same approach: one `overmind context implementation-slices <feature-path>` call emits all applicable surface maps plus the three feature sibling artifacts in the read-only manifest and binding block. It preserves the orchestrator's project-class validation: `backend`, `frontend`, `mobile`, `infrastructure` are valid; `infrastructure` is skipped for surface-map resolution; any other class fails project-class resolution (exit `2`). The skill runs once; the model produces one artifact covering all surface-map classes.

**D5 — Read-only guards in e2e launcher follow every-exit-path pattern from CRP-135/136/138**
Snapshot `init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, all applicable surface maps, and — when present before the session — `prerequisite_gaps.md`, before the session; `cmp`-assert each snapshotted input unchanged after on every exit path. Read-only-corruption error wins on double-failure. Assert `implementation_slices.md` was produced. This ports the orchestrator's `snapshot_readonly_inputs` / `ensure_readonly_inputs_unchanged` / output-produced guards into the launcher and additionally guards `prerequisite_gaps.md` when present (see D3).

**D6 — Delete both shell test suites in the same change**
Both `init_feature_implementation_slices_tests.sh` (orchestrator-level tests) and `check_implementation_slices_quality_tests.sh` (helper tests) are superseded by the TS tests for the gate and context modules. Both are deleted once TS tests cover the behavior. `CLAUDE.md` is updated in the same change.

**D7 — Scope `[UNFILLED]` rejection to structured placeholder values**
The legacy helper rejected the case-insensitive substring `[UNFILLED]` anywhere in the artifact. The TypeScript gate intentionally narrows this check to recognized field values, slice titles, and checklist bullets whose complete value is a bracketed placeholder containing `UNFILLED`. This preserves rejection of unchanged template values such as `[UNFILLED]`, `[none|UNFILLED]`, `[UNFILLED title]`, and `[UNFILLED concrete implementation slice]`, while allowing substantive prose that merely refers to the placeholder convention. This is a deliberate post-review deviation from strict helper parity to avoid false positives.

## Risks / Trade-offs

**[Risk] Gate awk logic includes non-trivial semantic surface matching (`canonical_surface` synonym folding + weighted token overlap in `surface_matches`) that is easy to port subtly wrong** → The helper's `canonical_surface`, `has_surface_terms`, `looks_supporting_only`, `is_weak_content_token`, and `surface_matches` functions are ported behavior-for-behavior; TS tests reuse the fixtures from `check_implementation_slices_quality_tests.sh`, including required-surface coverage match/near-miss cases, to confirm parity.

**[Risk] The optional `prerequisite_gaps.md` cross-check could be lost, silently dropping required-surface enforcement** → The conditional read is preserved explicitly (D3) and covered by tests for both branches: absent file (cross-check skipped, gate can pass) and present file with an uncovered required surface (exit `1`).

**[Risk] Evidence-token grammar (`gap/TECH_REQ-N`, `gap/TECH_REQ-NFR-N`, `comp/<slug>`) and forbidden-boilerplate literals drift during porting** → Ported as exact regex/string checks with per-case tests (valid token, invalid token, empty token, forbidden `Plan and discuss the slice` / `Review slice readiness` bullets).

**[Risk] Surface map resolution fails if a surface-map class has no surface map yet** → Both the context module and the gate's active-class derivation follow the orchestrator: context exits `2` if an active surface-map class's map file is absent; `infrastructure` is silently skipped by both. The model stops and surfaces the error to the operator.

## Migration Plan

1. Add `packages/asdlc-coordinator/src/validate/implementation-slices.ts` + export + register in `gateRegistry`
2. Add TS tests covering all gate exit-`1` and exit-`2` scenarios ported from `check_implementation_slices_quality_tests.sh`, including both `prerequisite_gaps.md` branches
3. Add `packages/asdlc-coordinator/src/context/implementation-slices.ts` + export + register in `contextRegistry`
4. Add TS tests covering context path resolution, read-only manifest entries, active-class resolution, and gate command emission
5. Add `packages/installer/_data/skills/overmind-implementation-slices/SKILL.md` + `assets/` (template + golden example)
6. Add `overmind-implementation-slices` to `PACKAGED_SKILLS` in `packages/installer/src/init.ts`
7. Update `project_setup_first_init_machine.sh`: add skill to `SKILL_NAMES`, remove old bash/rule/helper and flat template/golden-example staging constants
8. Update `project_add_feature_e2e.sh`: replace phase-8.1 legacy bash call with `run_implementation_slices_skill`; add pre-session read-only snapshots and post-session `cmp` guards; assert output was produced
9. Update `tests/ai_scripts/project_add_feature_e2e_tests.sh` to cover the new phase-8.1 skill path
10. Delete `feature_implementation_slices.sh`, `implementation_slices_rule.md`, `check_implementation_slices_quality.sh`, `init_feature_implementation_slices_tests.sh`, `check_implementation_slices_quality_tests.sh`
11. Remove all deleted file references from staging arrays, `CLAUDE.md` test listings, docs, README
12. Mark step 8.1 done in `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md`
13. Run verification: `npm test --workspace packages/asdlc-coordinator`, `npm test --workspace packages/installer`, `bash tests/ai_scripts/project_add_feature_e2e_tests.sh`, `bash tests/ai_scripts/project_setup_asdlc_tests.sh`

Rollback: no backward-compat shim. Reverting the commits restores the old bash path.

## Open Questions

None — design settled.
