## Context

Step 7.1 is an optional enrichment pass: it scans the surface-map files produced by step 7 for the literal `<to be defined during implementation>`, queries a configured knowledge-base MCP source for replacement candidates, collects user confirmation, and patches the confirmed values in place. The step is idempotent and non-blocking — leaving placeholders unchanged is always a valid outcome.

Today the step runs as `feature_surface_map_mcp_placeholder_enrichment.sh`: a bash orchestrator that (1) scans surface maps, (2) collects eligible KB source names from `external_sources.yaml`, (3) builds a model prompt and launches Codex, and (4) flips the `was_enriched_with_mcp: false → true` metadata flag post-session via `sed`. The test suite in `tests/ai_scripts/feature_surface_map_mcp_placeholder_enrichment_tests.sh` covers orchestrator-level scenarios only.

The gate used for quality validation is the existing `validateSurfaceMap` function from `validate/surface-map.ts`, invoked per-class (backend / frontend / mobile). The bash script references `.helper/check_feature_repo_surface_and_exec_context_be_quality.sh` and `.helper/check_feature_repo_surface_and_exec_context_fe_quality.sh` — these map to the same surface-map gate already registered in `run.ts`.

## Goals / Non-Goals

**Goals:**
- Introduce `packages/installer/_data/skills/overmind-surface-map-enrich/SKILL.md` with the inlined enrichment rule
- Introduce `packages/asdlc-coordinator/src/context/surface-map-enrich.ts` that replaces the bash scan + prompt-build logic
- Register `surface-map-enrich` in `contextRegistry` in `cli/run.ts`
- Add TS tests for the context module proving no-op detection and full-context emission
- Add `overmind-surface-map-enrich` to installer `PACKAGED_SKILLS`
- Update setup staging and e2e runner to use the skill
- Delete old bash script, rule file, and shell test suite once TS tests and e2e cover the behavior

**Non-Goals:**
- No new gate module: `validateSurfaceMap` already validates per-class surface maps; the skill tells the model to reuse `node .overmind/overmind.js gate surface-map <path> --class <klass>`
- No capture module: the model queries MCP directly during the skill session; no pre-session human-input artifact is written
- No assets directory inside the skill: the enrichment step does not draft from a template; it patches existing files

## Decisions

**D1 — No dedicated gate, reuse surface-map gate**
The surface maps modified by step 7.1 are in the same format validated by `validateSurfaceMap`. Adding a new gate would duplicate that logic. The SKILL.md references the existing gate command per class.

Alternatives considered: a thin `validate/surface-map-enrich.ts` that only checks `was_enriched_with_mcp: true` — rejected because it is not a structural quality check and would require maintaining a separate gate registration for an assertion the orchestrator flag already covers.

**D2 — Context module emits a no-op signal rather than exiting with error**
When no surface maps contain the placeholder literal, or no eligible KB sources are configured, the context module returns `exitCode: 0` with a special `no_op` block in the context text. The SKILL.md instructs the model to check this field and finish immediately rather than attempting enrichment. This preserves the bash behavior of exiting 0 silently in the no-op case.

Alternatives considered: returning `exitCode: 2` (blocker) for the no-op case — rejected because a no-op is not an error; the step is optional and skipping it cleanly is the expected outcome.

**D3 — `was_enriched_with_mcp` flag flip moves to model**
The old bash orchestrator flips the flag post-session via `sed`. In the skill, the model must write the flag as part of the confirmed patch (alongside the placeholder replacement). The SKILL.md makes this explicit: after applying user-confirmed replacements to a surface map and running the gate successfully, write `was_enriched_with_mcp: true` in the Document Meta section.

**D4 — No per-class invocation split**
The old bash scans all three classes (backend / frontend / mobile) in a single run and lists them in one prompt. The context module follows the same approach: one `context surface-map-enrich <feature-path>` call emits all maps with placeholders for all classes. The model runs the appropriate per-class gate after each confirmed edit.

**D5 — E2e 7.1 phase: Codex skill, same guard pattern as 5.1 (optional with confirm)**
Phase 7.1 is optional. The e2e runner adds `run_surface_map_enrich_skill` matching the pattern of `run_ears_review_skill`: confirm_start → Codex session → check exit. Snapshot + `cmp` read-only-input guards: `external_sources.yaml` and `init_progress_definition.yaml` must be byte-unchanged after the session; these guards replace the bash `ensure_file_unchanged` function.

## Risks / Trade-offs

**[Risk] Model must flip `was_enriched_with_mcp` flag reliably** → SKILL.md makes the flag write a required post-edit step, and the quality gate on the surface map catches structural regressions. The e2e launcher does not auto-flip the flag; the model owns it.

**[Risk] Context exits 0 on no-op but the model session is still launched** → SKILL.md instructs the model to check the `no_op` field first and end the session immediately with a brief confirmation. This is by design: the e2e runner does not check for placeholders before launching; the model decides.

**[Risk] Test gap: flag flip and MCP confirmation logic are model-owned** → TS tests cover deterministic context output; model behavior is covered by e2e test (stub Codex, assert prompt references gate commands and KB source names). The model's repair loop remains untested at unit level, consistent with every other migrated skill.

## Migration Plan

1. Add `packages/asdlc-coordinator/src/context/surface-map-enrich.ts` + export + register
2. Add TS tests for the new context function
3. Add `packages/installer/_data/skills/overmind-surface-map-enrich/SKILL.md` (no assets dir)
4. Add `overmind-surface-map-enrich` to `PACKAGED_SKILLS` in `packages/installer/src/init.ts`
5. Update `project_setup_first_init_machine.sh`: add skill to staging, remove old bash constants
6. Update `project_add_feature_e2e.sh`: replace 7.1 bash call with `run_surface_map_enrich_skill`, add read-only guards
7. Update `tests/ai_scripts/project_add_feature_e2e_tests.sh` to cover the new 7.1 skill path
8. Delete `feature_surface_map_mcp_placeholder_enrichment.sh`, `feature_surface_map_mcp_placeholder_enrichment_rule.md`, and `feature_surface_map_mcp_placeholder_enrichment_tests.sh`
9. Remove all deleted file references from staging arrays, test listings, README, docs
10. Run `npm test --workspace packages/asdlc-coordinator`, `npm test --workspace packages/installer`, `bash tests/ai_scripts/project_add_feature_e2e_tests.sh`, `bash tests/ai_scripts/project_setup_asdlc_tests.sh`

Rollback: no backward-compat shim. Reverting the commits restores the old bash path.

## Open Questions

None — design settled.
