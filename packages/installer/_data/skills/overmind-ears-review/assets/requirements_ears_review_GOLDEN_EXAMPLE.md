# Requirements EARS Extra Review - Golden Example

## 1. Document Meta
- feature_id: FEAT-2001
- feature_title: Admin moderation workspace access rules
- source_feature_br_summary: projects/p1/admin-moderation/feature_br_summary.md
- source_user_br_input: projects/p1/admin-moderation/user_br_input.md
- source_requirements_ears: projects/p1/admin-moderation/requirements_ears.md
- review_status: complete
- last_updated: 2026-04-11

## 2. Review Guidance
- completion_rule: Set `review_status: complete` only when every finding is in one of these terminal states: `added to ears`, `rejected`, `postponed`.
- pending_state: `escalated`
- allowed_severity: `High`, `Medium`, `Low`
- user_question_format: `Here is the finding: <finding summary>. I would recommend: <recommended change>. Should I add recommended changes? Please answer yes/no or provide your answer.`

## 3. Findings Ledger
### Finding 1 - ACTIVE qualifier narrows duplicate-account prohibition
- severity: High
- state: added to ears
- source_br_summary_reference: feature_br_summary.md -> business rules, BR-4 duplicate-account handling
- source_user_br_input_reference: user_br_input.md -> section 2 story, "the system must never let a user hold two accounts of the same account type"
- related_requirement_targets: Requirement 12
- gap_summary: The raw story forbids duplicate accounts for the same user and account type without any status qualifier, but feature_br_summary.md and Requirement 12 block duplicates only when the existing account is ACTIVE. The added ACTIVE qualifier permits a duplicate against a non-ACTIVE existing account, which the raw story forbids.
- recommendation: Restore the status-independent prohibition unless the summary records an intentional clarified decision to scope it to ACTIVE accounts; if it does, confirm that decision with the operator instead of silently keeping the narrower rule.
- suggested_ears_change: Update Requirement 12 so duplicate accounts of the same account type are rejected regardless of the existing account status, removing the ACTIVE qualifier from the guard condition.
- user_prompt: Here is the finding: the raw story forbids duplicate same-type accounts outright, but the summary and Requirement 12 only block them when the existing account is ACTIVE, which narrows the rule. I would recommend: remove the ACTIVE qualifier so duplicates are rejected regardless of existing account status. Should I add recommended changes? Please answer yes/no or provide your answer.
- user_response: yes
- resolution_notes: Removed the ACTIVE qualifier from Requirement 12 so the duplicate-account prohibition matches the raw story scope.

### Finding 2 - Audit export timing left intentionally open
- severity: Low
- state: postponed
- source_br_summary_reference: feature_br_summary.md -> open scope boundaries for reporting follow-up
- source_user_br_input_reference: none
- related_requirement_targets: new requirement
- gap_summary: The summary hints at audit export support later, but it is not committed as in-scope behavior for this feature and does not narrow any raw obligation.
- recommendation: Keep audit export out of current requirements_ears.md and revisit only if the feature scope is expanded.
- suggested_ears_change: No current EARS change; track as a future-scope question.
- user_prompt: Here is the finding: audit export timing is noted in the summary but not committed as current scope. I would recommend: keep audit export out of current requirements_ears.md and track it as a future-scope decision. Should I add recommended changes? Please answer yes/no or provide your answer.
- user_response: postpone until reporting epic
- resolution_notes: Left current EARS unchanged and marked the finding for later scope review.
