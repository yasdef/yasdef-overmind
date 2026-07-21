# User Business Input

## 1. Capture Meta
- captured_at: 2026-07-21

## 2. Epic/Story Input
- feature_id: UMS-001v3
- feature_title: umss_core_functionality_v3
- epic_story_source_file: projects/umms03-e7cafd12-d837-452c-b8cb-406712651ea8/umss_core_functionality_v3-1784644643/feature_requirements.txt
- epic_or_story: |
  Telegram User Registration and Basic User Count Visibility
  
    As a Teleforecaster operator,
    I want Telegram users to be registered in UMSS and basic user counts to be visible in an administration website,
    so that we can prove the first core user-management flow works and show early platform adoption to stakeholders.
  
    Business Value
  
    This story establishes the first usable UMSS business capability: Telegram users can be recognized, registered, and assigned an active account. It also gives the team and
    stakeholders a simple administration view showing total registered users and users registered in the last 24 hours.
  
    This creates a meaningful first sprint outcome: the platform can onboard users and show basic growth visibility without waiting for complex admin tooling.
  
    Scope
  
    The system must support:
    - Creating or resolving a Telegram identity.
    - Creating an OFFCHAIN_POINTS user account for that identity.
    - Preventing duplicate accounts for the same Telegram user and account type.
    - Resolving the authoritative account information for downstream services.
    - Providing simple user count data for an administration website.
    - Displaying total users and new users from the last 24 hours in the administration frontend.
  
    Acceptance Criteria
  
    1. New Telegram User Registration
  
    Given a Telegram user who does not yet exist in UMSS,
    when valid Telegram user data is submitted,
    then UMSS creates a Telegram identity for that user,
    and the identity receives the default USER role.
  
    2. Initial OFFCHAIN_POINTS Account Creation
  
    Given a registered Telegram identity,
    when an OFFCHAIN_POINTS account is requested for that identity,
    then UMSS creates exactly one ACTIVE OFFCHAIN_POINTS user account.
  
    3. Existing Telegram User Recognition
  
    Given a Telegram user who already exists in UMSS,
    when the user is seen again,
    then UMSS reuses the existing Telegram identity,
    and does not overwrite stored profile fields such as username, display name, or language code.
  
    4. Duplicate Account Protection
  
    Given a Telegram user already has an OFFCHAIN_POINTS account,
    when another OFFCHAIN_POINTS account creation is requested for the same Telegram user,
    then UMSS does not create a duplicate account.
  
    5. Account Resolution
  
    Given a registered Telegram user with an OFFCHAIN_POINTS account,
    when account information is requested,
    then UMSS returns the authoritative account id, Telegram user id, account type, account status, and role.
  
    6. Basic User Count Report
  
    Given Telegram identities exist in UMSS,
    when the administration website requests basic user counts,
    then the system returns:
    - total registered Telegram users
    - new Telegram users registered in the last 24 hours
  
    7. Empty User Count Report
  
    Given no Telegram identities exist yet,
    when the administration website requests basic user counts,
    then the system returns zero for total users and zero for new users in the last 24 hours.
  
    8. Administration Frontend Display
  
    Given the administration website is opened,
    when the user count data is loaded successfully,
    then the website displays total registered users and new users from the last 24 hours.
  
    9. Administration Frontend Error State
  
    Given the user count data cannot be loaded,
    when the administration website receives an error,
    then it shows a simple non-sensitive error message.
  
    10. Invalid Telegram User Rejection
  
    Given invalid Telegram user data,
    when registration is requested,
    then UMSS rejects the request and does not create identity or account records.
  
    11. Duplicate Registration Safety
  
    Given the same Telegram user registration is submitted more than once,
    when UMSS processes the repeated request,
    then it returns or reuses the existing identity instead of creating a duplicate Telegram identity.
  
    Definition of Done
  
    - A Telegram user can be registered in UMSS.
    - A registered Telegram user can receive one ACTIVE OFFCHAIN_POINTS account.
    - Duplicate OFFCHAIN_POINTS accounts are prevented.
    - Existing Telegram identity profile fields are not silently overwritten.
    - Account information can be resolved for a registered user.
    - A basic user count endpoint provides total users and new users from the last 24 hours.
    - A new administration frontend app displays those two values.
    - Empty and error states are handled in the frontend.
    - Automated backend tests cover registration, duplicate prevention, account resolution, and count correctness.
    - No market, ledger, forecasting, Telegram API, blockchain, or complex analytics behavior is introduced.
  
    Out of Scope
  
    - Admin login.
    - Admin roles and permissions.
    - Banning or role changes.
    - Audit log viewing.
    - Charts and advanced analytics.
    - DAU, retention, cohorts, or account status breakdowns.
    - CSV/PDF export.
    - Telegram Bot API integration.
    - TON_ONCHAIN activation.
  
- request_summary: umss_core_functionality_v3
- additional_business_context: [UNFILLED]
