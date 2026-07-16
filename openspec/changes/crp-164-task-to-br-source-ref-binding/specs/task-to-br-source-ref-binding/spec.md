## ADDED Requirements

### Requirement: Task-to-BR derives the complete captured-source reference set

The task-to-BR runtime SHALL derive its required source references from the captured input as the canonical workspace-relative path to `<feature-path>/user_br_input.md` followed by the trimmed `epic_story_source_file` value recorded in that artifact. It SHALL remove duplicate values while preserving first-seen order and SHALL expose the resulting set in task-to-BR context after capture has completed.

#### Scenario: Local file capture produces both traceability hops

- **WHEN** `user_br_input.md` records `epic_story_source_file: projects/p1/feature-a/feature_requirements.txt`
- **THEN** task-to-BR context exposes `projects/p1/feature-a/user_br_input.md` and `projects/p1/feature-a/feature_requirements.txt` as required source references
- **AND** the capture-record reference precedes the original-file reference

#### Scenario: Jira capture produces both traceability hops

- **WHEN** `user_br_input.md` records `epic_story_source_file: jira:CRP-164`
- **THEN** task-to-BR context exposes `projects/p1/feature-a/user_br_input.md` and `jira:CRP-164` as required source references

#### Scenario: Derivation begins only after capture

- **WHEN** task-to-BR starts for a feature that does not yet contain `user_br_input.md`
- **AND** capture produces `user_br_input.md` before task-to-BR context is invoked
- **THEN** required source references are derived from the newly captured artifact
- **AND** this source-reference derivation introduces no pre-session context requirement

### Requirement: Task-to-BR binds every captured source into the BR summary

The installed task-to-BR skill SHALL write every required captured-source reference into `feature_br_summary.md` `## 1. Document Meta -> source_refs` as exact semicolon-delimited elements. It SHALL use the canonical capture-record-first order for newly written values and SHALL preserve additional populated references already present in the field.

#### Scenario: Local capture is bound into a new summary

- **WHEN** task-to-BR context requires the feature's `user_br_input.md` path and a local story-file path
- **THEN** the skill writes both exact paths into `source_refs`
- **AND** it places the `user_br_input.md` path before the local story-file path

#### Scenario: Jira capture is bound into a new summary

- **WHEN** task-to-BR context requires the feature's `user_br_input.md` path and `jira:CRP-164`
- **THEN** the skill writes both exact values into `source_refs`

#### Scenario: Existing additional reference is retained

- **WHEN** `source_refs` already contains a populated reference that is not one of the two required captured-source references
- **THEN** the skill adds any missing required references and retains the additional reference

### Requirement: Task-to-BR gate enforces complete source binding

The task-to-BR gate SHALL parse `source_refs` from `feature_br_summary.md` `## 1. Document Meta` as semicolon-delimited, whitespace-trimmed elements and SHALL require exact set membership for every canonical captured-source reference. Ordering SHALL NOT affect gate success, and additional populated references SHALL be accepted.

#### Scenario: Complete source binding passes

- **WHEN** `source_refs` contains the exact workspace-relative `user_br_input.md` path and the exact `epic_story_source_file` locator
- **THEN** source-reference validation contributes no problem and the gate may exit `0` when all other task-to-BR checks pass

#### Scenario: Durable capture reference is missing

- **WHEN** `source_refs` contains the original story locator but omits the canonical `user_br_input.md` path
- **THEN** the gate exits `1`
- **AND** its diagnostic names the missing canonical capture-record reference

#### Scenario: Original story reference is missing

- **WHEN** `source_refs` contains the canonical `user_br_input.md` path but omits the `epic_story_source_file` locator
- **THEN** the gate exits `1`
- **AND** its diagnostic names the missing original-source locator

#### Scenario: Source references are missing or unfilled

- **WHEN** `## 1. Document Meta -> source_refs` is absent, empty, or `[UNFILLED]`
- **THEN** the gate exits `1` with an actionable field-level diagnostic

#### Scenario: Captured input artifact is missing at gate time

- **WHEN** the task-to-BR gate runs for a feature without `<feature-path>/user_br_input.md`
- **THEN** the gate exits `1`
- **AND** its diagnostic names `user_br_input.md` as missing so task-to-BR capture can be rerun

#### Scenario: Captured source metadata cannot define the complete set

- **WHEN** `user_br_input.md -> epic_story_source_file` is absent, empty, or `[UNFILLED]`
- **THEN** the gate exits `1` with a diagnostic naming that captured-input field

#### Scenario: Substring does not satisfy exact reference membership

- **WHEN** a required reference appears only as a substring of a different `source_refs` element
- **THEN** the gate exits `1` and reports the exact required reference as missing

#### Scenario: Extra references and alternate required-reference order pass

- **WHEN** `source_refs` contains every exact required reference in a different order and also contains another populated reference
- **THEN** source-reference validation passes

### Requirement: Installed task-to-BR payload preserves the source-binding contract

The Overmind installer SHALL deploy the updated task-to-BR skill and golden example to both supported runner skill directories on fresh install and update. The installed skill SHALL contain the complete source-binding rule, and the installed golden example SHALL use `projects/auth-platform/self-service-password-reset/user_br_input.md; jira:JIRA-AUTH-241` to demonstrate the capture path followed by the capture's canonical Jira locator rather than a bare ticket reference.

#### Scenario: Fresh install exposes the restored contract

- **WHEN** an ASDLC workspace is initialized from the updated package
- **THEN** both `.codex/skills/overmind-task-to-br` and `.claude/skills/overmind-task-to-br` contain the updated skill rule and golden example

#### Scenario: Update replaces a stale task-to-BR payload

- **WHEN** an existing ASDLC workspace is updated through the installer
- **THEN** stale installed task-to-BR skill content is replaced with the packaged complete source-binding contract
