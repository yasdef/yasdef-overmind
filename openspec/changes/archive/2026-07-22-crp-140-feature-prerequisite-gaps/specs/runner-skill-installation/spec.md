## MODIFIED Requirements

### Requirement: surface-map Skill Runner Installation

Overmind installation SHALL additionally install the packaged `overmind-prerequisite-gaps` skill into each supported local runner skill directory (`.codex/skills/overmind-prerequisite-gaps/` and `.claude/skills/overmind-prerequisite-gaps/`) for a runtime ASDLC workspace, joining `overmind-task-to-br`, `overmind-repo-br-scan`, `overmind-br-clarification`, `overmind-requirements-ears`, `overmind-ears-review`, `overmind-contract-delta`, `overmind-surface-map`, `overmind-surface-map-enrich`, `overmind-technical-requirements`, and `overmind-implementation-slices`, while keeping `.overmind/overmind.js` as the single shared runtime CLI. Each installed `overmind-prerequisite-gaps` skill folder SHALL contain `SKILL.md` and an `assets/` directory holding the prerequisite-gaps template and golden example. The TypeScript `overmind init` installer SHALL return installation metadata covering the new skill path, and SHALL fail before writing runner targets when the packaged `overmind-prerequisite-gaps` payload (`SKILL.md` + `assets/`) is incomplete.

#### Scenario: prerequisite-gaps skill installed for Codex and Claude via init
- **WHEN** `overmind init` runs in a project
- **THEN** `<project>/.codex/skills/overmind-prerequisite-gaps/SKILL.md` and `<project>/.claude/skills/overmind-prerequisite-gaps/SKILL.md` exist
- **AND** each installed skill folder contains its packaged `assets/` directory with the template and golden example
- **AND** `<project>/.overmind/overmind.js` remains the only installed CLI path with no runner-specific CLI copy

#### Scenario: ASDLC setup stages the prerequisite-gaps skill
- **WHEN** `project_setup_first_init_machine.sh` creates or updates an ASDLC workspace after `npm run build`
- **THEN** the workspace contains `.codex/skills/overmind-prerequisite-gaps/SKILL.md` and `.claude/skills/overmind-prerequisite-gaps/SKILL.md` alongside the ten previously migrated skill folders
- **AND** `.overmind/overmind.js` staging behavior is unchanged
- **AND** update mode repairs a missing or stale `overmind-prerequisite-gaps` runner skill folder from canonical source

#### Scenario: Incomplete payload fails before writing runner targets
- **WHEN** the packaged `overmind-prerequisite-gaps` skill is missing `SKILL.md` or `assets/`
- **THEN** installation fails before writing any runner skill target

### Requirement: Migrated Prerequisite-Gaps Bash Assets Are Not Staged

`project_setup_first_init_machine.sh` SHALL NOT stage the migrated step 8.2 bash assets — `feature_prerequisite_gaps.sh` command, `prerequisite_gaps_rule.md` rule, and `check_prerequisite_gaps_quality.sh` helper — into a runtime ASDLC workspace. Update mode SHALL remove these staged files when they exist in an already-provisioned workspace. The shared `class_repo_paths.sh`, `sync_repo_to_default_branch.sh`, `list_committed_sibling_features.sh`, `check_cross_class_peer_trigger.sh`, the surface quality helpers, and all downstream un-migrated step assets (steps 8.3–8.4) SHALL remain staged, as those are not migrated by this change.

#### Scenario: Fresh setup omits the migrated step-8.2 bash assets
- **WHEN** `project_setup_first_init_machine.sh` creates a fresh ASDLC workspace
- **THEN** `.commands/feature_prerequisite_gaps.sh`, `.rules/prerequisite_gaps_rule.md`, and `.helper/check_prerequisite_gaps_quality.sh` are not present
- **AND** the shared repo/cross-class/sibling libs, the surface quality helpers, and the downstream un-migrated step commands, rules, and helpers remain staged

#### Scenario: Update mode removes stale migrated step-8.2 assets
- **WHEN** `project_setup_first_init_machine.sh` runs in update mode for a workspace that still contains the migrated step-8.2 command, rule, or helper
- **THEN** those staged files are removed, and the `overmind-prerequisite-gaps` runner skill folders are present instead
- **AND** the shared libs and downstream un-migrated step assets remain staged

### Requirement: Prerequisite-Gaps Template And Golden Example Are Skill-Local

`project_setup_first_init_machine.sh` SHALL deploy `prerequisite_gaps_TEMPLATE.md` and `prerequisite_gaps_GOLDEN_EXAMPLE.md` only under each installed `overmind-prerequisite-gaps/assets/` directory. It SHALL NOT stage flat copies under `.templates/` or `.golden_examples/`. Update mode SHALL remove those flat copies when they exist in an already-provisioned workspace.

#### Scenario: Fresh setup omits flat prerequisite-gaps assets
- **WHEN** `project_setup_first_init_machine.sh` creates a fresh ASDLC workspace
- **THEN** both runner skill folders contain the template and golden example under `assets/`
- **AND** `.templates/prerequisite_gaps_TEMPLATE.md` and `.golden_examples/prerequisite_gaps_GOLDEN_EXAMPLE.md` are absent

#### Scenario: Update mode removes stale flat prerequisite-gaps assets
- **WHEN** update mode runs for a workspace containing the legacy flat template or golden example
- **THEN** those flat files are removed while the skill-local assets remain installed

### Requirement: E2e runner invokes skill for phase 8.2 with sync, read-only guards and output assertion

`project_add_feature_e2e.sh` phase 8.2 SHALL run `overmind sync prerequisite-gaps` before the session, then launch the `overmind-prerequisite-gaps` skill via Codex using `run_prerequisite_gaps_skill`, snapshot `init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `implementation_slices.md`, and each sibling `implementation_plan.md` present before the session, then `cmp`-assert each snapshotted input byte-unchanged after the session on every exit path, and assert `prerequisite_gaps.md` was produced. The shell e2e SHALL NOT run the quality gate itself.

#### Scenario: Phase 8.2 starts the skill
- **WHEN** the e2e runner reaches phase 8.2
- **THEN** a Codex session is started with a prompt that names the `overmind-prerequisite-gaps` skill and includes the exact `context prerequisite-gaps` and `gate prerequisite-gaps` commands

#### Scenario: Read-only input mutation fails the phase
- **WHEN** the model modifies `implementation_slices.md` during the phase-8.2 session
- **THEN** the `cmp` post-session check detects drift and the phase fails with an actionable error

#### Scenario: Sibling in-flight plan mutation fails the phase when present
- **WHEN** a sibling `implementation_plan.md` exists before the session and the model modifies it during the phase-8.2 session
- **THEN** the `cmp` post-session check detects drift and the phase fails with an actionable error

#### Scenario: Sync runs before the session
- **WHEN** the e2e runner reaches phase 8.2
- **THEN** `overmind sync prerequisite-gaps` is invoked before the Codex session is started

#### Scenario: Output file not produced
- **WHEN** the Codex session exits but `prerequisite_gaps.md` is not present in the feature directory
- **THEN** the e2e runner fails the phase with an error naming the missing file
