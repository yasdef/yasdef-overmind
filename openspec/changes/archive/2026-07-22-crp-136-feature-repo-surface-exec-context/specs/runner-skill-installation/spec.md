## ADDED Requirements

### Requirement: surface-map Skill Runner Installation

Overmind installation SHALL additionally install the packaged `overmind-surface-map` skill into each supported local runner skill directory (`.codex/skills/overmind-surface-map/` and `.claude/skills/overmind-surface-map/`) for a runtime ASDLC workspace, joining `overmind-task-to-br`, `overmind-repo-br-scan`, `overmind-br-clarification`, `overmind-requirements-ears`, `overmind-ears-review`, and `overmind-contract-delta`, while keeping `.overmind/overmind.js` as the single shared runtime CLI. Each installed `overmind-surface-map` skill folder SHALL contain `SKILL.md` and an `assets/` directory holding both the backend and the frontend/mobile surface-map templates and golden examples. The TypeScript `overmind init` installer SHALL return installation metadata covering the new skill path, and SHALL fail before writing runner targets when the packaged `overmind-surface-map` payload (`SKILL.md` + `assets/`) is incomplete.

#### Scenario: surface-map skill installed for Codex and Claude via init

- **WHEN** `overmind init` runs in a project
- **THEN** `<project>/.codex/skills/overmind-surface-map/SKILL.md` and `<project>/.claude/skills/overmind-surface-map/SKILL.md` exist
- **AND** each installed skill folder contains its packaged `assets/` directory with the backend and frontend/mobile templates and golden examples
- **AND** `<project>/.overmind/overmind.js` remains the only installed CLI path with no runner-specific CLI copy

#### Scenario: ASDLC setup stages the surface-map skill

- **WHEN** `project_setup_first_init_machine.sh` creates or updates an ASDLC workspace after `npm run build`
- **THEN** the workspace contains `.codex/skills/overmind-surface-map/SKILL.md` and `.claude/skills/overmind-surface-map/SKILL.md` alongside the six previously migrated skill folders
- **AND** `.overmind/overmind.js` staging behavior is unchanged
- **AND** update mode repairs a missing or stale `overmind-surface-map` runner skill folder from canonical source

#### Scenario: Incomplete payload fails before writing runner targets

- **WHEN** the packaged `overmind-surface-map` skill is missing `SKILL.md` or `assets/`
- **THEN** installation fails before writing any runner skill target

### Requirement: Migrated Surface-Map Bash Assets Are Not Staged

`project_setup_first_init_machine.sh` SHALL NOT stage the migrated step 7 orchestrator bash assets — the `feature_repo_surface_and_exec_context.sh` command and the `feature_repo_surface_and_exec_context_rule.md` rule — into a runtime ASDLC workspace. Update mode SHALL remove these staged files when they exist in an already-provisioned workspace. The two surface quality helpers `check_feature_repo_surface_and_exec_context_be_quality.sh` and `check_feature_repo_surface_and_exec_context_fe_quality.sh` SHALL remain staged, because the un-migrated step 7.1 (`feature_surface_map_mcp_placeholder_enrichment.sh`) requires and invokes them. The shared `class_repo_paths.sh`, `sync_repo_to_default_branch.sh`, `list_committed_sibling_features.sh`, and `check_cross_class_peer_trigger.sh` libs/helpers, and the downstream un-migrated step assets (step 7.1 onward), SHALL also remain staged, as those are not migrated by this change.

#### Scenario: Fresh setup omits the migrated orchestrator assets but keeps the shared helpers

- **WHEN** `project_setup_first_init_machine.sh` creates a fresh ASDLC workspace
- **THEN** `.commands/feature_repo_surface_and_exec_context.sh` and `.rules/feature_repo_surface_and_exec_context_rule.md` are not present
- **AND** `.helper/check_feature_repo_surface_and_exec_context_be_quality.sh` and `.helper/check_feature_repo_surface_and_exec_context_fe_quality.sh` remain staged (required by step 7.1)
- **AND** the shared repo/cross-class/sibling libs and the downstream un-migrated step commands, rules, and helpers remain staged

#### Scenario: Update mode removes stale migrated orchestrator assets

- **WHEN** `project_setup_first_init_machine.sh` runs in update mode for a workspace that still contains the migrated step 7 command or rule
- **THEN** those staged files are removed, and the `overmind-surface-map` runner skill folders are present instead
- **AND** the two surface quality helpers and the shared repo/cross-class/sibling libs remain staged

### Requirement: Surface-Map Templates And Golden Examples Are Skill-Local

`project_setup_first_init_machine.sh` SHALL deploy `project_surface_struct_resp_map_be_TEMPLATE.md`, `project_surface_struct_resp_map_fe_TEMPLATE.md`, `project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md`, and `project_surface_struct_resp_map_fe_GOLDEN_EXAMPLE.md` only under each installed `overmind-surface-map/assets/` directory. It SHALL NOT stage duplicate flat copies under `.templates/` or `.golden_examples/`. Update mode SHALL remove those flat copies when they exist in an already-provisioned workspace through the support-directory exact-manifest cleanup.

#### Scenario: Fresh setup omits flat surface-map assets

- **WHEN** `project_setup_first_init_machine.sh` creates a fresh ASDLC workspace
- **THEN** both runner skill folders contain the backend and frontend/mobile templates and golden examples under `assets/`
- **AND** `.templates/project_surface_struct_resp_map_be_TEMPLATE.md`, `.templates/project_surface_struct_resp_map_fe_TEMPLATE.md`, `.golden_examples/project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md`, and `.golden_examples/project_surface_struct_resp_map_fe_GOLDEN_EXAMPLE.md` are absent

#### Scenario: Update mode removes stale flat surface-map assets

- **WHEN** update mode runs for a workspace containing the legacy flat surface-map templates or golden examples
- **THEN** those flat files are removed while the skill-local assets remain installed
