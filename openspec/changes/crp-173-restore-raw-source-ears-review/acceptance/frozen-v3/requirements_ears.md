# Requirements (EARS)

System name: User Management Service System ("UMSS")  
Scope: Telegram identity onboarding, OFFCHAIN_POINTS account creation and resolution, and administration user-count reporting for this increment. Excludes admin authentication and authorization, advanced analytics, Telegram Bot API integration, TON_ONCHAIN activation, and market, ledger, forecasting, or blockchain behavior.

---

## Overview
- Product/Domain: UMSS Telegram user onboarding and administration visibility
- Goals: Register or resolve Telegram users, create one ACTIVE OFFCHAIN_POINTS account per Telegram identity, return authoritative account data, and show total and last-24-hour user counts to administrators
- Out of scope: Admin login; admin roles and permissions; banning or role changes; audit log viewing; charts and advanced analytics; DAU, retention, cohorts, or account-status breakdowns; CSV or PDF export; Telegram Bot API integration; TON_ONCHAIN activation; market, ledger, forecasting, blockchain, and other complex analytics behavior

## Glossary
- Telegram identity: The persisted UMSS record for a Telegram user
- OFFCHAIN_POINTS account: The UMSS account type created for a Telegram identity in this increment
- Authoritative account view: The response that returns canonical account and role data for a registered Telegram user
- Administration user-count report: The total registered Telegram user count and the count of users registered in the last 24 hours

## Actors
- Telegram user: The person whose Telegram data is submitted to UMSS
- Teleforecaster operator: The operator overseeing the onboarding flow
- Administration website: The frontend that requests and displays user counts
- Downstream service: A consumer that requests authoritative account information for a registered Telegram user

## Assumptions
- Total registered users and users registered in the last 24 hours are counted across every registered Telegram identity.
- This increment is limited to Telegram identities, OFFCHAIN_POINTS accounts, and administration visibility for total and last-24-hour user counts.

---

## Requirements

### Requirement 1 — Register new Telegram identities
**User Story:** As a Teleforecaster operator, I want valid new Telegram users to be registered in UMSS, so that the first UMSS onboarding flow creates usable user identities.

**Acceptance Criteria (EARS):**
- WHEN valid data for a new Telegram user is submitted, THE User Management Service System SHALL create a Telegram identity for that user.
- WHEN a new Telegram identity is created, THE User Management Service System SHALL assign the default `USER` role to that identity.

**Verification:** Automated backend tests covering successful Telegram user registration and default-role assignment.

---

### Requirement 2 — Create one ACTIVE OFFCHAIN_POINTS account
**User Story:** As a Teleforecaster operator, I want each registered Telegram identity to receive one usable OFFCHAIN_POINTS account, so that the onboarding flow produces an active UMSS account.

**Acceptance Criteria (EARS):**
- WHEN an `OFFCHAIN_POINTS` account is requested for a registered Telegram identity, THE User Management Service System SHALL create exactly one account of that type for the identity.
- WHEN the User Management Service System creates an `OFFCHAIN_POINTS` account in this flow, THE User Management Service System SHALL mark that account as `ACTIVE`.
- IF an `OFFCHAIN_POINTS` account already exists for the same Telegram user and account type, THEN THE User Management Service System SHALL not create another account.

**Verification:** Automated backend tests covering initial OFFCHAIN_POINTS account creation, ACTIVE status assignment, and duplicate-account prevention.

---

### Requirement 3 — Reuse existing identities on repeat registration
**User Story:** As a Teleforecaster operator, I want repeat submissions for the same Telegram user to reuse stored identity data, so that UMSS remains idempotent and preserves prior profile information.

**Acceptance Criteria (EARS):**
- WHEN the same Telegram user is seen again, THE User Management Service System SHALL reuse the existing Telegram identity.
- WHEN the same registration is submitted more than once, THE User Management Service System SHALL return or reuse the existing Telegram identity instead of creating a duplicate identity.
- WHILE reusing an existing Telegram identity, THE User Management Service System SHALL preserve stored profile fields including username, display name, and language code.

