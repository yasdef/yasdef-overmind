## MODIFIED Requirements

### Requirement: surface-map Skill Runner Installation

Overmind installation SHALL additionally install the packaged `overmind-plan-semantic-review` skill into each supported local runner skill directory (`.codex/skills/overmind-plan-semantic-review/` and `.claude/skills/overmind-plan-semantic-review/`) for a runtime ASDLC workspace, joining `overmind-task-to-br`, `overmind-repo-br-scan`, `overmind-br-clarification`, `overmind-requirements-ears`, `overmind-ears-review`, `overmind-contract-delta`, `overmind-surface-map`, `overmind-surface-map-enrich`, `overmind-technical-requirements`, `overmind-implementation-slices`, `overmind-prerequisite-gaps`, and `overmind-implementation-plan`, while keeping `.overmind/overmind.js` as the single shared runtime CLI. Each installed `overmind-plan-semantic-review` skill folder SHALL contain `SKILL.md` and an `assets/` directory holding the semantic-review template and golden example. The TypeScript `overmind init` installer SHALL return installation metadata covering the new skill path, and SHALL fail before writing runner targets when the packaged `overmind-plan-semantic-review` payload (`SKILL.md` + `assets/`) is incomplete.

#### Scenario: plan-semantic-review skill installed for Codex and Claude via init
- **WHEN** `overmind init` runs in a project
- **THEN** `<project>/.codex/skills/overmind-plan-semantic-review/SKILL.md` and `<project>/.claude/skills/overmind-plan-semantic-review/SKILL.md` exist
- **AND** each installed skill folder contains its packaged `assets/` directory with the template and golden example
- **AND** `<project>/.overmind/overmind.js` remains the only installed CLI path with no runner-specific CLI copy

#### Scenario: ASDLC setup stages the plan-semantic-review skill
- **WHEN** `project_setup_first_init_machine.sh` creates or updates an ASDLC workspace after `npm run build`
- **THEN** the workspace contains `.codex/skills/overmind-plan-semantic-review/SKILL.md` and `.claude/skills/overmind-plan-semantic-review/SKILL.md` alongside the twelve previously migrated skill folders
- **AND** `.overmind/overmind.js` staging behavior is unchanged
- **AND** update mode repairs a missing or stale `overmind-plan-semantic-review` runner skill folder from canonical source

#### Scenario: Incomplete payload fails before writing runner targets
- **WHEN** the packaged `overmind-plan-semantic-review` skill is missing `SKILL.md` or `assets/`
- **THEN** installation fails before writing any runner skill target

### Requirement: Migrated Semantic-Review Bash Assets Are Not Staged

`project_setup_first_init_machine.sh` SHALL NOT stage the migrated step 8.4 bash assets — the `feature_implementation_plan_semantic_review.sh` command, the `implementation_plan_semantic_review_rule.md` rule, and the `check_implementation_plan_semantic_review_quality.sh` helper — into a runtime ASDLC workspace. Update mode SHALL remove these staged files when they exist in an already-provisioned workspace, using the obsolete-staged-command list for the removed command. The shared `class_repo_paths.sh`, `sync_repo_to_default_branch.sh`, `list_committed_sibling_features.sh`, `check_cross_class_peer_trigger.sh`, the surface quality helpers, and the downstream un-migrated worker assignment/readiness assets SHALL remain staged, as those are not migrated by this change.

#### Scenario: Fresh setup omits the migrated step-8.4 bash assets
- **WHEN** `project_setup_first_init_machine.sh` creates a fresh ASDLC workspace
- **THEN** `.commands/feature_implementation_plan_semantic_review.sh`, `.rules/implementation_plan_semantic_review_rule.md`, and `.helper/check_implementation_plan_semantic_review_quality.sh` are not present
- **AND** the shared repo/cross-class/sibling libs, the surface quality helpers, and the un-migrated worker assignment/readiness commands, rules, and helpers remain staged

#### Scenario: Update mode removes stale migrated step-8.4 assets
- **WHEN** `project_setup_first_init_machine.sh` runs in update mode for a workspace that still contains the migrated step-8.4 command, rule, or helper
- **THEN** those staged files are removed, and the `overmind-plan-semantic-review` runner skill folders are present instead
- **AND** the shared libs and un-migrated worker assignment/readiness assets remain staged

### Requirement: Semantic-Review Template And Golden Example Are Skill-Local

`project_setup_first_init_machine.sh` SHALL deploy `implementation_plan_semantic_review_TEMPLATE.md` and `implementation_plan_semantic_review_GOLDEN_EXAMPLE.md` only under each installed `overmind-plan-semantic-review/assets/` directory. It SHALL NOT stage flat copies under `.templates/` or `.golden_examples/`. Update mode SHALL remove those flat copies when they exist in an already-provisioned workspace.

#### Scenario: Fresh setup omits flat semantic-review assets
- **WHEN** `project_setup_first_init_machine.sh` creates a fresh ASDLC workspace
- **THEN** both runner skill folders contain the template and golden example under `assets/`
- **AND** `.templates/implementation_plan_semantic_review_TEMPLATE.md` and `.golden_examples/implementation_plan_semantic_review_GOLDEN_EXAMPLE.md` are absent

#### Scenario: Update mode removes stale flat semantic-review assets
- **WHEN** update mode runs for a workspace containing the legacy flat template or golden example
- **THEN** those flat files are removed while the skill-local assets remain installed

### Requirement: E2e runner invokes skill for phase 8.4 with read-only guards and output assertion

