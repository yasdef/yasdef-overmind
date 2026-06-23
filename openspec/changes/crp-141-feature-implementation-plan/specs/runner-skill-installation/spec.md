## MODIFIED Requirements

### Requirement: surface-map Skill Runner Installation

Overmind installation SHALL additionally install the packaged `overmind-implementation-plan` skill into each supported local runner skill directory (`.codex/skills/overmind-implementation-plan/` and `.claude/skills/overmind-implementation-plan/`) for a runtime ASDLC workspace, joining `overmind-task-to-br`, `overmind-repo-br-scan`, `overmind-br-clarification`, `overmind-requirements-ears`, `overmind-ears-review`, `overmind-contract-delta`, `overmind-surface-map`, `overmind-surface-map-enrich`, `overmind-technical-requirements`, `overmind-implementation-slices`, and `overmind-prerequisite-gaps`, while keeping `.overmind/overmind.js` as the single shared runtime CLI. Each installed `overmind-implementation-plan` skill folder SHALL contain `SKILL.md` and an `assets/` directory holding the implementation-plan template and golden example. The TypeScript `overmind init` installer SHALL return installation metadata covering the new skill path, and SHALL fail before writing runner targets when the packaged `overmind-implementation-plan` payload (`SKILL.md` + `assets/`) is incomplete.

#### Scenario: implementation-plan skill installed for Codex and Claude via init
- **WHEN** `overmind init` runs in a project
- **THEN** `<project>/.codex/skills/overmind-implementation-plan/SKILL.md` and `<project>/.claude/skills/overmind-implementation-plan/SKILL.md` exist
- **AND** each installed skill folder contains its packaged `assets/` directory with the template and golden example
- **AND** `<project>/.overmind/overmind.js` remains the only installed CLI path with no runner-specific CLI copy

#### Scenario: ASDLC setup stages the implementation-plan skill
- **WHEN** `project_setup_first_init_machine.sh` creates or updates an ASDLC workspace after `npm run build`
- **THEN** the workspace contains `.codex/skills/overmind-implementation-plan/SKILL.md` and `.claude/skills/overmind-implementation-plan/SKILL.md` alongside the eleven previously migrated skill folders
- **AND** `.overmind/overmind.js` staging behavior is unchanged
- **AND** update mode repairs a missing or stale `overmind-implementation-plan` runner skill folder from canonical source

#### Scenario: Incomplete payload fails before writing runner targets
- **WHEN** the packaged `overmind-implementation-plan` skill is missing `SKILL.md` or `assets/`
- **THEN** installation fails before writing any runner skill target

### Requirement: Migrated Implementation-Plan Bash Assets Are Not Staged

`project_setup_first_init_machine.sh` SHALL NOT stage the migrated step 8.3 bash assets — `feature_implementation_plan.sh` command, `implementation_plan_rule.md` rule, and `check_implementation_plan_quality.sh` helper — into a runtime ASDLC workspace. Update mode SHALL remove these staged files when they exist in an already-provisioned workspace. The shared `class_repo_paths.sh`, `sync_repo_to_default_branch.sh`, `list_committed_sibling_features.sh`, `check_cross_class_peer_trigger.sh`, the surface quality helpers, and all downstream un-migrated step assets (step 8.4 semantic review, worker assignment/readiness) SHALL remain staged, as those are not migrated by this change.

#### Scenario: Fresh setup omits the migrated step-8.3 bash assets
- **WHEN** `project_setup_first_init_machine.sh` creates a fresh ASDLC workspace
- **THEN** `.commands/feature_implementation_plan.sh`, `.rules/implementation_plan_rule.md`, and `.helper/check_implementation_plan_quality.sh` are not present
- **AND** the shared repo/cross-class/sibling libs, the surface quality helpers, and the downstream un-migrated step commands, rules, and helpers remain staged

#### Scenario: Update mode removes stale migrated step-8.3 assets
- **WHEN** `project_setup_first_init_machine.sh` runs in update mode for a workspace that still contains the migrated step-8.3 command, rule, or helper
- **THEN** those staged files are removed, and the `overmind-implementation-plan` runner skill folders are present instead
- **AND** the shared libs and downstream un-migrated step assets remain staged

### Requirement: Step 8.4 semantic review references the plan gate via the shared CLI

