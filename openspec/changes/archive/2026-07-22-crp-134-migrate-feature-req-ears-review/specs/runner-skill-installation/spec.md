## ADDED Requirements

### Requirement: ears-review Skill Runner Installation

Overmind installation SHALL additionally install the packaged `overmind-ears-review` skill into each supported local runner skill directory (`.codex/skills/overmind-ears-review/` and `.claude/skills/overmind-ears-review/`) for a runtime ASDLC workspace, joining `overmind-task-to-br`, `overmind-repo-br-scan`, `overmind-br-clarification`, and `overmind-requirements-ears`, while keeping `.overmind/overmind.js` as the single shared runtime CLI. The TypeScript `overmind init` installer SHALL return installation metadata covering the new skill path, and SHALL fail before writing runner targets when the packaged `overmind-ears-review` payload (`SKILL.md` + `assets/`) is incomplete.

#### Scenario: ears-review skill installed for Codex and Claude via init

- **WHEN** `overmind init` runs in a project
- **THEN** `<project>/.codex/skills/overmind-ears-review/SKILL.md` and `<project>/.claude/skills/overmind-ears-review/SKILL.md` exist
- **AND** each installed skill folder contains its packaged `assets/` directory
- **AND** `<project>/.overmind/overmind.js` remains the only installed CLI path with no runner-specific CLI copy

#### Scenario: ASDLC setup stages the ears-review skill

- **WHEN** `project_setup_first_init_machine.sh` creates or updates an ASDLC workspace after `npm run build`
- **THEN** the workspace contains `.codex/skills/overmind-ears-review/SKILL.md` and `.claude/skills/overmind-ears-review/SKILL.md` alongside the `overmind-task-to-br`, `overmind-repo-br-scan`, `overmind-br-clarification`, and `overmind-requirements-ears` skill folders
- **AND** `.overmind/overmind.js` staging behavior is unchanged
- **AND** update mode repairs a missing or stale `overmind-ears-review` runner skill folder from canonical source

#### Scenario: Incomplete payload fails before writing runner targets

- **WHEN** the packaged `overmind-ears-review` skill is missing `SKILL.md` or `assets/`
- **THEN** installation fails before writing any runner skill target

### Requirement: Migrated EARS-Review Bash Assets Are Not Staged

`project_setup_first_init_machine.sh` SHALL NOT stage the migrated step 5.1 bash assets — the `feature_requirements_ears_review.sh` command, the `requirements_ears_review_rule.md` rule, and the `check_requirements_ears_review_quality.sh` helper — into a runtime ASDLC workspace. Update mode SHALL remove these staged files when they exist in an already-provisioned workspace. The downstream un-migrated step assets (step 6 contract-delta onward) SHALL remain staged, as those steps are not migrated by this change.

#### Scenario: Fresh setup omits the migrated bash assets

- **WHEN** `project_setup_first_init_machine.sh` creates a fresh ASDLC workspace
- **THEN** `.commands/feature_requirements_ears_review.sh`, `.rules/requirements_ears_review_rule.md`, and `.helper/check_requirements_ears_review_quality.sh` are not present
- **AND** the downstream un-migrated step commands, rules, and helpers remain staged

#### Scenario: Update mode removes stale migrated bash assets

- **WHEN** `project_setup_first_init_machine.sh` runs in update mode for a workspace that still contains the migrated step 5.1 command, rule, or helper
- **THEN** those staged files are removed, and the `overmind-ears-review` runner skill folders are present instead
