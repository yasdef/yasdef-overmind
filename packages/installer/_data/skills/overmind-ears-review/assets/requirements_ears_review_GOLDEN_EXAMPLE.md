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
- recommendation: Restore the status-independent prohibition; missing_br_data.md contains no answered rised=true item mapping to BR-4, so the ACTIVE scope has no clarification evidence. If an answered item is later mapped to BR-4, confirm the clarified decision with the operator instead of silently keeping the narrower rule.
- suggested_ears_change: Update Requirement 12 so duplicate accounts of the same account type are rejected regardless of the existing account status, removing the ACTIVE qualifier from the guard condition.
- user_prompt: Here is the finding: the raw story forbids duplicate same-type accounts outright, but the summary and Requirement 12 only block them when the existing account is ACTIVE, which narrows the rule. I would recommend: remove the ACTIVE qualifier so duplicates are rejected regardless of existing account status. Should I add recommended changes? Please answer yes/no or provide your answer.
- user_response: yes
- resolution_notes: Removed the ACTIVE qualifier from Requirement 12 so the duplicate-account prohibition matches the raw story scope.

### Finding 2 - Moderator eligibility precondition lost before EARS
- severity: High
- state: added to ears
- source_br_summary_reference: feature_br_summary.md -> business rules, BR-7 moderation queue assignment
- source_user_br_input_reference: user_br_input.md -> section 2 story, "only a moderator who already holds an active workspace membership may be assigned a queue"
- related_requirement_targets: Requirement 5
- gap_summary: The raw story assigns queues only to a moderator who already holds an active workspace membership. feature_br_summary.md BR-7 and Requirement 5 assign a queue to any moderator, and missing_br_data.md records no answered rised=true item mapping to BR-7, so the removed membership guard is raw capture drift rather than a clarified decision. Removing the guard broadens assignment to moderators without workspace membership.
- recommendation: Restore the active-workspace-membership precondition as a guard on queue assignment, because no clarification evidence supports removing it.
- suggested_ears_change: Update Requirement 5 so a queue is assigned only WHEN the target moderator holds an active workspace membership, and rejected otherwise.
- user_prompt: Here is the finding: the raw story only allows queue assignment to a moderator with an active workspace membership, but BR-7 and Requirement 5 drop that precondition and there is no answered clarification item for it. I would recommend: restore the active-membership precondition as a guard on queue assignment. Should I add recommended changes? Please answer yes/no or provide your answer.
- user_response: yes
- resolution_notes: Added the active-workspace-membership guard and its rejection path to Requirement 5 so assignment scope matches the raw story.

### Finding 3 - Expired-invitation rejection absent from BR and EARS
- severity: High
- state: added to ears
- source_br_summary_reference: none
- source_user_br_input_reference: user_br_input.md -> section 2 story, "an invitation that has passed its expiry date must be refused with an explanation"
- related_requirement_targets: new requirement
- gap_summary: The raw story requires refusing an expired workspace invitation with an explanation. feature_br_summary.md carries no invitation-expiry rule at all and requirements_ears.md has no matching criterion, so the obligation was lost before the BR rather than altered inside it. missing_br_data.md contains no answered item covering invitation expiry, so the omission is raw capture drift. source_br_summary_reference is none because no BR location exists to cite.
- recommendation: Add the expired-invitation rejection path as a new EARS requirement so the raw obligation is represented downstream.
- suggested_ears_change: Add a requirement stating that WHEN a user accepts an invitation whose expiry date has passed, the system SHALL refuse the acceptance and return the expiry reason.
- user_prompt: Here is the finding: the raw story requires refusing an expired invitation with an explanation, but neither the BR summary nor the EARS requirements mention invitation expiry at all. I would recommend: add a new EARS requirement for the expired-invitation rejection path. Should I add recommended changes? Please answer yes/no or provide your answer.
- user_response: yes
- resolution_notes: Added a new EARS requirement covering refusal of expired invitations with the expiry reason.

### Finding 4 - Clarified retention window not translated into EARS
- severity: Medium
- state: added to ears
- source_br_summary_reference: feature_br_summary.md -> business rules, BR-9 moderation decision retention window of 90 days
- source_user_br_input_reference: none
- related_requirement_targets: Requirement 18
- gap_summary: BR-9 records a 90-day retention window for moderation decisions, evidenced by answered rised_item_3 in missing_br_data.md with source= section 7 BR-9. The raw story states no retention obligation at all, so this is a clarified decision, but Requirement 18 still states retention without any window. The gap is a BR-to-EARS translation miss, not raw drift, so the raw reference is truthfully none.
- recommendation: Translate the clarified 90-day window into Requirement 18 rather than reopening the retention decision.
- suggested_ears_change: Update Requirement 18 so moderation decisions are retained for 90 days and become eligible for purge afterwards.
- user_prompt: Here is the finding: BR-9 sets a clarified 90-day retention window for moderation decisions, but Requirement 18 states retention with no window. I would recommend: state the 90-day retention window in Requirement 18. Should I add recommended changes? Please answer yes/no or provide your answer.
- user_response: yes
- resolution_notes: Requirement 18 now states the clarified 90-day retention window.

### Finding 5 - Clarified appeal window differs from raw wording but EARS already matches
- severity: Medium
- state: added to ears
- source_br_summary_reference: feature_br_summary.md -> business rules, BR-12 moderation appeal window of 14 days
- source_user_br_input_reference: user_br_input.md -> section 2 story, "a moderated user may appeal within one month"
- related_requirement_targets: Requirement 21
- gap_summary: The raw story allows a one-month appeal window while BR-12 sets 14 days, so the clarified decision narrows raw wording. Answered rised_item_5 in missing_br_data.md with source= section 7 BR-12 maps to that BR answer, so the narrower window is an explicit operator decision rather than raw drift. Requirement 21 already states the 14-day window, so EARS is consistent with the clarified decision; the discrepancy is recorded for traceable disposition, not silently dropped.
- recommendation: Retain the clarified 14-day appeal window and confirm that the narrower scope is intended, because the raw story asked for one month.
- suggested_ears_change: No EARS change required; Requirement 21 already states the clarified 14-day appeal window.
- user_prompt: Here is the finding: the raw story allows a one-month appeal window, but the answered clarification set it to 14 days and Requirement 21 already states 14 days. I would recommend: retain the clarified 14-day window and confirm the narrower scope is intended. Should I add recommended changes? Please answer yes/no or provide your answer.
- user_response: yes
- resolution_notes: Operator confirmed the clarified 14-day appeal window; requirements_ears.md already matched the decision, so no edit was required.
