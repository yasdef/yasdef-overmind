## Context

`overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` currently bootstraps only `asdlc/.commands/` plus the visible compatibility template path `asdlc/templates/init_progress_definition_TEMPLATE.yaml`. Update mode, introduced in `crp-090`, repairs missing staged commands but does not stage or refresh the broader set of repo-owned support assets that Overmind scripts depend on: rules, templates, golden examples, helper scripts, and setup files.

The user request expands the machine-local ASDLC contract so update mode can bring an existing ASDLC home into a consistent repo-aligned state. The current repository layout already gives a natural source inventory:
- `overmind/rules/`
- `overmind/templates/`
- `overmind/golden_examples/`
- `overmind/scripts/helper/`
- `overmind/setup/`

This change should remain narrow:
- no new CLI flags/options,
- no change to `asdlc/.commands/` overwrite rules,
- and no migration of current project-bootstrap consumers away from `asdlc/templates/init_progress_definition_TEMPLATE.yaml`.

## Goals / Non-Goals

**Goals:**
- Stage repository-owned support assets into deterministic ASDLC-local directories.
- Make update mode refresh those staged support assets so an existing ASDLC home matches current repo-owned content.
- Preserve the visible `asdlc/templates/init_progress_definition_TEMPLATE.yaml` compatibility path used by current project setup flows.
- Reuse shared staging logic between bootstrap and update paths so the asset inventory and copy semantics stay aligned.

**Non-Goals:**
- Change staged-command repair from missing-only to overwrite-in-place.
- Remove or rename the existing visible `asdlc/templates/` compatibility directory.
- Delete user-added files from staged support-asset directories as part of sync.
- Introduce a separate manifest file or new operator-facing commands for asset synchronization.

## Decisions

1. Use one explicit source-to-target asset mapping inside `project_setup_first_init_machine.sh`.
Rationale: bootstrap and update mode must stage the same support-asset groups, and a single mapping table avoids copy/paste drift between code paths.
Alternative considered: maintain separate bootstrap and update file lists. Rejected because the current gap exists precisely due to behavior divergence between those paths.

2. Treat staged support assets as repo-managed mirrors, but keep staged commands as missing-only repair.
Rationale: the user explicitly asked to "add/update" rules, templates, golden examples, and helper scripts so the local ASDLC environment stays consistent with the repository. Existing `.commands` files may contain local operator tweaks, so their narrower repair semantics should remain unchanged.
Alternative considered: make both commands and support assets overwrite-in-place during update mode. Rejected because it broadens scope and risks clobbering local command customizations not covered by the request.

3. Preserve `asdlc/templates/init_progress_definition_TEMPLATE.yaml` as a compatibility copy alongside the new `.templates` mirror.
Rationale: current add-project behavior depends on the visible `templates/` path. Keeping that file synchronized avoids coupling this change to a broader consumer-path migration.
Alternative considered: move all consumers immediately to `asdlc/.templates/`. Rejected because it introduces unnecessary downstream changes and regression risk.

4. Synchronize managed files in place without deleting unknown extras.
Rationale: "consistent environment" requires current repo-owned files to exist and be refreshed, but deletion of extra local files adds risk and was not requested. Refresh-in-place is enough to make managed assets current.
Alternative considered: hard mirror with deletion of files not present in source directories. Rejected because it could erase local experiments or future staged artifacts outside this change's ownership.

5. Preserve executable bits for staged helper scripts on both bootstrap and update.
Rationale: helper scripts are shell entrypoints, so copying content without executable permissions would produce a broken local environment.
Alternative considered: rely on filesystem defaults from `cp`. Rejected because explicit permission setting is more robust across environments and copy modes.

## Risks / Trade-offs

- [Risk] Update mode will overwrite staged support-asset edits made directly inside `asdlc/.rules/`, `.templates/`, `.golden_examples/`, `.helper/`, or `.setup/`.  
  Mitigation: document these directories as repo-managed mirrors and keep the overwrite behavior limited to support assets, not `.commands`.

- [Risk] The visible compatibility template and hidden `.templates` mirror could drift if the script updates only one of them.  
  Mitigation: route both through the same canonical template source and test both bootstrap and update behavior.

- [Risk] Asset inventory may grow over time and bootstrap/update logic could silently miss new files if copy behavior is too hand-maintained.  
  Mitigation: stage all regular files directly from the source directories rather than enumerating individual filenames in multiple places.

## Migration Plan

1. Refactor `project_setup_first_init_machine.sh` to define the support-asset source/target mapping and shared staging helpers.
2. Extend bootstrap flow to create/populate `.rules`, `.templates`, `.golden_examples`, `.helper`, and `.setup`, while continuing to localize `init_progress_definition_TEMPLATE.yaml` into `asdlc/templates/`.
3. Extend update mode to create missing support-asset directories and refresh their managed files from the current repository sources.
4. Keep `.commands` behavior unchanged except for the existing missing-file repair path.
5. Update `tests/ai_scripts/project_setup_asdlc_tests.sh` and `overmind/README.md` to cover the expanded local ASDLC support-asset contract.

Rollback strategy: remove support-asset staging/sync helpers, keep existing `.commands` repair behavior, and retain only the visible compatibility template localization.

## Open Questions

- None.
