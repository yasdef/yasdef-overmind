## Context

Step 8 (Technical Requirements) is still implemented as a bash orchestrator (`feature_technical_requirements.sh`) + rule (`technical_requirements_rule.md`) + awk gate helper (`check_feature_technical_requirements_quality.sh`). CRP-137 completed migration of step 7.1, leaving step 8 as the next row in the migration table.

Step 8 differs from the recently migrated steps in two ways:
1. **Multi-class context bundle** — unlike step 7 (one skill invocation per class), step 8 runs once and produces a single `technical_requirements.md` that spans all active repo classes. The context module must resolve each class's surface map and pass all of them as inputs in a single context block.
2. **Substantial gate** — `check_feature_technical_requirements_quality.sh` is a ~780-line awk script that checks seven required sections, nine section-1 scalar keys, three section-2 scalar keys, per-class repository-evidence blocks, per-requirement coverage blocks (with the transport_layer / user_reachable_surface split), component blocks, planning-signal or empty-marker shape, and at least one risk entry. It also reads `init_progress_definition.yaml` (active classes) and `requirements_ears.md` (REQ-*/NFR-* IDs) as runtime context for validation. This entire check set ports one-for-one to `validate/technical-requirements.ts`.

Unlike step 7, step 8 has no `--class` parameter on gate or context — it is always a single run covering all active classes at once.

There is no capture module: all upstream inputs (`requirements_ears.md`, `common_contract_definition.md`, surface maps) are in place before step 8 runs.

## Goals / Non-Goals

**Goals:**
- Introduce `validate/technical-requirements.ts` porting all gate checks from `check_feature_technical_requirements_quality.sh`
- Introduce `context/technical-requirements.ts` replacing the `build_prompt` + class-resolution logic from `feature_technical_requirements.sh`
- Add `overmind-technical-requirements` skill + assets to `packages/installer/_data/skills/`
- Register in `contextRegistry` and `gateRegistry` in `cli/run.ts`
- Add installer and setup/e2e wiring with read-only guards
- Delete all migrated bash, rule, and shell test files with no backward-compat shim

**Non-Goals:**
- No capture module (no human-input artifact for this step)
- No `--class` parameter on gate or context (single shared output, not per-class)
- No changes to steps 8.1–8.4 (implementation slices, prerequisite gaps, implementation plan, semantic review)
- No TS orchestrator / state machine migration
- No `.github`/`.agents` runner fan-out

## Decisions

**D1 — New dedicated gate module, not a reuse**
Step 8 requires its own gate because the format and checks are entirely different from the surface-map gate. The `check_feature_technical_requirements_quality.sh` awk logic is substantial and validates a unique seven-section document structure keyed against runtime-derived data (active classes + requirement IDs). The `validate/technical-requirements.ts` ports this check set one-for-one.

Alternatives considered: a thin wrapper around the existing shell helper — rejected because the migration goal is a clean TS replacement, not a shell-invocation shim.

**D2 — Gate reads sibling artifacts at runtime (same directory-based discovery as the shell helper)**
The gate resolves `init_progress_definition.yaml` and `requirements_ears.md` by ascending from the `technical_requirements.md` target path: feature dir → parent project dir, matching the bash helper's `target_dir` / `project_dir` derivation. The `gateRegistry` dispatch passes the feature path; the gate derives siblings from it. Exit `2` if required siblings are absent.

Alternatives considered: passing all three paths explicitly as CLI args — rejected to keep the gate command simple (`overmind gate technical-requirements <feature-path>`) and match the pattern of other single-path gate commands.

**D3 — Gate reads applicable surface maps to reconstruct `required_repo_csv`**
The gate reads `init_progress_definition.yaml` to derive the active surface-map classes (`backend`/`frontend`/`mobile`; `infrastructure` is skipped), then reads each class's surface map (`project_surface_struct_resp_map_<class>.md`) to rebuild `required_repo_csv` — the set of repos whose surface maps contain at least one `applicability: applicable` entry, requiring at least one `### Component:` block in section 5. This preserves the bash helper's `surface_has_applicable_entries` + `required_repo_csv` logic one-for-one. The gate exits `2` when a required sibling (`init_progress_definition.yaml`, `requirements_ears.md`) or an expected surface map file is missing.

Alternatives considered: derive `required_repo_csv` from `init_progress_definition.yaml` alone without re-reading surface maps — rejected because applicable-entry detection requires reading the actual surface map content, as in the bash helper.

