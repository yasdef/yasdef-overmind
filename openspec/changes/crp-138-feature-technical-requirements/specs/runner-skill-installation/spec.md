## MODIFIED Requirements

### Requirement: surface-map Skill Runner Installation

Overmind installation SHALL additionally install the packaged `overmind-technical-requirements` skill into each supported local runner skill directory (`.codex/skills/overmind-technical-requirements/` and `.claude/skills/overmind-technical-requirements/`) for a runtime ASDLC workspace, joining `overmind-task-to-br`, `overmind-repo-br-scan`, `overmind-br-clarification`, `overmind-requirements-ears`, `overmind-ears-review`, `overmind-contract-delta`, `overmind-surface-map`, and `overmind-surface-map-enrich`, while keeping `.overmind/overmind.js` as the single shared runtime CLI. Each installed `overmind-technical-requirements` skill folder SHALL contain `SKILL.md` and an `assets/` directory holding the technical-requirements template and golden example. The TypeScript `overmind init` installer SHALL return installation metadata covering the new skill path, and SHALL fail before writing runner targets when the packaged `overmind-technical-requirements` payload (`SKILL.md` + `assets/`) is incomplete.

#### Scenario: technical-requirements skill installed for Codex and Claude via init
- **WHEN** `overmind init` runs in a project
- **THEN** `<project>/.codex/skills/overmind-technical-requirements/SKILL.md` and `<project>/.claude/skills/overmind-technical-requirements/SKILL.md` exist
- **AND** each installed skill folder contains its packaged `assets/` directory with the template and golden example
- **AND** `<project>/.overmind/overmind.js` remains the only installed CLI path with no runner-specific CLI copy

#### Scenario: ASDLC setup stages the technical-requirements skill
- **WHEN** `project_setup_first_init_machine.sh` creates or updates an ASDLC workspace after `npm run build`
- **THEN** the workspace contains `.codex/skills/overmind-technical-requirements/SKILL.md` and `.claude/skills/overmind-technical-requirements/SKILL.md` alongside the eight previously migrated skill folders
- **AND** `.overmind/overmind.js` staging behavior is unchanged
- **AND** update mode repairs a missing or stale `overmind-technical-requirements` runner skill folder from canonical source

#### Scenario: Incomplete payload fails before writing runner targets
- **WHEN** the packaged `overmind-technical-requirements` skill is missing `SKILL.md` or `assets/`
- **THEN** installation fails before writing any runner skill target

### Requirement: Migrated Technical-Requirements Bash Assets Are Not Staged

`project_setup_first_init_machine.sh` SHALL NOT stage the migrated step 8 bash assets — `feature_technical_requirements.sh` command, `technical_requirements_rule.md` rule, and `check_feature_technical_requirements_quality.sh` helper — into a runtime ASDLC workspace. Update mode SHALL remove these staged files when they exist in an already-provisioned workspace. The shared `class_repo_paths.sh`, `sync_repo_to_default_branch.sh`, `list_committed_sibling_features.sh`, `check_cross_class_peer_trigger.sh`, the surface quality helpers, and all downstream un-migrated step assets (steps 8.1–8.4) SHALL remain staged, as those are not migrated by this change.

#### Scenario: Fresh setup omits the migrated step-8 bash assets
- **WHEN** `project_setup_first_init_machine.sh` creates a fresh ASDLC workspace
- **THEN** `.commands/feature_technical_requirements.sh`, `.rules/technical_requirements_rule.md`, and `.helper/check_feature_technical_requirements_quality.sh` are not present
- **AND** the shared repo/cross-class/sibling libs, the surface quality helpers, and the downstream un-migrated step commands, rules, and helpers remain staged

#### Scenario: Update mode removes stale migrated step-8 assets
- **WHEN** `project_setup_first_init_machine.sh` runs in update mode for a workspace that still contains the migrated step-8 command, rule, or helper
- **THEN** those staged files are removed, and the `overmind-technical-requirements` runner skill folders are present instead
- **AND** the shared libs and downstream un-migrated step assets remain staged

### Requirement: Technical-Requirements Template And Golden Example Are Skill-Local

`project_setup_first_init_machine.sh` SHALL deploy `technical_requirements_TEMPLATE.md` and `technical_requirements_GOLDEN_EXAMPLE.md` only under each installed `overmind-technical-requirements/assets/` directory. It SHALL NOT stage flat copies under `.templates/` or `.golden_examples/`. Update mode SHALL remove those flat copies when they exist in an already-provisioned workspace.

#### Scenario: Fresh setup omits flat technical-requirements assets
- **WHEN** `project_setup_first_init_machine.sh` creates a fresh ASDLC workspace
- **THEN** both runner skill folders contain the template and golden example under `assets/`
- **AND** `.templates/technical_requirements_TEMPLATE.md` and `.golden_examples/technical_requirements_GOLDEN_EXAMPLE.md` are absent

#### Scenario: Update mode removes stale flat technical-requirements assets
- **WHEN** update mode runs for a workspace containing the legacy flat template or golden example
- **THEN** those flat files are removed while the skill-local assets remain installed
