## ADDED Requirements

### Requirement: ears-review structural validation

The `ears-review` validator SHALL validate a feature's `requirements_ears_review.md` ledger with behavior parity to the former `check_requirements_ears_review_quality.sh`. It SHALL exit `1` when the target is empty or contains only whitespace, and SHALL exit `1` when the artifact still contains any `[UNFILLED]` placeholder. It SHALL require the sections `## 1. Document Meta`, `## 2. Review Guidance`, and `## 3. Findings Ledger`. It SHALL require the meta keys `feature_id`, `feature_title`, `source_feature_br_summary`, `source_requirements_ears`, `review_status`, and `last_updated`, each present and filled, and SHALL require `review_status` to be `in_progress` or `complete`. It SHALL parse `### Finding <N> — <Title>` blocks and require each block to contain the fields `severity`, `state`, `source_br_summary_reference`, `related_requirement_targets`, `gap_summary`, `recommendation`, `suggested_ears_change`, `user_prompt`, `user_response`, and `resolution_notes`, each present and filled; `severity` SHALL be one of `High`, `Medium`, `Low`, and `state` SHALL be one of `escalated`, `added to ears`, `rejected`, `postponed` (matched after normalization to lowercase with collapsed whitespace and stripped quotes). When no Finding blocks exist, the ledger SHALL declare `- no_findings: true` and `review_status` SHALL be `complete`; when Finding blocks are present, `no_findings: true` SHALL be rejected. `review_status: complete` SHALL be rejected when any finding is in `state: escalated`, and `review_status: in_progress` SHALL be rejected when Finding blocks exist but none is `escalated`. The validator SHALL exit `0` on a structurally complete ledger, exit `1` with actionable `quality gate failed: …` messages on any structural violation, and exit `2` on runtime failure. The validator SHALL NOT read or mutate `feature_br_summary.md` or `requirements_ears.md`.

#### Scenario: Structurally complete ledger passes

- **WHEN** `overmind gate ears-review <feature-path>` runs against a `requirements_ears_review.md` with all required sections, filled meta keys, a valid `review_status`, and every Finding block carrying all ten fields with valid `severity`/`state` consistent with `review_status`
- **THEN** the validator exits `0` with a pass result

#### Scenario: Empty or unfilled target fails

- **WHEN** `requirements_ears_review.md` is empty, whitespace-only, or still contains an `[UNFILLED]` placeholder
- **THEN** the validator exits `1` reporting the empty target or the remaining `[UNFILLED]` placeholders

#### Scenario: Missing section or meta key fails

- **WHEN** the ledger is missing `## 1. Document Meta`, `## 2. Review Guidance`, or `## 3. Findings Ledger`, or a required meta key is missing or unfilled
- **THEN** the validator exits `1` naming the missing section or meta key

#### Scenario: Invalid finding field, severity, or state fails

- **WHEN** a Finding block is missing one of its ten required fields, or has a `severity` outside {High, Medium, Low} or a `state` outside {escalated, added to ears, rejected, postponed}
- **THEN** the validator exits `1` naming the offending finding block and field/value

#### Scenario: no_findings and review_status consistency

- **WHEN** there are no Finding blocks but the ledger lacks `- no_findings: true` or `review_status` is not `complete`, or there are Finding blocks but `no_findings: true` is present
- **THEN** the validator exits `1` reporting the no_findings/review_status inconsistency

#### Scenario: review_status versus escalated findings

- **WHEN** `review_status: complete` but at least one finding remains `escalated`, or `review_status: in_progress` but findings exist with none `escalated`
- **THEN** the validator exits `1` reporting the review_status/escalated inconsistency

#### Scenario: Runtime failure escalates

- **WHEN** the target path cannot be read for reasons other than emptiness
- **THEN** the validator exits `2` with a runtime error message

### Requirement: ears-review context assembly

The `ears-review` context builder SHALL assemble the step's dynamic context for a feature path with parity to the prompt context of `feature_requirements_ears_review.sh`. It SHALL resolve the feature path, the read-only `feature_br_summary.md` source (exit `2` if absent), the `requirements_ears.md` source/target (exit `2` if absent), and the `requirements_ears_review.md` ledger target. On success the assembled block SHALL include the workspace root, the feature artifact root, the read-only BR source path, the two allowed-write targets (`requirements_ears.md` and `requirements_ears_review.md`), the exact `ears-review` gate command, and skill-relative asset references for the review template and golden example; the step rule is inlined in `SKILL.md`, not emitted as a separate rule-file reference.

#### Scenario: Context assembled for a reviewable feature

- **WHEN** `overmind context ears-review <feature-path>` runs and both `feature_br_summary.md` and `requirements_ears.md` exist for a resolvable feature folder
- **THEN** the builder prints the assembled context block including the read-only BR source, the allowed-write list (`requirements_ears.md` and `requirements_ears_review.md`), and the exact `ears-review` gate command, and exits `0`

#### Scenario: Missing BR summary blocks context

- **WHEN** `feature_br_summary.md` is absent for the feature
- **THEN** the builder exits `2` with a message that the upstream BR summary is required

#### Scenario: Missing EARS requirements blocks context

- **WHEN** `requirements_ears.md` is absent for the feature
- **THEN** the builder exits `2` with a message that the upstream EARS requirements are required

#### Scenario: Context uses skill-relative asset paths

- **WHEN** `overmind context ears-review <feature-path>` emits asset references
- **THEN** those references use `assets/...` paths relative to the loaded `overmind-ears-review` skill directory
- **AND** the context output does not hardcode `.claude/skills/...`, `.codex/skills/...`, or any source-repo path

### Requirement: overmind-ears-review skill

