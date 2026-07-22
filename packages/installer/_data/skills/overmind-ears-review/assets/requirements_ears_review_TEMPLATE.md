# Requirements EARS Extra Review - Template

Use this artifact to track review findings recorded by the step 5.1 review of
`requirements_ears.md` against its read-only sources `user_br_input.md`,
`feature_br_summary.md`, and `missing_br_data.md`.

## 1. Document Meta
- feature_id: [UNFILLED]
- feature_title: [UNFILLED]
- source_feature_br_summary: [UNFILLED]
- source_user_br_input: [UNFILLED]
- source_requirements_ears: [UNFILLED]
- review_status: in_progress
- last_updated: [UNFILLED]

## 2. Review Guidance
- completion_rule: Set `review_status: complete` only when every finding is in one of these terminal states: `added to ears`, `rejected`, `postponed`.
- pending_state: `escalated`
- allowed_severity: `High`, `Medium`, `Low`
- user_question_format: `Here is the finding: <finding summary>. I would recommend: <recommended change>. Should I add recommended changes? Please answer yes/no or provide your answer.`

## 3. Findings Ledger
- no_findings: true

---

### Finding <N> - <Short gap title>
- severity: Medium
- state: escalated
- source_br_summary_reference: <section, bullet, or note in feature_br_summary.md, or `none`>
- source_user_br_input_reference: <section, bullet, or note in user_br_input.md, or `none`>
- related_requirement_targets: <Requirement ids to update, or `new requirement`>
- gap_summary: <what is missing, ambiguous, or inconsistent in requirements_ears.md>
- recommendation: <recommended requirement change in plain language>
- suggested_ears_change: <precise EARS wording or edit direction to apply>
- user_prompt: Here is the finding: <gap summary>. I would recommend: <recommended change>. Should I add recommended changes? Please answer yes/no or provide your answer.
- user_response: [UNFILLED]
- resolution_notes: [UNFILLED]