Because `check_implementation_plan_quality.sh` is deleted and unstaged by this change, the still-bash step 8.4 orchestrator (`feature_implementation_plan_semantic_review.sh`) — its only remaining consumer — SHALL NOT depend on that helper. Step 8.4 SHALL drop `.helper/check_implementation_plan_quality.sh` from its required-file check, and SHALL present the implementation-plan quality gate to its model as `node .overmind/overmind.js gate implementation-plan <feature-path>` (a model-invoked command, not orchestrator-run). Because the plan gate the model is now told to run depends on the shared CLI, step 8.4 SHALL preflight `.overmind/overmind.js` in `ensure_required_files` (replacing the removed helper entry) so a missing CLI fails before launching the model rather than handing the model an unusable gate command. Step 8.4's own semantic-review gate, rule, template, golden example, and skill migration remain out of scope for this change.

#### Scenario: Step 8.4 does not require the deleted helper
- **WHEN** step 8.4 runs in a workspace provisioned after this change (with `check_implementation_plan_quality.sh` absent)
- **THEN** step 8.4 does not fail its required-file check for the missing helper

#### Scenario: Step 8.4 exposes the CLI plan gate to its model
- **WHEN** step 8.4 builds its model prompt
- **THEN** the implementation-plan quality gate command it presents is `node .overmind/overmind.js gate implementation-plan <feature-path>` and it does not reference `.helper/check_implementation_plan_quality.sh`

#### Scenario: Step 8.4 preflights the shared CLI
- **WHEN** step 8.4 runs in a workspace where `.overmind/overmind.js` is absent
- **THEN** its required-file check fails with an actionable error naming the missing CLI before any model session is launched

### Requirement: Implementation-Plan Template And Golden Example Are Skill-Local

`project_setup_first_init_machine.sh` SHALL deploy `implementation_plan_TEMPLATE.md` and `implementation_plan_GOLDEN_EXAMPLE.md` only under each installed `overmind-implementation-plan/assets/` directory. It SHALL NOT stage flat copies under `.templates/` or `.golden_examples/`. Update mode SHALL remove those flat copies when they exist in an already-provisioned workspace.

#### Scenario: Fresh setup omits flat implementation-plan assets
- **WHEN** `project_setup_first_init_machine.sh` creates a fresh ASDLC workspace
- **THEN** both runner skill folders contain the template and golden example under `assets/`
- **AND** `.templates/implementation_plan_TEMPLATE.md` and `.golden_examples/implementation_plan_GOLDEN_EXAMPLE.md` are absent

#### Scenario: Update mode removes stale flat implementation-plan assets
- **WHEN** update mode runs for a workspace containing the legacy flat template or golden example
- **THEN** those flat files are removed while the skill-local assets remain installed

### Requirement: E2e runner invokes skill for phase 8.3 with read-only guards and output assertion

`project_add_feature_e2e.sh` phase 8.3 SHALL launch the `overmind-implementation-plan` skill via Codex using `run_implementation_plan_skill`, snapshot `init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, `implementation_slices.md`, and `prerequisite_gaps.md` before the session, then `cmp`-assert each snapshotted input byte-unchanged after the session on every exit path, and assert `implementation_plan.md` was produced. Phase 8.3 SHALL NOT run any repo sync (step 8.3 has no pre-session sync). The shell e2e SHALL NOT run the quality gate itself.

#### Scenario: Phase 8.3 starts the skill
- **WHEN** the e2e runner reaches phase 8.3
- **THEN** a Codex session is started with a prompt that names the `overmind-implementation-plan` skill and includes the exact `context implementation-plan` and `gate implementation-plan` commands

#### Scenario: Read-only input mutation fails the phase
- **WHEN** the model modifies `technical_requirements.md` during the phase-8.3 session
- **THEN** the `cmp` post-session check detects drift and the phase fails with an actionable error

#### Scenario: Prerequisite-gaps input mutation fails the phase
- **WHEN** the model modifies `prerequisite_gaps.md` during the phase-8.3 session
- **THEN** the `cmp` post-session check detects drift and the phase fails with an actionable error

#### Scenario: No sync runs for phase 8.3
- **WHEN** the e2e runner reaches phase 8.3
- **THEN** no `overmind sync` command is invoked for the phase-8.3 session

#### Scenario: Output file not produced
- **WHEN** the Codex session exits but `implementation_plan.md` is not present in the feature directory
- **THEN** the e2e runner fails the phase with an error naming the missing file
