## Why

`design_docs/e2e_orchestrator_migration/06_sh_remove_plan.md` finishes the transition off shell. Overmind has never been installed — no persistent ASDLC workspace exists anywhere — so the remaining `.sh` files are pre-TypeScript scaffolding, not a deployed surface with a backward-compatibility contract.

This change clears the first pieces: the two backend/frontend surface-map validators (`check_feature_repo_surface_and_exec_context_{be,fe}_quality.sh`) are already fully owned by `packages/asdlc-coordinator/src/validate/surface-map.ts`, and their former shell consumer is gone. They are dead production code. It also removes the deployment-history compatibility artifacts an earlier draft added and pins the fresh-install-only baseline the rest of the plan builds on.

## What Changes

- Confirm via a no-consumer audit that both surface-map validators have no production, packaged-skill, CLI, or staging consumer.
- Delete both validators.
- Remove the deployment-history compatibility artifacts (deployed-shell cleanup manifest, historically-staged helper inventory, and their consistency tests) — nothing was ever deployed, so there is nothing to clean up.
- Remove the transitional shell allow-list guard: with no back-compat contract there is no set of "allowed" surviving shell files to track. The single end-state zero-shell assertion lands with the installer cutover instead.
- Record the fresh-install-only installer baseline as the migration closure contract.

## Capabilities

### New Capabilities

- `surface-map-shell-removal`: surface-map structural quality is TypeScript-owned (its shell validators are gone), and the shell-removal effort is scoped to fresh installation with no deployment-history compatibility surface.

### Modified Capabilities

<!-- None. -->

## Impact

- Deletes two unowned shell validators under `overmind/scripts/helper/`.
- Removes the deployed-shell cleanup manifest, historically-staged helper inventory, and the transitional inventory guard test under `packages/installer/`.
- Removes validator-specific stale-workspace fixtures from `tests/ai_scripts/project_setup_asdlc_tests.sh`; the synthetic fixture continues to cover the current shell's generic `.helper` reconcile.
- Aligns `design_docs/e2e_orchestrator_migration/06_sh_remove_plan.md` with the fresh-install, no-parity-ceremony framing.
- Leaves the other 13 production shell files and their owning removal units unchanged.
