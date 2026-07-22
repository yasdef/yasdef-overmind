## ADDED Requirements

### Requirement: Multi-Skill Runner Installation

Overmind installation SHALL install every packaged Overmind skill — at this stage `overmind-task-to-br` and `overmind-repo-br-scan` — into each supported local runner skill directory (`.codex/skills/<skill>/` and `.claude/skills/<skill>/`) for a runtime ASDLC workspace, while keeping `.overmind/overmind.js` as the single shared runtime CLI. The TypeScript `overmind init` installer SHALL return installation metadata covering every installed skill path.

#### Scenario: Both skills installed for Codex and Claude via init

- **WHEN** `overmind init` runs in a project
- **THEN** `<project>/.codex/skills/overmind-task-to-br/SKILL.md` and `<project>/.codex/skills/overmind-repo-br-scan/SKILL.md` exist
- **AND** `<project>/.claude/skills/overmind-task-to-br/SKILL.md` and `<project>/.claude/skills/overmind-repo-br-scan/SKILL.md` exist
- **AND** each installed skill folder contains its packaged `assets/` directory
- **AND** `<project>/.overmind/overmind.js` remains the only installed CLI path with no runner-specific CLI copy

#### Scenario: ASDLC setup stages both skills

- **WHEN** `project_setup_first_init_machine.sh` creates or updates an ASDLC workspace after `npm run build`
- **THEN** the workspace contains `.codex/skills/overmind-repo-br-scan/SKILL.md` and `.claude/skills/overmind-repo-br-scan/SKILL.md` alongside the `overmind-task-to-br` skill folders
- **AND** `.overmind/overmind.js` staging behavior is unchanged
- **AND** update mode repairs a missing or stale `overmind-repo-br-scan` runner skill folder from canonical source

### Requirement: Migrated Repo-Scan Bash Assets Are Not Staged

`project_setup_first_init_machine.sh` SHALL NOT stage the migrated repo-scan bash assets — the `feature_scan_repo_for_br.sh` command, the `repo_br_scan_rule.md` rule, and the `check_business_context_filled_from_repo.sh` helper — into a runtime ASDLC workspace. Update mode SHALL remove these staged files when they exist in an already-provisioned workspace.

#### Scenario: Fresh setup omits the migrated bash assets

- **WHEN** `project_setup_first_init_machine.sh` creates a fresh ASDLC workspace
- **THEN** `.commands/feature_scan_repo_for_br.sh`, `.rules/repo_br_scan_rule.md`, and `.helper/check_business_context_filled_from_repo.sh` are not present

#### Scenario: Update mode removes stale migrated bash assets

- **WHEN** `project_setup_first_init_machine.sh` runs in update mode for a workspace that still contains the migrated repo-scan command, rule, or helper
- **THEN** those staged files are removed, and the `overmind-repo-br-scan` runner skill folders are present instead
