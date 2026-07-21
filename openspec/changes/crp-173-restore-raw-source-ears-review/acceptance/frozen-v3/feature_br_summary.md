# Feature Business Requirements Summary

## 1. Document Meta
- feature_id: UMS-001v3
- feature_title: umss_core_functionality_v3
- project_type_code: A
- project_type_label: New project
- source_type: User input
- source_refs: projects/umms03-e7cafd12-d837-452c-b8cb-406712651ea8/umss_core_functionality_v3-1784644643/user_br_input.md; projects/umms03-e7cafd12-d837-452c-b8cb-406712651ea8/umss_core_functionality_v3-1784644643/feature_requirements.txt
- last_updated: 2026-07-21
- ready_to_ears: true

## 2. Source Request Snapshot
### 2.1 Original request summary
- short summary: Register Telegram users in UMSS, create one ACTIVE OFFCHAIN_POINTS account per Telegram identity, and expose total and last-24-hour user counts in an administration website.

### 2.2 Raw source references
- jira_link: [UNFILLED]
- related_docs: projects/umms03-e7cafd12-d837-452c-b8cb-406712651ea8/umss_core_functionality_v3-1784644643/feature_requirements.txt

### 2.3 Explicitly stated in source
- stated_goals: Prove the first core UMSS user-management flow works and show early platform adoption to stakeholders through administration user counts.
- stated_scope: Create or resolve Telegram identities, create one OFFCHAIN_POINTS account per identity, resolve authoritative account information, provide total and last-24-hour user counts, and display those counts in the administration frontend.
- stated_acceptance_criteria: New Telegram users are registered with default USER role; one ACTIVE OFFCHAIN_POINTS account is created per registered identity; existing identities are reused without overwriting stored profile fields; account resolution returns authoritative account data; user count reporting returns totals and last-24-hour counts including zero-value cases; the administration frontend displays counts and a non-sensitive error state; invalid input and duplicate registration requests do not create duplicate records.
- stated_constraints: Default USER role is assigned on Telegram identity creation; only one ACTIVE OFFCHAIN_POINTS account may exist per Telegram user and account type; stored profile fields must not be silently overwritten; automated backend tests must cover registration, duplicate prevention, account resolution, and count correctness; no market, ledger, forecasting, Telegram API, blockchain, or complex analytics behavior is introduced.
- stated_non_goals: Admin login, admin roles and permissions, banning or role changes, audit log viewing, charts and advanced analytics, DAU or retention analytics, account-status breakdowns, CSV or PDF export, Telegram Bot API integration, and TON_ONCHAIN activation are excluded.

## 3. Feature Intent
### 3.1 Business goal
- primary_business_goal: Establish the first usable UMSS onboarding and user-account flow for Telegram users.
- expected_business_value: Deliver an initial stakeholder-visible increment that proves onboarding works and provides adoption visibility through administration counts.
- problem_being_solved: UMSS needs a working initial user-registration capability and a minimal administration view that shows whether Telegram user adoption is starting.

### 3.2 Success outcome
- desired_outcome: Telegram users can be registered or recognized in UMSS, receive one ACTIVE OFFCHAIN_POINTS account, and administrators can view total users and users registered in the last 24 hours.
- success_signals: Valid new Telegram users are registered with default USER role, repeated users are reused without duplicate identities or accounts, account resolution returns authoritative account data, user counts return correct totals including zero-value cases, and the administration frontend renders counts plus an error state when loading fails.

### 3.3 Why now
- business_priority_reason: The story is intended to produce the first meaningful sprint outcome for UMSS without waiting for broader administration tooling.
- milestone_or_deadline: First sprint outcome for the initial core UMSS functionality increment.

## 4. Actors and Consumers
### 4.1 Primary actors
- actors: Teleforecaster operator; Telegram user

### 4.2 Secondary actors and systems
- secondary_actors: Administration website; downstream services that need authoritative account information

### 4.3 Affected downstream and upstream consumers
- dependent_systems: Administration frontend consuming count data; downstream services consuming authoritative account resolution data
- impacted_consumers: Teleforecaster stakeholders monitoring early adoption; operators using the administration website

## 5. Scope Definition
### 5.1 In scope
- in_scope_items: Telegram identity creation or resolution; OFFCHAIN_POINTS account creation; duplicate identity and account prevention; authoritative account resolution; total-user and last-24-hour user count reporting; administration frontend display of counts and error state.

