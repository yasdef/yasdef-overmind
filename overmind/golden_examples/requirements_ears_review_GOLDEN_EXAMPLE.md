# Requirements EARS Extra Review - Golden Example

## 1. Document Meta
- feature_id: FEAT-2001
- feature_title: Admin moderation workspace access rules
- source_feature_br_summary: projects/p1/admin-moderation/feature_br_summary.md
- source_requirements_ears: projects/p1/admin-moderation/requirements_ears.md
- review_status: complete
- last_updated: 2026-04-11

## 2. Review Guidance
- completion_rule: Set `review_status: complete` only when every finding is in one of these terminal states: `added to ears`, `rejected`, `postponed`.
- pending_state: `escalated`
- allowed_severity: `High`, `Medium`, `Low`
- user_question_format: `Here is the finding: <finding summary>. I would recommend: <recommended change>. Should I add recommended changes? Please answer yes/no or provide your answer.`

## 3. Findings Ledger
### Finding 1 - ACTIVE status must guard workspace APIs
- severity: Medium
- state: added to ears
- source_br_summary_reference: feature_br_summary.md -> business rules and access-control notes for moderation workspace
- related_requirement_targets: Requirement 8, Requirement 10, Requirement 15, Requirement 16
- gap_summary: ACTIVE status is enforced at login or open-page level, but post-authentication workspace API access is not explicitly protected in requirements_ears.md.
- recommendation: Add explicit EARS statements that deny moderation workspace access and data to authenticated admins who are not ACTIVE.
- suggested_ears_change: Add a new requirement titled `Restrict workspace use to ACTIVE admins` and update the related access-control requirements so ACTIVE is enforced after authentication as well.
- user_prompt: Here is the finding: ACTIVE status is not explicitly enforced for post-auth workspace API access. I would recommend: add explicit EARS behavior to deny moderation workspace access and data when admin status is not ACTIVE. Should I add recommended changes? Please answer yes/no or provide your answer.
- user_response: yes
- resolution_notes: Added a new access-control requirement and updated the listed requirement blocks to mention ACTIVE status explicitly.

### Finding 2 - Audit export timing left intentionally open
- severity: Low
- state: postponed
- source_br_summary_reference: feature_br_summary.md -> open scope boundaries for reporting follow-up
- related_requirement_targets: new requirement
- gap_summary: The source story hints at audit export support later, but it is not committed as in-scope behavior for this feature.
- recommendation: Keep audit export out of current requirements_ears.md and revisit only if the feature scope is expanded.
- suggested_ears_change: No current EARS change; track as a future-scope question.
- user_prompt: Here is the finding: audit export timing is noted in the source story but not committed as current scope. I would recommend: keep audit export out of current requirements_ears.md and track it as a future-scope decision. Should I add recommended changes? Please answer yes/no or provide your answer.
- user_response: postpone until reporting epic
- resolution_notes: Left current EARS unchanged and marked the finding for later scope review.
