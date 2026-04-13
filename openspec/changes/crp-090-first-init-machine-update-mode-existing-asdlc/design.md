## Context

`overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` currently treats any pre-existing `<selected_parent>/asdlc` directory as a hard error. That behavior was safe for initial bootstrap, but it now blocks a maintenance case where the ASDLC workspace is already initialized, metadata exists, and only staged command scripts under `.commands` need to be restored.

The requested change is intentionally narrow:
- detect an already initialized ASDLC home only when both `asdlc/` and `asdlc/asdlc_metadata.yaml` exist,
- announce that the script is switching to update mode,
- and repair missing staged command scripts under `asdlc/.commands/`.

The existing bootstrap flow for fresh setups must remain intact, including metadata scaffold creation, template staging, quickrun generation, and default path injection into staged commands.

## Goals / Non-Goals

**Goals:**
- Add a safe update-mode path for existing initialized ASDLC homes.
- Gate update mode on the presence of canonical metadata so arbitrary directories are not treated as valid workspaces.
- Ensure `.commands` contains the full required staged command set after update mode completes.
- Backfill missing staged scripts with the same default `asdlc/projects` wiring used during fresh bootstrap.
- Preserve existing metadata and existing staged command files unless a required script is absent.

**Non-Goals:**
- Rebuild or rewrite the entire ASDLC workspace when update mode is entered.
- Change metadata contents or project records during update mode.
- Add new CLI flags/options or introduce a separate repair script.
- Force-refresh already present command files in `.commands`.

## Decisions

1. Use metadata presence as the update-mode discriminator.
Rationale: `asdlc/asdlc_metadata.yaml` is the strongest local signal that the directory is an initialized ASDLC workspace rather than an unrelated folder named `asdlc`.
Alternative considered: switch to update mode whenever `asdlc/` exists. Rejected because it would treat incomplete or unrelated directories as valid workspaces.

2. Keep fail-fast behavior for partial or invalid existing roots.
Rationale: if `asdlc/` exists without metadata, the script cannot safely assume layout ownership. Preserving the current hard stop avoids mutating ambiguous state.
Alternative considered: auto-create missing metadata and continue. Rejected because it blurs bootstrap and repair semantics and increases overwrite risk.

3. Repair only missing staged command scripts.
Rationale: the user request is to add absent `.sh` scripts, not to refresh or overwrite customized local command copies. Update mode should be minimally invasive.
Alternative considered: always recopy all staged commands. Rejected because it could erase user-local adjustments in existing `.commands` files.

4. Reuse the existing staging path logic for repaired commands.
Rationale: repaired files must behave exactly like fresh bootstrap output, especially the injected `ASDLC_PROJECTS_DIR_DEFAULT` pointing at `asdlc/projects`.
Alternative considered: special-case update mode with separate command templates. Rejected because it creates behavioral drift between bootstrap and repair outputs.

5. Treat `.commands` as repairable workspace state.
Rationale: update mode should succeed whether `.commands` already exists with gaps or is missing entirely, as long as the ASDLC root and metadata are valid.
Alternative considered: require `.commands` to already exist before update mode can proceed. Rejected because the primary purpose of update mode is to restore missing staged command state.

## Risks / Trade-offs

- [Risk] Update mode could mask accidental selection of an old ASDLC home.
  Mitigation: print the explicit message `asdlc folder already exists, switch to update mode` before making repair changes.

- [Risk] Existing `.commands` files may diverge from current source behavior if only missing scripts are backfilled.
  Mitigation: keep repair semantics intentionally narrow and document that update mode restores absent commands, not full command refresh.

- [Risk] A partially corrupted ASDLC home without metadata will still fail.
  Mitigation: preserve fail-fast behavior for ambiguous state and surface a clear error rather than making unsafe assumptions.

## Migration Plan

1. Update `project_setup_first_init_machine.sh` to branch after parent-path validation:
   - fresh bootstrap when `asdlc/` is absent,
   - update mode when `asdlc/` and `asdlc_metadata.yaml` are both present,
   - fail fast when `asdlc/` exists without metadata.
2. Ensure update mode creates `.commands` if needed, checks the required staged command set, and stages only absent scripts.
   - `project_setup_add_new_project.sh`
   - `project_setup_update_project.sh`
   - `init_progress_scanner.sh`
   - `init_common_contract_definition.sh`
3. Reuse the existing staged-command rewrite logic so repaired scripts default to `<selected_parent>/asdlc/projects`.
4. Extend script tests to cover:
   - update-mode detection and messaging,
   - absent command restoration,
   - preservation of already present command files,
   - continued failure for existing `asdlc/` without metadata.
5. Update `overmind/README.md` to describe first-init-machine update mode and its repair scope.

Rollback strategy: remove the update-mode branch and restore the prior fail-fast path for all existing `asdlc/` directories.

## Open Questions

- None.
