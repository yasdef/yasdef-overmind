# Prerequisite Gaps - Golden Example

This example covers the same "manage-tel-usr-id" feature used in the technical-requirements golden example.
It demonstrates `present_in_repo`, `scheduled_in_slices` (including one promoted from an earlier `unmet`
finding), and a requirement with no user-reachable prerequisites.

## 1. Document Meta
- feature_id: AA-1
- source_requirements_ears: projects/umss_spg-1775826843000/manage_tel_usr_id-1775827430/requirements_ears.md
- source_technical_requirements: projects/umss_spg-1775826843000/manage_tel_usr_id-1775827430/technical_requirements.md
- source_implementation_slices: projects/umss_spg-1775826843000/manage_tel_usr_id-1775827430/implementation_slices.md
- last_updated: 2026-04-12

## 2. Prerequisite Trace

### Requirement: REQ-1
- requirement_summary: Trusted internal callers can submit Telegram user data and receive a usable identity result.
- prerequisites: see entries below

#### Prerequisite: Telegram identity endpoint
- status: present_in_repo
- evidence: POST /api/v1/telegram/identify
- slice_ref: none

#### Prerequisite: Frontend identity registration route
- status: scheduled_in_slices
- evidence: Slice slice-3 adds /telegram/register page so the flow is operator-reachable from the web client. This prerequisite was originally identified as unmet; it was promoted after adding slice-3 to implementation_slices.md.
- slice_ref: slice-3

### Requirement: REQ-7
- requirement_summary: Concurrent duplicate account-create requests keep the first success and reject later duplicates predictably.
- prerequisites: see entries below

#### Prerequisite: Account creation endpoint
- status: present_in_repo
- evidence: POST /api/v1/accounts
- slice_ref: none

#### Prerequisite: Account reconciliation scheduled job
- status: scheduled_in_slices
- evidence: Slice slice-4 adds the nightly account-reconciliation-job that detects and resolves stale duplicate accounts. No scheduled job exists in the repo today.
- slice_ref: slice-4

### Requirement: NFR-1
- requirement_summary: The core flow responds within the expected latency budget.
- prerequisites: none
