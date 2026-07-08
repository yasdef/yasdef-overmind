## Context

`design_docs/e2e_orchestrator_migration/06_sh_remove_plan.md` finishes the rewrite off shell. Overmind has never been installed, so the surviving `.sh` files are pre-TypeScript scaffolding — behavior reference, not a deployed contract. This change removes the two surface-map validators whose behavior already has a TypeScript owner, and strips the deployment-history compatibility artifacts and the transitional inventory guard an earlier draft added under the assumption that shell had been deployed.

## Goals / Non-Goals

**Goals:**

- Delete both surface-map shell validators after a no-consumer audit.
- Keep stable `0`/`1`/`2` surface-map gate semantics through the TypeScript owner, `validate/surface-map.ts`.
- Remove the deployment-history compatibility artifacts and the transitional shell allow-list guard.
- Pin the fresh-install-only installer baseline.
- Keep `npm run verify` and the shell suites green.

**Non-Goals:**

- Migrating any of the other 13 production shell files.
- Implementing the TypeScript installer cutover.
- Adding CLI verbs, flags, or options.
- Maintaining any transitional shell allow-list or per-slice inventory.

## Decisions

### 1. Delete both validators as dead code

Neither validator is staged or consumed by any production script, packaged skill, CLI gate, or staging configuration. `validate/surface-map.ts` is the sole surface-map quality owner, exercised through the `overmind gate surface-map` CLI and its `surface-map-*.test.ts` coverage. Because the validators are dead code with no consumer, a no-consumer audit is sufficient to remove them safely — there is no running behavior to preserve, so no responsibility/parity inventory gates the deletion.

### 2. No deployment-history compatibility artifacts

An earlier draft added a deployed-shell cleanup manifest and a historically-staged helper inventory on the assumption that shell had been deployed and would need cleanup on upgrade. Nothing was ever deployed, so these carry no contract and are removed. The current shell's generic `.helper` reconcile remains covered by the synthetic `obsolete_helper.sh` fixture; validator-specific stale-copy fixtures add no coverage under the fresh-install baseline and are removed with them.

### 3. No transitional shell allow-list guard

With no backward-compatibility contract there is no set of "allowed" surviving shell files to track, and no reason to maintain a monotonically shrinking allow-list edited in every removal unit. The transitional inventory guard is therefore removed rather than shrunk. The end state is asserted once — a single repository- and package-wide zero-shell assertion that lands with the installer cutover (`06_sh_remove_plan.md ## Work units`, unit D).

### 4. Fresh-install installer baseline

`packages/installer` will bootstrap a new ASDLC workspace from the TypeScript package payload (CLI, packaged skills, runtime templates, setup defaults, generated guidance). Since no persistent workspace exists, the migration carries no deployed-shell cleanup manifest, historical staging inventory, or direct-upgrade contract.

## No-consumer audit record

- `feature_surface_map_mcp_placeholder_enrichment.sh` (the former step 7.1 orchestrator) is absent from `overmind/scripts/`.
- Searches of `overmind/scripts/`, `packages/installer/_data/skills/`, and `packages/asdlc-coordinator/src/` found no invocation, source, requirement, or staging reference to either validator.
- `project_setup_first_init_machine.sh` stages three other helpers and does not stage either validator.
- The installed `overmind-surface-map` skill invokes `node .overmind/overmind.js gate surface-map <feature-path> --class <class>`.
- The CLI class-gate registry maps `surface-map` to `validateSurfaceMap`; no second production implementation remains.

The `BACKEND_CONFIG`/`FRONTEND_CONFIG` split in `validate/surface-map.ts` already covers the class-specific title, sections, layer/surface, `project_classes`, applicability, and pass-message differences the two shell validators encoded; `surface-map-validator.test.ts` and `surface-map-cli.test.ts` exercise the `0`/`1`/`2` classifications.

## Risks / Trade-offs

- **Hidden consumer:** the audit covers production scripts, packaged skills, CLI dispatch, and staging configuration; all clear.
- **Future persistent installation:** creating one before the installer cutover would change the migration baseline and require an explicit upgrade decision.

## Migration Plan

1. Record the no-consumer audit.
2. Delete the two validators.
3. Remove the deployment-history compatibility artifacts, the transitional inventory guard, and validator-specific stale-copy fixtures.
4. Run package, shell, repository, and strict OpenSpec verification.

Rollback restores the two source validators.

## Open Questions

- None.