### 5.2 Out of scope
- out_of_scope_items: Admin login; admin roles and permissions; banning or role changes; audit log viewing; charts and advanced analytics; DAU, retention, cohorts, or account-status breakdowns; CSV or PDF export; Telegram Bot API integration; TON_ONCHAIN activation; market, ledger, forecasting, blockchain, and other complex analytics behavior.

### 5.3 Open scope boundaries
- unclear_scope_points: rised=true; unresolved_item=Should total registered users and new users in the last 24 hours count every registered Telegram identity, or only Telegram users who already have an ACTIVE OFFCHAIN_POINTS account? Answer: Count every registered Telegram identity.

## 6. Functional Requirements
> Keep one item per atomic business requirement as a one-line entry.
> Use format: `- FR-N: <concise business requirement>`.
> Add as many FR entries as needed (`FR-N` is open-ended, not capped at two).

- FR-1: UMSS must create a Telegram identity with the default USER role when valid data for a new Telegram user is submitted.
- FR-2: UMSS must create exactly one ACTIVE OFFCHAIN_POINTS account for a registered Telegram identity when that account type is requested.
- FR-3: UMSS must reuse an existing Telegram identity and preserve stored profile fields when the same Telegram user is seen again.
- FR-4: UMSS must return authoritative account id, Telegram user id, account type, account status, and role when account information is requested for a registered Telegram user.
- FR-5: UMSS must return total registered Telegram users and newly registered Telegram users from the last 24 hours for administration count requests.
- FR-6: The administration frontend must display total registered users and new users from the last 24 hours after count data loads successfully.
- FR-7: The administration frontend must display a non-sensitive error message when user count data cannot be loaded.
- FR-8: UMSS must reject invalid Telegram user data without creating identity or account records.
- FR-9: UMSS must return or reuse the existing Telegram identity when the same registration is submitted more than once.

## 7. Business Rules and Decision Logic
> Use one-line entries with format: `- BR-N: <concise business rule or decision logic>`.
> Add as many BR entries as needed (`BR-N` is open-ended, not capped at two).

- BR-1: A new Telegram identity receives the default USER role at registration time.
- BR-2: Only one OFFCHAIN_POINTS account may exist for the same Telegram user and account type, and that account is ACTIVE when first created.
- BR-3: Existing Telegram identity profile fields including username, display name, and language code must not be overwritten when the user is seen again.
- BR-4: User count reporting must return zero total users and zero last-24-hour users when no Telegram identities exist.
- BR-5: User count reporting for this feature is limited to total registered Telegram users and users registered in the last 24 hours.
- BR-6: Invalid Telegram user submissions must not create identity records or account records.

## 8. Permissions and Access Constraints
- who_can_do_what: Telegram registration requests can create or resolve Telegram identities and OFFCHAIN_POINTS accounts; the administration website can request user count data; downstream services can request authoritative account information.
- ownership_rules: OFFCHAIN_POINTS accounts created in this flow are associated with the resolved Telegram identity they were requested for.
- role_constraints: Newly created Telegram identities receive the default USER role; admin roles and permissions are not part of this feature.
- auth_related_constraints: Admin login and admin permission modeling are excluded from scope for this increment.
- tenant_or_visibility_constraints: [UNFILLED]

## 9. State and Data Expectations
- entities_involved: Telegram identity; OFFCHAIN_POINTS user account; authoritative account view; administration user-count report
- data_inputs_required: Valid Telegram user data; OFFCHAIN_POINTS account request; account-information request; administration count request
- data_outputs_required: Created or reused Telegram identity; ACTIVE OFFCHAIN_POINTS account; authoritative account id, Telegram user id, account type, account status, and role; total-user and last-24-hour user-count values
- state_changes_expected: New Telegram users create identity and account records; repeated users reuse the existing identity; duplicate account requests do not create new accounts.
- persistence_expectations: Telegram identities and OFFCHAIN_POINTS accounts must be stored so later registrations and account-resolution requests can reuse authoritative records and count queries can reflect persisted registrations.
- audit_or_history_expectations: [UNFILLED]
- idempotency_or_uniqueness_expectations: Repeated registration must not create duplicate Telegram identities, and no duplicate OFFCHAIN_POINTS account may be created for the same Telegram user and account type.

## 10. Failure Cases and Edge Cases
### Negative and rejection cases
- rejection_cases: Invalid Telegram user data is rejected without creating identity or account records; a duplicate OFFCHAIN_POINTS account request does not create another account; if count data cannot be loaded, the administration frontend shows a non-sensitive error message.

