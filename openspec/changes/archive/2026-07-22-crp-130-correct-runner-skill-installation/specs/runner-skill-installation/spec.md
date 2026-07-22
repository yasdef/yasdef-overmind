## ADDED Requirements

### Requirement: Runner Skill Installation Targets

Overmind installation SHALL install the packaged `overmind-task-to-br` skill into each supported local runner skill directory for a runtime ASDLC workspace. The supported runner targets for this change SHALL be `.codex/skills/overmind-task-to-br/` and `.claude/skills/overmind-task-to-br/`.

#### Scenario: Packaged skill is installed for Codex and Claude

- **WHEN** Overmind installs or stages a runtime ASDLC workspace
- **THEN** `.codex/skills/overmind-task-to-br/SKILL.md` exists
- **AND** `.claude/skills/overmind-task-to-br/SKILL.md` exists
- **AND** each installed skill folder contains the packaged `assets/` directory

### Requirement: Shared Runtime CLI Is Preserved

Overmind installation SHALL keep `.overmind/overmind.js` as the single shared runtime CLI bundle used by installed skills. The skill installation SHALL NOT copy the CLI into runner-specific skill directories and SHALL NOT change the CLI command paths emitted by task-to-BR context.

#### Scenario: Skills use the shared CLI

- **WHEN** the `overmind-task-to-br` skill is installed into runner skill directories
- **THEN** `.overmind/overmind.js` remains present and executable
- **AND** runner skill directories do not contain a runner-specific `overmind.js` copy
- **AND** task-to-BR instructions continue to call `node .overmind/overmind.js capture|context|gate ...`

### Requirement: ASDLC Setup Stages Skills

`project_setup_first_init_machine.sh` SHALL stage the packaged `overmind-task-to-br` skill into supported runner skill directories during both fresh ASDLC setup and update mode. If the canonical packaged skill source is missing, setup SHALL fail with a clear error before producing an incomplete runtime skill installation.

#### Scenario: Fresh setup provisions runner skills

- **WHEN** `project_setup_first_init_machine.sh` creates a fresh ASDLC workspace after `npm run build`
- **THEN** the workspace contains `.overmind/overmind.js`
- **AND** the workspace contains `.codex/skills/overmind-task-to-br/SKILL.md`
- **AND** the workspace contains `.claude/skills/overmind-task-to-br/SKILL.md`

#### Scenario: Update mode repairs missing runner skills

- **WHEN** `project_setup_first_init_machine.sh` runs in update mode for an existing ASDLC workspace missing one supported runner skill folder
- **THEN** the missing runner skill folder is recreated from the canonical packaged skill source
- **AND** existing `.overmind/overmind.js` staging behavior is preserved

#### Scenario: Missing canonical skill source fails setup

- **WHEN** the packaged source at `packages/installer/_data/skills/overmind-task-to-br/` is absent
- **THEN** setup fails with an error naming the missing skill source
- **AND** setup does not silently create only `.overmind/overmind.js` without the required runner skill installation

### Requirement: TypeScript Installer Installs Supported Runner Skills

The TypeScript `overmind init` installer SHALL install the packaged `overmind-task-to-br` skill into all supported local runner skill directories and SHALL return enough installation metadata for tests and callers to inspect those installed paths.

#### Scenario: TypeScript init provisions both runner skills

- **WHEN** `overmind init` runs in a project
- **THEN** `<project>/.codex/skills/overmind-task-to-br/SKILL.md` exists
- **AND** `<project>/.claude/skills/overmind-task-to-br/SKILL.md` exists
- **AND** `<project>/.overmind/overmind.js` remains the installed CLI path
