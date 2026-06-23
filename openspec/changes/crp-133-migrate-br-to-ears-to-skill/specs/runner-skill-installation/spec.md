## ADDED Requirements

### Requirement: requirements-ears Skill Runner Installation

Overmind installation SHALL additionally install the packaged `overmind-requirements-ears` skill into each supported local runner skill directory (`.codex/skills/overmind-requirements-ears/` and `.claude/skills/overmind-requirements-ears/`) for a runtime ASDLC workspace, joining `overmind-task-to-br`, `overmind-repo-br-scan`, and `overmind-br-clarification`, while keeping `.overmind/overmind.js` as the single shared runtime CLI. The TypeScript `overmind init` installer SHALL return installation metadata covering the new skill path, and SHALL fail before writing runner targets when the packaged `overmind-requirements-ears` payload (`SKILL.md` + `assets/`) is incomplete.

#### Scenario: requirements-ears skill installed for Codex and Claude via init

- **WHEN** `overmind init` runs in a project
- **THEN** `<project>/.codex/skills/overmind-requirements-ears/SKILL.md` and `<project>/.claude/skills/overmind-requirements-ears/SKILL.md` exist
- **AND** each installed skill folder contains its packaged `assets/` directory
- **AND** `<project>/.overmind/overmind.js` remains the only installed CLI path with no runner-specific CLI copy

#### Scenario: ASDLC setup stages the requirements-ears skill

- **WHEN** `project_setup_first_init_machine.sh` creates or updates an ASDLC workspace after `npm run build`
- **THEN** the workspace contains `.codex/skills/overmind-requirements-ears/SKILL.md` and `.claude/skills/overmind-requirements-ears/SKILL.md` alongside the `overmind-task-to-br`, `overmind-repo-br-scan`, and `overmind-br-clarification` skill folders
- **AND** `.overmind/overmind.js` staging behavior is unchanged
- **AND** update mode repairs a missing or stale `overmind-requirements-ears` runner skill folder from canonical source

#### Scenario: Incomplete payload fails before writing runner targets

- **WHEN** the packaged `overmind-requirements-ears` skill is missing `SKILL.md` or `assets/`
- **THEN** installation fails before writing any runner skill target

### Requirement: Migrated BR-to-EARS Bash Assets Are Not Staged

`project_setup_first_init_machine.sh` SHALL NOT stage the migrated step 5 bash assets — the `feature_br_to_ears.sh` command, the `br_to_ears.md` rule, and the `check_requirements_ears_quality.sh` helper — into a runtime ASDLC workspace. Update mode SHALL remove these staged files when they exist in an already-provisioned workspace. The step 5.1 EARS-review assets (`feature_requirements_ears_review.sh`, its rule, and `check_requirements_ears_review_quality.sh`) SHALL remain staged, as that step is not migrated by this change.

#### Scenario: Fresh setup omits the migrated bash assets

- **WHEN** `project_setup_first_init_machine.sh` creates a fresh ASDLC workspace
- **THEN** `.commands/feature_br_to_ears.sh`, `.rules/br_to_ears.md`, and `.helper/check_requirements_ears_quality.sh` are not present
- **AND** the step 5.1 EARS-review command, rule, and helper remain staged

#### Scenario: Update mode removes stale migrated bash assets

- **WHEN** `project_setup_first_init_machine.sh` runs in update mode for a workspace that still contains the migrated step 5 command, rule, or helper
- **THEN** those staged files are removed, and the `overmind-requirements-ears` runner skill folders are present instead
