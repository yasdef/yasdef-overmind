# Implementation Plan Semantic Review

Use this artifact to track semantic findings for `implementation_plan.md`, user
selection, and applied plan updates.

## 1. Document Meta
- feature_id: [UNFILLED]
- feature_title: [UNFILLED]
- source_implementation_plan: [UNFILLED]
- source_project_definition: [UNFILLED]
- source_requirements_ears: [UNFILLED]
- source_technical_requirements: [UNFILLED]
- review_status: in_progress
- last_updated: [UNFILLED]

## 2. Review Guidance
- completion_rule: Set `review_status: complete` only when every finding is terminal (`applied`, `rejected`, `postponed`) or `no_findings: true`; terminal `delivered_surface_consumption_unclear` and `repo_scaffold_readiness_unclear` findings require non-empty `resolution_notes`.
- user_question_format: `Which finding numbers should I apply to implementation_plan.md? (examples: 1,3 | all | none | postpone 2 | reject 4)`
- allowed_finding_types: step_scope_overlap, technical_gap_mix, dependency_ordering, requirement_grouping, delivered_surface_consumption_unclear, repo_scaffold_readiness_unclear
- allowed_severity: High, Medium, Low
- allowed_states: added, applied, rejected, postponed

## 3. Findings Ledger
- no_findings: true

---

### Finding <N> - <Short semantic finding title>
- severity: Medium
- finding_type: step_scope_overlap
- state: added
- target_steps: Step 1.2
- related_requirements: REQ-1, REQ-2
- related_evidence: gap/TECH_REQ-1, comp/example-component
- summary: <what semantic issue exists in current slicing/order>
- rationale: <why this issue matters for execution quality>
- recommendation: <recommended split/reorder/regroup action>
- user_selection: <selected | rejected | postponed | [UNFILLED]>
- plan_patch_summary: <exact change applied to implementation_plan.md, or no change>
- resolution_notes: <decision and final outcome>