### Edge cases
- edge_cases: When a Telegram user already exists, UMSS must reuse the identity and preserve stored profile fields; when no Telegram identities exist, count reporting returns zero total users and zero users registered in the last 24 hours; repeated registration requests reuse the existing identity.

### Recovery and retry expectations
- retry_or_recovery_expectations: Repeated registration submissions must safely reuse the existing Telegram identity instead of creating duplicates, and the frontend must remain able to communicate a load failure through a non-sensitive error state.

## 11. Integration and Dependency Context
- upstream_dependencies: A source of Telegram user data must submit valid registration information into UMSS.
- downstream_dependencies: Administration frontend count display; downstream consumers that need authoritative account information
- external_systems_involved: Administration website
- contract_or_api_expectations: Account resolution responses include authoritative account id, Telegram user id, account type, account status, and role; count responses include total registered Telegram users and users registered in the last 24 hours.
- event_or_async_expectations: [UNFILLED]
- prerequisite_capabilities: UMSS must be able to persist Telegram identities and OFFCHAIN_POINTS accounts, resolve existing identities during repeat submissions, and calculate total and last-24-hour registration counts for administration requests.

## 12. Non-Functional Requirements
### 12.1 Security and privacy
- security_requirements: Invalid Telegram user data must be rejected, and frontend error handling must avoid exposing sensitive details.
- privacy_requirements: [UNFILLED]

### 12.2 Performance and reliability
- performance_requirements: [UNFILLED]
- latency_throughput_expectations: [UNFILLED]
- reliability_expectations: Duplicate registration submissions and duplicate OFFCHAIN_POINTS account requests must not create duplicate persisted records.

### 12.3 Observability and supportability
- logging_expectations: [UNFILLED]
- metrics_expectations: [UNFILLED]
- tracing_expectations: [UNFILLED]
- alerting_expectations: [UNFILLED]

### 12.4 Operational and rollout
- migration_expectations: [UNFILLED]
- config_expectations: [UNFILLED]
- rollout_constraints: [UNFILLED]
- backward_compatibility_expectations: [UNFILLED]

### 12.5 Testing and quality
- required_test_levels: Automated backend tests must cover registration, duplicate prevention, account resolution, and count correctness; frontend behavior must cover empty and error states.
- special_quality_constraints: This increment must not introduce market, ledger, forecasting, Telegram API, blockchain, or complex analytics behavior.

## 13. Existing-System Context
> Especially important for project types B and C.
> Repo scan should prefer filling repository-wide business context here before any future feature-specific enrichment.
> Use one complete block of items per one repository.
> Duplicate the block below for every repository in scope.

### 13.1 Repository Block Template
- repository_id_or_class: [UNFILLED]
- repository_path: [UNFILLED]
- repository_business_domain: [UNFILLED]
- repository_primary_capability: [UNFILLED]
- repository_supported_business_flows: [UNFILLED]
- repository_supported_user_roles: [UNFILLED]
- already_implemented_behavior: [UNFILLED]
- partially_implemented_behavior: [UNFILLED]
- known_gaps: [UNFILLED]
- known_workarounds: [UNFILLED]
- legacy_constraints: [UNFILLED]
- refactor_signals: [UNFILLED]
- prerequisite_missing_parts: [UNFILLED]

## 14. Assumptions
### Confirmed assumptions
- confirmed_assumptions: This increment is limited to Telegram identities and OFFCHAIN_POINTS accounts plus administration visibility for total and last-24-hour user counts.

### Working assumptions
- working_assumptions: [UNFILLED]

### Needs validation
- assumptions_needing_validation: [UNFILLED]

## 15. Open Questions
### Critical questions
- critical_questions: rised=true; unresolved_item=Should total registered users and new users in the last 24 hours count every registered Telegram identity, or only Telegram users who already have an ACTIVE OFFCHAIN_POINTS account? Answer: Count every registered Telegram identity.

### Non-critical questions
- non_critical_questions: [UNFILLED]

## 16. Linked Artifacts
> Populated from Jira-sourced artifacts in step 3 and user-provided links during BR clarification in step 4.2. Always emitted; leave the list empty when no artifacts or links are found.
> Each entry captures: id (LAR-NNN), title, type, locator.
> Supported types: data_schema | diagram | api_spec | design_mock | document | image | pdf | other.
