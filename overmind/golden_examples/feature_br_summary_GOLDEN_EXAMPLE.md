# Feature Business Requirements Summary

## 1. Document Meta
- feature_id: FEAT-RESET-001
- feature_title: Self-service password reset
- project_type_code: B
- project_type_label: Existing project with partial context
- source_type: User input
- source_refs: JIRA-AUTH-241
- last_updated: 2026-03-18
- ready_to_ears: false

## 2. Source Request Snapshot
### 2.1 Original request summary
- short summary: Add secure self-service password reset for existing users.

### 2.2 Raw source references
- jira_link: JIRA-AUTH-241
- related_docs: auth-security-guidelines-v3.md, onboarding-flow-notes.md

### 2.3 Explicitly stated in source
- stated_goals: Users can reset forgotten passwords without support tickets.
- stated_scope: Request reset, validate token, set new password, notify user.
- stated_acceptance_criteria: Expiring token, secure validation, audit trail.
- stated_constraints: Must use existing email provider and rate-limit controls; introduces no new identity provider and no SMS delivery channel.
- stated_non_goals: No identity-provider migration in this feature.

## 3. Feature Intent
### 3.1 Business goal
- primary_business_goal: Reduce account-recovery support volume.
- expected_business_value: Faster account access and lower support cost.
- problem_being_solved: Users currently depend on manual support reset flow.

### 3.2 Success outcome
- desired_outcome: End users complete reset without agent intervention.
- success_signals: 60 percent drop in password-reset tickets within 30 days.

### 3.3 Why now
- business_priority_reason: Account-lock complaints increased after MFA rollout.
- milestone_or_deadline: Needed before Q2 onboarding campaign.

## 4. Actors and Consumers
### 4.1 Primary actors
- actors: Registered end user, support operator (observer role).

### 4.2 Secondary actors and systems
- secondary_actors: Email provider, auth API, audit pipeline.

### 4.3 Affected downstream and upstream consumers
- dependent_systems: Login flow, notification service.
- impacted_consumers: Customer support dashboard, security monitoring.

## 5. Scope Definition
### 5.1 In scope
- in_scope_items: Reset request endpoint, token verification, password update.

### 5.2 Out of scope
- out_of_scope_items: Account signup, MFA enrollment, SSO user management, SMS delivery channel.

### 5.3 Open scope boundaries
- unclear_scope_points: rised=false; unresolved_item=Whether SMS fallback is required for pilot cohort.

## 6. Functional Requirements
> Keep one item per atomic business requirement as a one-line entry.
> Use format `- FR-N: ...` and add as many items as required by scope.

- FR-1: Registered end user can request a password-reset link using account email without opening a support ticket.
- FR-2: System sends a one-time reset link after request validation and applicable rate-limit checks pass.
- FR-3: Registered end user can set a new password when submitting a valid, unexpired, unused reset token.

## 7. Business Rules and Decision Logic
- BR-1: Reset token expires 15 minutes after issuance.
- BR-2: Successful password reset invalidates all active sessions and requires re-authentication.
- BR-3: Reset requests for the same account are rate-limited to prevent abuse and token spam.

## 8. Permissions and Access Constraints
- who_can_do_what: Any registered user can request reset for own account.
- ownership_rules: Support can view reset events but cannot set passwords.
- role_constraints: Admin endpoints are excluded from this flow.
- auth_related_constraints: Token must be single-use and signed.
- tenant_or_visibility_constraints: Tenant boundaries must be preserved.

## 9. State and Data Expectations
- entities_involved: UserAccount, PasswordResetToken, AuditEvent.
- data_inputs_required: Email, token, new password.
- data_outputs_required: Request acknowledgment, reset success/failure result.
- state_changes_expected: Token issued/consumed, password hash replaced.
- persistence_expectations: Token and audit records persisted.
- audit_or_history_expectations: Request and completion events stored with actor context.
- idempotency_or_uniqueness_expectations: Token value unique per request.

## 10. Failure Cases and Edge Cases
### Negative and rejection cases
- rejection_cases: Unknown email, expired token, reused token, weak password.

### Edge cases
- edge_cases: Multiple reset requests issued in short window.

### Recovery and retry expectations
- retry_or_recovery_expectations: User can request new token after cooldown period.