**Verification:** Automated backend tests covering repeat registration reuse, duplicate-identity prevention, and preservation of stored profile fields.

---

### Requirement 4 — Return authoritative account information
**User Story:** As a downstream service, I want authoritative account information for a registered Telegram user, so that dependent flows consume canonical UMSS account data.

**Acceptance Criteria (EARS):**
- WHEN account information is requested for a registered Telegram user, THE User Management Service System SHALL return the authoritative account id, Telegram user id, account type, account status, and role.

**Verification:** Automated backend tests covering authoritative account-resolution responses and required response fields.

---

### Requirement 5 — Report administration user counts
**User Story:** As an administration website, I want UMSS to return current registration counts, so that administrators can monitor early Telegram user adoption.

**Acceptance Criteria (EARS):**
- WHEN the administration website requests user counts, THE User Management Service System SHALL return the total registered Telegram users and the Telegram users registered in the last 24 hours.
- WHEN the User Management Service System calculates administration user counts for this feature, THE User Management Service System SHALL count every registered Telegram identity.
- IF no Telegram identities exist, THEN THE User Management Service System SHALL return zero total users and zero users registered in the last 24 hours.

**Verification:** Automated backend tests covering total-user counts, last-24-hour counts, the all-registered-identities counting rule, and zero-value responses.

---

### Requirement 6 — Display administration user counts
**User Story:** As a Teleforecaster operator, I want the administration website to show current user counts, so that I can see early platform adoption without querying backend systems directly.

**Acceptance Criteria (EARS):**
- WHEN user count data loads successfully, THE User Management Service System SHALL display total registered users and new users from the last 24 hours in the administration website.
- WHEN user count data loads successfully with zero values, THE User Management Service System SHALL display zero total registered users and zero new users from the last 24 hours in the administration website.

**Verification:** Frontend automated tests covering successful count rendering and zero-value display behavior.

---

### Requirement 7 — Show a count-loading error state
**User Story:** As a Teleforecaster operator, I want the administration website to communicate count-loading failures clearly, so that I know the data is unavailable without exposing backend details.

**Acceptance Criteria (EARS):**
- IF user count data cannot be loaded, THEN THE User Management Service System SHALL display an administration website error state for the failed load.

**Verification:** Frontend automated tests covering the administration count-loading error state.

---

### Requirement 8 — Reject invalid Telegram user data
**User Story:** As a client developer, I want invalid Telegram registrations to fail deterministically, so that invalid data does not create unusable records in UMSS.

**Acceptance Criteria (EARS):**
- IF submitted Telegram user data is invalid, THEN THE User Management Service System SHALL reject the registration without creating a Telegram identity.
- IF submitted Telegram user data is invalid and an `OFFCHAIN_POINTS` account was requested, THEN THE User Management Service System SHALL reject the request without creating an account.

**Verification:** Automated backend validation tests covering invalid Telegram user submissions and confirming that identity and account records are not created.

---

### Requirement 9 — Persist identities and account ownership
**User Story:** As a downstream service, I want UMSS to persist onboarding results reliably, so that later registrations, account-resolution requests, and count queries use authoritative stored records.

**Acceptance Criteria (EARS):**
- WHEN the User Management Service System creates a Telegram identity, THE User Management Service System SHALL persist that identity for later registration reuse and count queries.
- WHEN the User Management Service System creates an `OFFCHAIN_POINTS` account in this flow, THE User Management Service System SHALL persist the account and associate it with the resolved Telegram identity.

**Verification:** Automated backend persistence tests covering stored Telegram identities, stored OFFCHAIN_POINTS accounts, and account ownership association.

---

## Non-Functional Requirements

### NFR 1 — Protect sensitive error details
**User Story:** As a Teleforecaster operator, I want administration errors to avoid exposing sensitive details, so that failures do not leak internal information.

**Acceptance Criteria (EARS):**
- IF user count data cannot be loaded, THEN THE User Management Service System SHALL display a non-sensitive error message in the administration website.

**Verification:** Frontend automated tests confirming the count-loading error message is shown without sensitive backend details.

---
