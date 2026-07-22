## Why

Project creation and project update are still owned by three pre-TypeScript shell scripts (`project_setup_add_new_project.sh`, `project_setup_update_project.sh`, `project_setup_common.sh`) that build project metadata, definitions, folders, and the initial git commit through `awk`/`sed`/`grep` and heredocs. This is Unit B of `design_docs/e2e_orchestrator_migration/06_sh_remove_plan.md`: move the project lifecycle into a deterministic TypeScript coordinator primitive plus the already-migrated `overmind project reconcile`, and delete the shell — Overmind has never been installed, so the scripts are behavior reference, not a deployed contract to preserve.

## What Changes

- Add a deterministic project-creation primitive (`capture/project.ts`) and `overmind project create` that: prompts for and normalizes the project name, selects the project type (`A`/`B`/`C`), collects an ordered class selection, captures each class as ready-with-path or deferred, validates and canonicalizes ready repo paths, appends the project record to `asdlc_metadata.yaml`, seeds `init_progress_definition.yaml` from the template with a `meta_info` block, creates the project folder, and runs `git init` + initial commit with a local-identity fallback. Clock, UUID, operator interaction, temp-fixture, and git are injected ports for deterministic tests.
- Make the existing `overmind project reconcile` the **sole** update path: fold the still-useful project-selection and reconciliation-intent operator guidance from `project_setup_update_project.sh` into the reconcile CLI flow so the shell wrapper is no longer needed.
- Absorb the reusable helpers from `project_setup_common.sh` — project-type labels, YAML double-quote escaping, and repo-path validation/resolution — into `capture/project.ts`, `parse/`, and `workspace/` where they architecturally belong (reusing the existing `parse/project-definition.ts` `escapeYamlDoubleQuoted`).
- Delete `project_setup_add_new_project.sh`, `project_setup_update_project.sh`, `project_setup_common.sh`, and the `project_setup_update_project_tests.sh` shell suite; remove their `.commands`/`common_libs` staging in `project_setup_first_init_machine.sh`.
- Update `overmind/README.md`, `QUICKRUN.md`, and generated quick-run guidance to name `overmind project create` and `overmind project reconcile` instead of the shell commands.

## Capabilities

### New Capabilities

- `project-creation`: create an ASDLC project deterministically via `overmind project create` — name normalization, type selection, ordered class selection, ready/deferred repo capture with canonical-path validation, `asdlc_metadata.yaml` append, definition-template population, project-folder creation, and project `git init` + initial commit with local-identity fallback.
- `project-update`: make `overmind project reconcile` the single project update path, absorbing project selection and reconciliation-intent operator guidance from the retired shell wrapper.

### Modified Capabilities

<!-- None. Project creation has no prior TypeScript spec, and the reconcile flow has no OpenSpec spec of record; both are captured as new capabilities in this change. -->

## Impact

- Adds `packages/asdlc-coordinator/src/capture/project.ts` and package tests; extends `packages/asdlc-coordinator/src/git/` with a project `git init`/initial-commit seam (or extends `ProjectGitPort`), and `workspace/`/`parse/` with the absorbed repo-path validation and type-label helpers.
- Extends CLI dispatch in `packages/asdlc-coordinator/src/cli/run.ts` with `project create` and folds project selection + reconciliation-intent guidance into `runProjectReconcile`; updates the `overmind` usage string.
- Deletes three shell files (`project_setup_add_new_project.sh`, `project_setup_update_project.sh`, `project_setup_common.sh`) and the `project_setup_update_project_tests.sh` suite; removes their staging from `project_setup_first_init_machine.sh`.
- Reuses existing seams (`InteractionPort`, injected clock/UUID as in `capture/scaffold-feature.ts`, `parse/project-definition.ts` helpers, `workspace/` discovery/resolution). No runtime `dependencies` added to `packages/asdlc-coordinator` (kept `{}`).
- Touches operator docs (`README.md`, `QUICKRUN.md`) and generated quick-run guidance for the project verbs.
