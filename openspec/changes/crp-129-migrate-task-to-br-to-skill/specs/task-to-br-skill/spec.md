## ADDED Requirements

### Requirement: task-to-br structural validation

The `task-to-br` validator SHALL validate a feature's business-requirements artifacts with behavior parity to the former `check_task_to_br_quality.sh`. It SHALL operate on `feature_br_summary.md` (the target), `user_br_input.md`, and `missing_br_data.md` in the feature folder, and SHALL report a recoverable problem (exit `1`) when any of the following hold:

- `user_br_input.md` is absent, or its `epic_or_story` block contains no real source story/request content.
- `missing_br_data.md` is absent (it MUST exist, with an empty unresolved ledger when no business gaps remain).
- `## 1. Document Meta` is missing, or `source_type` is unfilled or does not include `User input`, or `last_updated` is unfilled or not `YYYY-MM-DD`.
- `### 2.1 Original request summary` short summary is unfilled, or `### 3.1 Business goal` primary_business_goal is unfilled.
- `## 6. Functional Requirements` has no meaningful `- FR-N: ...` item, or `## 7. Business Rules and Decision Logic` has no meaningful `- BR-N: ...` item.
- Unresolved items under `## 15. Open Questions`, `### Needs validation`, or `### 5.3 Open scope boundaries` are not moved into the `missing_br_data.md` ledger; or ledger items lack `rised=false|true`; or unresolved rised items exist while `## 6. Latest User Answers -> answers` or `## 7. Loop Decision -> unresolved_after_stop` is `[UNFILLED]`.

#### Scenario: Captured user input lacks story content

- **WHEN** `user_br_input.md` exists but its `epic_or_story` block has no source story content
- **THEN** the validator exits `1` with a message that `user_br_input.md -> epic_or_story must contain actual source story/request content`

#### Scenario: Missing required summary section

- **WHEN** `feature_br_summary.md` has an unfilled `### 2.1 Original request summary` short summary
- **THEN** the validator exits `1` with a message naming that unfilled section

#### Scenario: Unresolved open question not in the ledger

- **WHEN** `## 15. Open Questions` contains an unresolved item that is not recorded in `missing_br_data.md`
- **THEN** the validator exits `1` with a message requiring the item be moved to `missing_br_data.md` as a `rised_item_N` with `rised=false`

#### Scenario: Fully populated artifacts pass

- **WHEN** all required sections/fields are filled and unresolved items are correctly recorded in the ledger
- **THEN** the validator exits `0` with a pass message

### Requirement: overmind-task-to-br skill

The repository SHALL provide an `overmind-task-to-br` agent skill at `skills/overmind-task-to-br/` containing `SKILL.md` (with the former task-to-br rule inlined and the orchestrator's former prompt logic) and an `assets/` directory holding the BR-summary template and golden example. The `SKILL.md` SHALL instruct the model to: read the captured task input and required inputs, write/repair `feature_br_summary.md` (and `missing_br_data.md`), then run `overmind-gate task-to-br <feature-path>` and act on its exit code — finish on `0`, repair the artifact per the reported problems and rerun on `1`, and stop and inform the user on `2`. The model SHALL own the repair loop; the skill SHALL NOT auto-run the gate from an orchestrator.

#### Scenario: Skill drives generate-then-validate

- **WHEN** the operator invokes `overmind-task-to-br` for a feature
- **THEN** the model writes the BR artifacts and runs `overmind-gate task-to-br <feature-path>` before finalizing

#### Scenario: Skill repairs on recoverable failure

- **WHEN** `overmind-gate task-to-br` exits `1`
- **THEN** the model revises the artifact to address each reported problem and reruns the gate until it exits `0` or `2`

#### Scenario: Skill escalates on gate error

- **WHEN** `overmind-gate task-to-br` exits `2`
- **THEN** the model stops, reports that validation cannot complete, and waits for user instructions

### Requirement: Standalone runnability via golden example

The `overmind-task-to-br` skill SHALL be runnable in isolation without first executing upstream steps, by supplying the reference input `feature_br_summary.md` from the bundled `feature_br_summary_GOLDEN_EXAMPLE.md`.

#### Scenario: Pilot runs from a single canned input

- **WHEN** a developer places the golden-example BR summary into a feature folder and invokes the skill
- **THEN** the full loop (generate/repair → `overmind-gate task-to-br` → exit code) runs without any other upstream artifact being produced first