`project_add_feature_e2e.sh` phase 8.4 SHALL launch the `overmind-plan-semantic-review` skill via Codex using `run_plan_semantic_review_skill`, following the established migrated-launcher pattern: it SHALL invoke `overmind context plan-semantic-review <feature-path>` **once** (returning the context exit code on a nonzero context result) and snapshot **exactly** the read-only inputs the context command emits as `- read_only_input: <path>` lines — it SHALL NOT independently resolve active classes or applicable surface-map paths in the launcher, since that parsing/path logic is owned by `context/plan-semantic-review.ts` and duplicating it risks divergence that leaves inputs unguarded. When a Codex session is launched, `run_plan_semantic_review_skill` SHALL, on every exit path: (1) `cmp`-assert each snapshotted input byte-unchanged, with a read-only-input corruption failure taking precedence over every other outcome (fail the phase regardless of the model exit code); (2) if the model session exited nonzero, return that nonzero exit to `run_phase_by_index` — which maps any launched-command nonzero exit to phase failure (`PHASE_EXECUTION_FAILED_RC`, `40`) — without asserting output and without treating it as a clean decline (a launched Codex exit of `30` is a model failure, not the decline signal); (3) assert `implementation_plan_semantic_review.md` was produced only after a clean (`0`) model exit. The decline/skip signals are owned by `run_phase_by_index` and generated only on the pre-launch confirmation-declined path, which launches no session, runs no guard, and asserts no output; because 8.4 is the final phase, an ordinary decline returns `30` and a closed input stream returns `20` (the `10` "later required phase" branch is unreachable for the last phase). Phase 8.4 SHALL NOT snapshot or guard `implementation_plan.md`, which is a mutable target the step may legitimately patch. Phase 8.4 SHALL NOT run any repo sync (step 8.4 has no pre-session sync) and SHALL NOT run either quality gate itself. The existing before/after phase-8.4 checkpoint commits and the pre-launch decline (`20`/`30`) pass-through SHALL be preserved.

When the operator explicitly requests `--resume 8.4`, required-step discovery MAY report `next step: none` because optional steps do not make a feature unfinished. In that case, the runner SHALL reuse the valid saved feature-path cache for the requested project and proceed directly to phase 8.4 instead of rejecting the resume. Runs without `--resume 8.4` SHALL retain the existing completed-feature behavior.

#### Scenario: Explicit 8.4 resume uses completed cached feature
- **WHEN** the saved feature-path cache is valid for the selected project, discovery reports no unfinished features, and the operator invokes `--resume 8.4`
- **THEN** the runner selects the cached feature, runs its scanner for context, and offers the phase-8.4 confirmation without scaffolding a new feature

#### Scenario: Phase 8.4 starts the skill
- **WHEN** the e2e runner reaches phase 8.4
- **THEN** a Codex session is started with a prompt that names the `overmind-plan-semantic-review` skill and includes the exact `context plan-semantic-review`, `gate plan-semantic-review`, and `gate implementation-plan` commands

#### Scenario: Launcher snapshots exactly the context read-only manifest
- **WHEN** `run_plan_semantic_review_skill` prepares the phase-8.4 session
- **THEN** it invokes `overmind context plan-semantic-review` once and snapshots exactly the inputs the context command emits as `- read_only_input:` lines, without independently resolving active classes or surface-map paths in the launcher

#### Scenario: Read-only input mutation fails the phase
- **WHEN** the model modifies `technical_requirements.md` or an applicable surface map during the phase-8.4 session
- **THEN** the `cmp` post-session check detects drift and the phase fails with an actionable error

#### Scenario: Plan mutation does not fail the phase
- **WHEN** the model patches `implementation_plan.md` during the phase-8.4 session but leaves every read-only input unchanged
- **THEN** the phase does not fail on a read-only guard for `implementation_plan.md`

#### Scenario: No sync runs for phase 8.4
- **WHEN** the e2e runner reaches phase 8.4
- **THEN** no `overmind sync` command is invoked for the phase-8.4 session

#### Scenario: E2e does not run the gates itself
- **WHEN** the e2e runner reaches phase 8.4
- **THEN** it does not shell out to `gate plan-semantic-review` or `gate implementation-plan`; only the model/skill owns the gate loop

#### Scenario: Output file not produced after a clean exit
- **WHEN** the Codex session exits `0` but `implementation_plan_semantic_review.md` is not present in the feature directory
- **THEN** the e2e runner fails the phase with an error naming the missing file

#### Scenario: Pre-launch decline does not assert output
- **WHEN** phase 8.4 confirmation is declined before launch, so `run_phase_by_index` returns `30` (final phase, no later required phase) — or `20` on a closed input stream — without launching a Codex session and no `implementation_plan_semantic_review.md` is produced
- **THEN** no read-only guard runs, no missing-output assertion runs, and the `20`/`30` skip/decline signal propagates as designed

#### Scenario: Launched model nonzero exit maps to phase failure
- **WHEN** a launched Codex session exits nonzero (including `30`) with every read-only input unchanged
- **THEN** `run_plan_semantic_review_skill` returns the nonzero exit to `run_phase_by_index`, which maps it to phase failure (`PHASE_EXECUTION_FAILED_RC`), asserts no output, and does not treat the exit as a clean decline

#### Scenario: Corruption on a nonzero model exit still fails the phase
- **WHEN** a launched Codex session mutates a read-only input and then exits nonzero
- **THEN** the read-only `cmp` guard runs and the phase fails with the read-only-corruption error, which takes precedence over the returned model exit status
