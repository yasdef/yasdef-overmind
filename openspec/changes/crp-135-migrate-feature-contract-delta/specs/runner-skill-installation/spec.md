## ADDED Requirements

### Requirement: contract-delta Skill Runner Installation

Overmind installation SHALL additionally install the packaged `overmind-contract-delta` skill into each supported local runner skill directory (`.codex/skills/overmind-contract-delta/` and `.claude/skills/overmind-contract-delta/`) for a runtime ASDLC workspace, joining `overmind-task-to-br`, `overmind-repo-br-scan`, `overmind-br-clarification`, `overmind-requirements-ears`, and `overmind-ears-review`, while keeping `.overmind/overmind.js` as the single shared runtime CLI. The TypeScript `overmind init` installer SHALL return installation metadata covering the new skill path, and SHALL fail before writing runner targets when the packaged `overmind-contract-delta` payload (`SKILL.md` + `assets/`) is incomplete.

#### Scenario: contract-delta skill installed for Codex and Claude via init

- **WHEN** `overmind init` runs in a project
- **THEN** `<project>/.codex/skills/overmind-contract-delta/SKILL.md` and `<project>/.claude/skills/overmind-contract-delta/SKILL.md` exist
- **AND** each installed skill folder contains its packaged `assets/` directory
- **AND** `<project>/.overmind/overmind.js` remains the only installed CLI path with no runner-specific CLI copy

#### Scenario: ASDLC setup stages the contract-delta skill

- **WHEN** `project_setup_first_init_machine.sh` creates or updates an ASDLC workspace after `npm run build`
- **THEN** the workspace contains `.codex/skills/overmind-contract-delta/SKILL.md` and `.claude/skills/overmind-contract-delta/SKILL.md` alongside the `overmind-task-to-br`, `overmind-repo-br-scan`, `overmind-br-clarification`, `overmind-requirements-ears`, and `overmind-ears-review` skill folders
- **AND** `.overmind/overmind.js` staging behavior is unchanged
- **AND** update mode repairs a missing or stale `overmind-contract-delta` runner skill folder from canonical source

#### Scenario: Incomplete payload fails before writing runner targets

- **WHEN** the packaged `overmind-contract-delta` skill is missing `SKILL.md` or `assets/`
- **THEN** installation fails before writing any runner skill target

### Requirement: Migrated Contract-Delta Bash Assets Are Not Staged

`project_setup_first_init_machine.sh` SHALL NOT stage the migrated step 6 bash assets — the `feature_contract_delta.sh` command, the `feature_contract_delta_rule.md` rule, and the `check_feature_contract_delta_quality.sh` helper — into a runtime ASDLC workspace. Update mode SHALL remove these staged files when they exist in an already-provisioned workspace. The shared `check_cross_class_peer_trigger.sh` helper and `list_committed_sibling_features.sh` lib SHALL remain staged, and the downstream un-migrated step assets (step 7 surface-map onward) SHALL remain staged, as those helpers and steps are not migrated by this change.

#### Scenario: Fresh setup omits the migrated bash assets

- **WHEN** `project_setup_first_init_machine.sh` creates a fresh ASDLC workspace
- **THEN** `.commands/feature_contract_delta.sh`, `.rules/feature_contract_delta_rule.md`, and `.helper/check_feature_contract_delta_quality.sh` are not present
- **AND** the shared `check_cross_class_peer_trigger.sh` helper and `list_committed_sibling_features.sh` lib, and the downstream un-migrated step commands, rules, and helpers, remain staged

#### Scenario: Update mode removes stale migrated bash assets

- **WHEN** `project_setup_first_init_machine.sh` runs in update mode for a workspace that still contains the migrated step 6 command, rule, or helper
- **THEN** those staged files are removed, and the `overmind-contract-delta` runner skill folders are present instead
- **AND** the shared cross-class/sibling helpers remain staged

### Requirement: Contract-Delta Template And Golden Example Are Skill-Local

`project_setup_first_init_machine.sh` SHALL deploy `feature_contract_delta_TEMPLATE.md` and `feature_contract_delta_GOLDEN_EXAMPLE.md` only under each installed `overmind-contract-delta/assets/` directory. It SHALL NOT stage duplicate flat copies under `.templates/` or `.golden_examples/`. Update mode SHALL remove those flat copies when they exist in an already-provisioned workspace through the support-directory exact-manifest cleanup.

#### Scenario: Fresh setup omits flat contract-delta assets

- **WHEN** `project_setup_first_init_machine.sh` creates a fresh ASDLC workspace
- **THEN** both runner skill folders contain the contract-delta template and golden example under `assets/`
- **AND** `.templates/feature_contract_delta_TEMPLATE.md` and `.golden_examples/feature_contract_delta_GOLDEN_EXAMPLE.md` are absent

#### Scenario: Update mode removes stale flat contract-delta assets

- **WHEN** update mode runs for a workspace containing the legacy flat contract-delta template or golden example
- **THEN** both flat files are removed while the skill-local assets remain installed
