## Why

Step 7.1 (MCP placeholder enrichment) is the last optional step in the 4.1–7.1 range still executing as a legacy bash orchestrator. Every other step in that range has been migrated to a TypeScript skill. Migrating this step completes the skill-coverage gap and replaces the shell test suite with a TS test that runs in the standard `npm test` workflow.

## What Changes

- New skill package: `packages/installer/_data/skills/overmind-surface-map-enrich/SKILL.md` (+ `assets/` directory)
- New context module: `packages/asdlc-coordinator/src/context/surface-map-enrich.ts` — scans existing surface maps for the placeholder literal, reads eligible KB source names from `external_sources.yaml`, and emits the deterministic context block
- No new gate module: the step reuses `node .overmind/overmind.js gate surface-map <path> --class <klass>` per modified map
- No capture module: no human-input artifact; the model interacts with MCP sources directly after context is emitted
- Register `surface-map-enrich` in `contextRegistry` in `packages/asdlc-coordinator/src/cli/run.ts`
- Export from `packages/asdlc-coordinator/src/context/index.ts`
- Add TS tests for the context module in `packages/asdlc-coordinator`
- Add `overmind-surface-map-enrich` to `PACKAGED_SKILLS` in `packages/installer/src/init.ts`
- Update `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`: replace legacy bash invocation at phase 7.1 with a `run_surface_map_enrich_skill` function (same Codex skill pattern used by other phases)
- Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`: add `overmind-surface-map-enrich` to `SKILL_NAMES`, remove legacy script constants and staging references for the old bash
- Update `tests/ai_scripts/project_add_feature_e2e_tests.sh` to cover the new skill invocation for 7.1
- Delete `overmind/scripts/feature_surface_map_mcp_placeholder_enrichment.sh`
- Delete `overmind/rules/feature_surface_map_mcp_placeholder_enrichment_rule.md`
- Delete `tests/ai_scripts/feature_surface_map_mcp_placeholder_enrichment_tests.sh`
- Remove all deleted file references from setup staging arrays, test listings, docs, and README

## Capabilities

### New Capabilities

- `surface-map-enrich`: Skill and TS context primitives for Step 7.1 (optional MCP placeholder enrichment of surface-map artifacts). Covers the model-invokable `overmind context surface-map-enrich` command, the inlined enrichment rule, and all TS tests proving context output correctness.

### Modified Capabilities

## Impact

- `packages/asdlc-coordinator/src/context/` — new `surface-map-enrich.ts` + updated `index.ts`
- `packages/asdlc-coordinator/src/cli/run.ts` — new entry in `contextRegistry`
- `packages/installer/src/init.ts` — `overmind-surface-map-enrich` added to `PACKAGED_SKILLS`
- `packages/installer/_data/skills/` — new `overmind-surface-map-enrich/` directory
- `overmind/scripts/project_mgmt/project_add_feature_e2e.sh` — 7.1 phase replaced with skill call
- `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` — staging updated
- `tests/ai_scripts/project_add_feature_e2e_tests.sh` — updated for skill launch at 7.1
- Deleted: `overmind/scripts/feature_surface_map_mcp_placeholder_enrichment.sh`, `overmind/rules/feature_surface_map_mcp_placeholder_enrichment_rule.md`, `tests/ai_scripts/feature_surface_map_mcp_placeholder_enrichment_tests.sh`