The packaged `overmind-ears-review` skill SHALL provide the model-facing orchestrator for the optional step 5.1 EARS review, with `requirements_ears_review_rule.md` inlined into `SKILL.md` and the review template plus golden example under `assets/`. `SKILL.md` SHALL instruct the model to: run `overmind context ears-review <feature-path>`; compare `requirements_ears.md` against the validated `feature_br_summary.md` for material business findings only (missing guard/rejection behavior, missing actor/permission constraint, missing state-dependent behavior, ambiguous scope, a source business rule absent from EARS, or an EARS statement that overshoots/contradicts the source), excluding style-only, wording-only, and implementation-only findings; surface one finding at a time, highest severity first then source order, using the exact 3-line interaction format (`Here is the finding: …`, `I would recommend: …`, `Should I add recommended changes? Please answer yes/no or provide your answer.`); apply the yes/no/custom answer-handling rules and keep each finding in exactly one terminal-or-pending `state` (`escalated`, `added to ears`, `rejected`, `postponed`); maintain the durable findings ledger in `requirements_ears_review.md`, preserving already-resolved findings; write only `requirements_ears.md` and `requirements_ears_review.md` and never modify `feature_br_summary.md`; set `review_status: complete` only when no finding remains `escalated`, and when there are no material findings create `requirements_ears_review.md` with `review_status: complete` and `- no_findings: true`; and run `overmind gate ears-review <feature-path>` after every write or repair. Gate exit handling SHALL be: `0` complete; `1` read the gate output, repair the ledger (and EARS if needed), and rerun the gate; `2` stop and report the blocker. The two literal final-response lines — the success line `requirements_ears extra review phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase` and the infeasibility line `based on provided reasons, requirements_ears extra review cannot be completed with current BR/EARS input. Please provide instructions what to do, or adjust artifacts and rerun this phase` — SHALL appear only in `SKILL.md`.

#### Scenario: Skill drives the review gate loop

- **WHEN** the model loads `overmind-ears-review` and the gate exits `1`
- **THEN** the model reads the gate output, repairs `requirements_ears_review.md` (and `requirements_ears.md` if the finding decision requires it), and reruns `overmind gate ears-review` without modifying `feature_br_summary.md`

#### Scenario: Skill surfaces one finding at a time with the fixed format

- **WHEN** the model has one or more active findings
- **THEN** it presents the highest-severity finding first using the exact 3-line interaction format and waits for the operator's yes/no/custom answer before advancing

#### Scenario: Skill finishes on gate pass with the success line

- **WHEN** the gate exits `0` and no finding remains `escalated`
- **THEN** the model ends its final response with the exact success final-response line defined only in `SKILL.md`

#### Scenario: Skill records no_findings when no material gaps exist

- **WHEN** the model finds no material business gaps between EARS and the BR summary
- **THEN** it creates `requirements_ears_review.md` with `review_status: complete` and `- no_findings: true`, makes no EARS edits, and ends with the success final-response line

#### Scenario: Skill stops with the infeasibility line when review cannot complete

- **WHEN** the model determines review completion is not feasible with the current BR/EARS input or operator decisions
- **THEN** it stops finalization and ends with the exact infeasibility final-response line defined only in `SKILL.md`, asking the operator for instructions

#### Scenario: Skill stops on gate runtime failure

- **WHEN** the gate exits `2`
- **THEN** the model stops, reports the blocker, and waits for operator instructions without further edits

#### Scenario: Read-only BR source and dual-target boundary are preserved

- **WHEN** the model applies accepted findings
- **THEN** it writes only `requirements_ears.md` and `requirements_ears_review.md` and does not modify `feature_br_summary.md`

### Requirement: Feature e2e orchestrator drives the ears-review skill

The `project_add_feature_e2e.sh` phase 5.1 SHALL launch the `overmind-ears-review` skill via a Codex session (mirroring the phase 4.2 / phase 5 skill launchers) instead of the deleted `feature_requirements_ears_review.sh`. The launcher prompt SHALL include only runtime bindings and the exact `context`/`gate ears-review` commands; it SHALL NOT duplicate the skill's literal final-response lines, the 3-line interaction format, or gate exit-code handling. The phase SHALL NOT run the model gate itself. To preserve the former `ensure_feature_br_summary_unchanged` protection deterministically, the launcher SHALL snapshot `feature_br_summary.md` before launching the skill session and SHALL assert it is byte-unchanged after the session completes, failing the phase with an actionable error if it was modified; this guard is the only deterministic post-skill step and is not a re-run of the model gate.

#### Scenario: Phase 5.1 launches the ears-review skill

- **WHEN** the e2e orchestrator runs phase 5.1 for a feature
- **THEN** it starts a Codex session telling the model to load `overmind-ears-review` with the runtime bindings and the exact `context`/`gate` `ears-review` commands
- **AND** the launcher prompt does not contain either of the skill's literal final-response lines

#### Scenario: Orchestrator does not run the review gate itself

- **WHEN** phase 5.1 runs
- **THEN** the orchestrator does not invoke `overmind gate ears-review`; the model owns the gate loop

#### Scenario: Missing skill or CLI fails before launching

- **WHEN** phase 5.1 runs but the installed `overmind-ears-review` skill or `.overmind/overmind.js` is absent from the runtime workspace
- **THEN** the orchestrator fails before launching the Codex session, reporting the missing skill or CLI

#### Scenario: Read-only BR mutation fails the phase

- **WHEN** the skill session completes but `feature_br_summary.md` differs from its pre-launch snapshot
- **THEN** phase 5.1 fails with an actionable error reporting that the read-only BR summary must not be modified, and does not report the phase as successful
