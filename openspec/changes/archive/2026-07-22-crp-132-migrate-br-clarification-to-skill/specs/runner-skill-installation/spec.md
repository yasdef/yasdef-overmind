## ADDED Requirements

### Requirement: br-clarification Skill Runner Installation

Overmind installation SHALL additionally install the packaged `overmind-br-clarification` skill into each supported local runner skill directory (`.codex/skills/overmind-br-clarification/` and `.claude/skills/overmind-br-clarification/`) for a runtime ASDLC workspace, joining `overmind-task-to-br` and `overmind-repo-br-scan`, while keeping `.overmind/overmind.js` as the single shared runtime CLI. The TypeScript `overmind init` installer SHALL return installation metadata covering the new skill path, and SHALL fail before writing runner targets when the packaged `overmind-br-clarification` payload (`SKILL.md` + `assets/`) is incomplete.

#### Scenario: br-clarification skill installed for Codex and Claude via init

- **WHEN** `overmind init` runs in a project
- **THEN** `<project>/.codex/skills/overmind-br-clarification/SKILL.md` and `<project>/.claude/skills/overmind-br-clarification/SKILL.md` exist
- **AND** each installed skill folder contains its packaged `assets/` directory
- **AND** `<project>/.overmind/overmind.js` remains the only installed CLI path with no runner-specific CLI copy

#### Scenario: ASDLC setup stages the br-clarification skill

- **WHEN** `project_setup_first_init_machine.sh` creates or updates an ASDLC workspace after `npm run build`
- **THEN** the workspace contains `.codex/skills/overmind-br-clarification/SKILL.md` and `.claude/skills/overmind-br-clarification/SKILL.md` alongside the `overmind-task-to-br` and `overmind-repo-br-scan` skill folders
- **AND** `.overmind/overmind.js` staging behavior is unchanged
- **AND** update mode repairs a missing or stale `overmind-br-clarification` runner skill folder from canonical source

#### Scenario: Incomplete payload fails before writing runner targets

- **WHEN** the packaged `overmind-br-clarification` skill is missing `SKILL.md` or `assets/`
- **THEN** installation fails before writing any runner skill target

### Requirement: Migrated BR-Clarification Bash Assets Are Not Staged

`project_setup_first_init_machine.sh` SHALL NOT stage the migrated step 4.2 bash assets — the `feature_user_br_clarification.sh` command, the `feature_br_check_ears_readiness.sh` command, the `user_br_clarification_rule.md` rule, and the `check_user_br_clarification_quality.sh` helper — into a runtime ASDLC workspace. Update mode SHALL remove these staged files when they exist in an already-provisioned workspace.

#### Scenario: Fresh setup omits the migrated bash assets

- **WHEN** `project_setup_first_init_machine.sh` creates a fresh ASDLC workspace
- **THEN** `.commands/feature_user_br_clarification.sh`, `.commands/feature_br_check_ears_readiness.sh`, `.rules/user_br_clarification_rule.md`, and `.helper/check_user_br_clarification_quality.sh` are not present

#### Scenario: Update mode removes stale migrated bash assets

- **WHEN** `project_setup_first_init_machine.sh` runs in update mode for a workspace that still contains any migrated step 4.2 command, rule, or helper
- **THEN** those staged files are removed, and the `overmind-br-clarification` runner skill folders are present instead