**D4 — No per-class invocation; context module bundles all surface maps in one call**
The bash orchestrator resolves all active classes in one run and emits all surface map paths in the same prompt. The context module follows the same approach: one `overmind context technical-requirements <feature-path>` call emits all applicable surface maps in the read-only manifest and binding block. It preserves the orchestrator's project-class validation: `backend`, `frontend`, `mobile`, and `infrastructure` are valid, `infrastructure` is skipped for surface-map resolution, and any other class blocks context assembly. The skill runs once; the model produces one artifact covering all surface-map classes.

**D5 — Read-only guards in e2e launcher follow every-exit-path pattern from CRP-135/136**
Snapshot `init_progress_definition.yaml`, `requirements_ears.md`, `common_contract_definition.md`, and all applicable surface maps before the session; `cmp`-assert each unchanged after on every exit path. Read-only-corruption error wins on double-failure. Assert `technical_requirements.md` was produced.

**D6 — Delete both shell test suites in the same change**
Both `init_feature_technical_requirements_tests.sh` (orchestrator-level tests) and `check_feature_technical_requirements_quality_tests.sh` (helper tests) are superseded by the TS tests for the gate and context modules. Both are deleted once TS tests cover the behavior. CLAUDE.md is updated in the same change.

## Risks / Trade-offs

**[Risk] Gate awk logic is complex (~780 lines) and easy to miss edge cases when porting** → TS tests map every exit-`1` scenario from `check_feature_technical_requirements_quality_tests.sh` one-for-one; the shell test suite drives the porting checklist before deletion.

**[Risk] Gate reads `requirements_ears.md` to derive valid REQ-*/NFR-* IDs; if the file uses an unexpected heading format the gate may miss IDs** → The awk extractor pattern from the bash helper is ported verbatim (`### Requirement NNN` / `### NFR NNN`); the same test fixtures from the old helper tests are reused to confirm parity.

**[Risk] Surface map resolution fails if a surface-map class has no surface map yet** → Both the context module and the gate exit `2` (blocker) if any surface-map class's (`backend`/`frontend`/`mobile`) expected surface map file is absent. `infrastructure` is silently skipped by both, matching the bash orchestrator's `collect_applicable_surface_maps` behavior. The model stops and surfaces the error to the operator.

**[Risk] `required_repo_csv` logic (which repos need component blocks) depends on surface-map content** → The gate reads the surface maps at validation time to reconstruct this set. Surface maps are read-only inputs stable by the time step 8 runs; their content is not expected to change between context emission and gate invocation.

## Migration Plan

1. Add `packages/asdlc-coordinator/src/validate/technical-requirements.ts` + export + register in `gateRegistry`
2. Add TS tests covering all gate exit-`1` and exit-`2` scenarios ported from `check_feature_technical_requirements_quality_tests.sh`
3. Add `packages/asdlc-coordinator/src/context/technical-requirements.ts` + export + register in `contextRegistry`
4. Add TS tests covering context path resolution, read-only manifest entries, and gate command emission
5. Add `packages/installer/_data/skills/overmind-technical-requirements/SKILL.md` + `assets/` (template + golden example)
6. Add `overmind-technical-requirements` to `PACKAGED_SKILLS` in `packages/installer/src/init.ts`
7. Update `project_setup_first_init_machine.sh`: add skill to `SKILL_NAMES`, remove old bash/rule staging constants
8. Update `project_add_feature_e2e.sh`: replace phase-8 bash call with `run_technical_requirements_skill`; add pre-session `overmind context`-derived read-only snapshots and post-session `cmp` guards; assert output was produced
9. Update `tests/ai_scripts/project_add_feature_e2e_tests.sh` to cover the new phase-8 skill path
10. Delete `feature_technical_requirements.sh`, `technical_requirements_rule.md`, `init_feature_technical_requirements_tests.sh`, `check_feature_technical_requirements_quality_tests.sh`
11. Remove all deleted file references from staging arrays, `CLAUDE.md` test listings, docs, README
12. Mark step 8 done in `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md`
13. Run verification: `npm test --workspace packages/asdlc-coordinator`, `npm test --workspace packages/installer`, `bash tests/ai_scripts/project_add_feature_e2e_tests.sh`, `bash tests/ai_scripts/project_setup_asdlc_tests.sh`

Rollback: no backward-compat shim. Reverting the commits restores the old bash path.

## Open Questions

None — design settled.
