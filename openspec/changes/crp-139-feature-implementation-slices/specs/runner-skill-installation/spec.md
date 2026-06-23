## MODIFIED Requirements

### Requirement: surface-map Skill Runner Installation

Overmind installation SHALL additionally install the packaged `overmind-implementation-slices` skill into each supported local runner skill directory (`.codex/skills/overmind-implementation-slices/` and `.claude/skills/overmind-implementation-slices/`) for a runtime ASDLC workspace, joining `overmind-task-to-br`, `overmind-repo-br-scan`, `overmind-br-clarification`, `overmind-requirements-ears`, `overmind-ears-review`, `overmind-contract-delta`, `overmind-surface-map`, `overmind-surface-map-enrich`, and `overmind-technical-requirements`, while keeping `.overmind/overmind.js` as the single shared runtime CLI. Each installed `overmind-implementation-slices` skill folder SHALL contain `SKILL.md` and an `assets/` directory holding the implementation-slices template and golden example. The TypeScript `overmind init` installer SHALL return installation metadata covering the new skill path, and SHALL fail before writing runner targets when the packaged `overmind-implementation-slices` payload (`SKILL.md` + `assets/`) is incomplete.

#### Scenario: implementation-slices skill installed for Codex and Claude via init
- **WHEN** `overmind init` runs in a project
- **THEN** `<project>/.codex/skills/overmind-implementation-slices/SKILL.md` and `<project>/.claude/skills/overmind-implementation-slices/SKILL.md` exist
- **AND** each installed skill folder contains its packaged `assets/` directory with the template and golden example
- **AND** `<project>/.overmind/overmind.js` remains the only installed CLI path with no runner-specific CLI copy

#### Scenario: ASDLC setup stages the implementation-slices skill
- **WHEN** `project_setup_first_init_machine.sh` creates or updates an ASDLC workspace after `npm run build`
- **THEN** the workspace contains `.codex/skills/overmind-implementation-slices/SKILL.md` and `.claude/skills/overmind-implementation-slices/SKILL.md` alongside the nine previously migrated skill folders
- **AND** `.overmind/overmind.js` staging behavior is unchanged
- **AND** update mode repairs a missing or stale `overmind-implementation-slices` runner skill folder from canonical source

#### Scenario: Incomplete payload fails before writing runner targets
- **WHEN** the packaged `overmind-implementation-slices` skill is missing `SKILL.md` or `assets/`
- **THEN** installation fails before writing any runner skill target

### Requirement: Migrated Implementation-Slices Bash Assets Are Not Staged

`project_setup_first_init_machine.sh` SHALL NOT stage the migrated step 8.1 bash assets — `feature_implementation_slices.sh` command, `implementation_slices_rule.md` rule, and `check_implementation_slices_quality.sh` helper — into a runtime ASDLC workspace. Update mode SHALL remove these staged files when they exist in an already-provisioned workspace. The shared `class_repo_paths.sh`, `sync_repo_to_default_branch.sh`, `list_committed_sibling_features.sh`, `check_cross_class_peer_trigger.sh`, the surface quality helpers, and all downstream un-migrated step assets (steps 8.2–8.4) SHALL remain staged, as those are not migrated by this change.

#### Scenario: Fresh setup omits the migrated step-8.1 bash assets
- **WHEN** `project_setup_first_init_machine.sh` creates a fresh ASDLC workspace
- **THEN** `.commands/feature_implementation_slices.sh`, `.rules/implementation_slices_rule.md`, and `.helper/check_implementation_slices_quality.sh` are not present
- **AND** the shared repo/cross-class/sibling libs, the surface quality helpers, and the downstream un-migrated step commands, rules, and helpers remain staged

#### Scenario: Update mode removes stale migrated step-8.1 assets
- **WHEN** `project_setup_first_init_machine.sh` runs in update mode for a workspace that still contains the migrated step-8.1 command, rule, or helper
- **THEN** those staged files are removed, and the `overmind-implementation-slices` runner skill folders are present instead
- **AND** the shared libs and downstream un-migrated step assets remain staged

### Requirement: Implementation-Slices Template And Golden Example Are Skill-Local

`project_setup_first_init_machine.sh` SHALL deploy `implementation_slices_TEMPLATE.md` and `implementation_slices_GOLDEN_EXAMPLE.md` only under each installed `overmind-implementation-slices/assets/` directory. It SHALL NOT stage flat copies under `.templates/` or `.golden_examples/`. Update mode SHALL remove those flat copies when they exist in an already-provisioned workspace.

#### Scenario: Fresh setup omits flat implementation-slices assets
- **WHEN** `project_setup_first_init_machine.sh` creates a fresh ASDLC workspace
- **THEN** both runner skill folders contain the template and golden example under `assets/`
- **AND** `.templates/implementation_slices_TEMPLATE.md` and `.golden_examples/implementation_slices_GOLDEN_EXAMPLE.md` are absent

#### Scenario: Update mode removes stale flat implementation-slices assets
- **WHEN** update mode runs for a workspace containing the legacy flat template or golden example
- **THEN** those flat files are removed while the skill-local assets remain installed

### Requirement: E2e runner invokes skill for phase 8.1 with read-only guards and output assertion

`project_add_feature_e2e.sh` phase 8.1 SHALL launch the `overmind-implementation-slices` skill via Codex using `run_implementation_slices_skill`, snapshot `init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, all applicable surface map files, and — when it exists before the session — `prerequisite_gaps.md`, then `cmp`-assert each snapshotted input byte-unchanged after the session on every exit path, and assert `implementation_slices.md` was produced. Because the gate consumes `prerequisite_gaps.md` for its required-surface cross-check, guarding it when present prevents the model from mutating it to bypass validation; its absence SHALL NOT cause a guard failure. The shell e2e SHALL NOT run the quality gate itself.

#### Scenario: Phase 8.1 starts the skill
- **WHEN** the e2e runner reaches phase 8.1
- **THEN** a Codex session is started with a prompt that names the `overmind-implementation-slices` skill and includes the exact `context implementation-slices` and `gate implementation-slices` commands

#### Scenario: Read-only input mutation fails the phase
- **WHEN** the model modifies `technical_requirements.md` during the phase-8.1 session
- **THEN** the `cmp` post-session check detects drift and the phase fails with an actionable error

#### Scenario: prerequisite_gaps.md mutation fails the phase when present
- **WHEN** `prerequisite_gaps.md` exists before the session and the model modifies it during the phase-8.1 session
- **THEN** the `cmp` post-session check detects drift and the phase fails with an actionable error

#### Scenario: prerequisite_gaps.md absent is not guarded
- **WHEN** `prerequisite_gaps.md` does not exist before the phase-8.1 session
- **THEN** no `prerequisite_gaps.md` snapshot or guard is applied and its absence does not fail the phase

#### Scenario: Output file not produced
- **WHEN** the Codex session exits but `implementation_slices.md` is not present in the feature directory
- **THEN** the e2e runner fails the phase with an error naming the missing file