## 11. Integration and Dependency Context
- upstream_dependencies: Existing auth user store.
- downstream_dependencies: Email delivery service and audit stream.
- external_systems_involved: SMTP provider.
- contract_or_api_expectations: New reset endpoints in auth API contract.
- event_or_async_expectations: Audit event emitted asynchronously.
- prerequisite_capabilities: Rate limiting and email-template rendering.

## 12. Non-Functional Requirements
### 12.1 Security and privacy
- security_requirements: Signed token, hash-at-rest, brute-force throttling.
- privacy_requirements: Never reveal whether email exists in system responses.

### 12.2 Performance and reliability
- performance_requirements: Reset request endpoint p95 under 300ms.
- latency_throughput_expectations: Support peak 100 reset requests per minute.
- reliability_expectations: 99.9 percent availability for reset endpoints.

### 12.3 Observability and supportability
- logging_expectations: Structured security logs for request and completion.
- metrics_expectations: Counters for requests, failures, expired-token attempts.
- tracing_expectations: End-to-end trace across auth and notification services.
- alerting_expectations: Alert on abnormal reset-failure spike.

### 12.4 Operational and rollout
- migration_expectations: None for existing password hashes.
- config_expectations: Token TTL and cooldown configured per environment; no new identity-provider or SMS configuration is introduced.
- rollout_constraints: Enable behind feature flag for one week.
- backward_compatibility_expectations: Existing login API behavior unchanged.

### 12.5 Testing and quality
- required_test_levels: Unit, integration, API contract, security tests.
- special_quality_constraints: Include token replay and abuse scenarios.

## 13. Existing-System Context
> Especially important for project types B and C.

### 13.1 Repository: backend
- repository_id_or_class: backend
- repository_path: /repos/identity-platform-backend
- repository_business_domain: Identity and access management.
- repository_primary_capability: Authentication APIs, account lifecycle, and password recovery orchestration.
- repository_supported_business_flows: Sign-in, token refresh, password reset request, reset confirmation, and support-assisted account unlock.
- repository_supported_user_roles: Registered end user, support operator, security/admin operator.
- already_implemented_behavior: Manual support reset endpoint and account lockout policy are implemented.
- partially_implemented_behavior: Reset-token invalidation is implemented but audit metadata is incomplete.
- known_gaps: No self-service UI handoff contract for reset completion.
- known_workarounds: Support agents complete resets via internal tools.
- legacy_constraints: Legacy session store has delayed revocation propagation.
- refactor_signals: Reset orchestration and notification side effects are tightly coupled.
- prerequisite_missing_parts: Dedicated recovery audit table is not yet implemented.

### 13.2 Repository: frontend
- repository_id_or_class: frontend
- repository_path: /repos/identity-platform-frontend
- repository_business_domain: End-user identity access experience.
- repository_primary_capability: User-facing authentication journeys and account-recovery entry points.
- repository_supported_business_flows: Login, forgot-password initiation, reset-link confirmation, and session-expiry recovery.
- repository_supported_user_roles: Registered end user and helpdesk-support user.
- already_implemented_behavior: Login and session-expiry recovery screens are implemented.
- partially_implemented_behavior: Forgot-password screen exists but success/error states are inconsistent.
- known_gaps: No completed reset-confirmation UX for first-time link visits.
- known_workarounds: Support shares manual recovery steps outside the app.
- legacy_constraints: Shared form-state utility limits per-flow validation rules.
- refactor_signals: Auth-routing guards and reset flow state handling need consolidation.
- prerequisite_missing_parts: Unified reset status component and analytics event mapping are missing.

## 14. Assumptions
### Confirmed assumptions
- confirmed_assumptions: Existing email provider SLA is sufficient.

### Working assumptions
- working_assumptions: Support dashboard only needs read-only reset status.

### Needs validation
- assumptions_needing_validation: rised=false; unresolved_item=Whether SMS fallback is required by compliance.

## 15. Open Questions
### Critical questions
- critical_questions: rised=false; unresolved_item=Is forced MFA re-verification required after reset?

### Non-critical questions
- non_critical_questions: rised=false; unresolved_item=Should reset success email include device metadata?

## 16. Linked Artifacts

- id: LAR-001
  title: Password Reset Flow Diagram
  type: diagram
  locator: https://confluence.example.com/display/AUTH/password-reset-flow
- id: LAR-002
  title: Auth API Contract v3 — Reset Endpoints
  type: api_spec
  locator: https://confluence.example.com/display/AUTH/api-contract-v3
