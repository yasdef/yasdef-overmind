# Implementation Plan Semantic Review - Golden Example

## 1. Document Meta
- feature_id: ORD-42
- feature_title: order-projection-refresh
- source_implementation_plan: projects/p1/feature-a/implementation_plan.md
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_technical_requirements: projects/p1/feature-a/technical_requirements.md
- review_status: complete
- last_updated: 2026-04-11

## 2. Review Guidance
- completion_rule: Set `review_status: complete` only when every finding is terminal (`applied`, `rejected`, `postponed`) or `no_findings: true`.
- user_question_format: `Which finding numbers should I apply to implementation_plan.md? (examples: 1,3 | all | none | postpone 2 | reject 4)`
- allowed_finding_types: step_scope_overlap, technical_gap_mix, dependency_ordering, requirement_grouping
- allowed_severity: High, Medium, Low
- allowed_states: added, applied, rejected, postponed

## 3. Findings Ledger
### Finding 1 - Backend step mixes two independent read-path slices
- severity: Medium
- finding_type: step_scope_overlap
- state: applied
- target_steps: Step 1.2
- related_requirements: REQ-6
- related_evidence: gap/TECH_REQ-6, comp/backend-order-query-controller
- summary: One backend step combines query read-service completion and error-contract hardening that can be reviewed and delivered independently.
- rationale: Bundling these slices hides handoff checkpoints and makes rollback decisions harder if one sub-slice fails.
- recommendation: Split Step 1.2 into two ordered backend steps: read-path completion first, then error-contract hardening.
- user_selection: selected
- plan_patch_summary: Split former Step 1.2 into new Steps 1.2 and 1.3 with explicit dependency.
- resolution_notes: User selected finding 1 for application; plan was updated accordingly.

### Finding 2 - Client alignment order is semantically weak for shared contract rollout
- severity: Low
- finding_type: dependency_ordering
- state: postponed
- target_steps: Step 1.4, Step 1.5
- related_requirements: REQ-4, REQ-6
- related_evidence: gap/TECH_REQ-4, comp/frontend-order-projection-client, comp/mobile-order-projection-client
- summary: Client alignment steps depend on backend query completion but not explicitly on contract-hardening work.
- rationale: Client work may start against a moving contract if contract-hardening stays implicit.
- recommendation: Add explicit dependency from client steps to backend contract-hardening step.
- user_selection: postponed
- plan_patch_summary: No implementation plan change in this pass.
- resolution_notes: User chose to postpone this finding to a later review pass.
