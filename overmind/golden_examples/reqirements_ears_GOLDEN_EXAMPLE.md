# Requirements (EARS) - Golden Example

This example is synthetic and project-agnostic.

System name: Example Task Tracking Service (“ETTS”)  
Scope: REST API + database-backed task tracking with auditable state changes.

---

## Overview
- Product/Domain: Example task tracking system
- Goals: Create, update, and query tasks with auditable state changes
- Out of scope: Billing, multi-tenant org management, time-tracking analytics reports

## Glossary
- Task: A unit of work tracked by the system
- Assignee: The user responsible for a task

## Actors
- User: End user interacting with the system
- Admin: Operator managing configuration

## Assumptions
- Users authenticate before accessing protected endpoints.
- Time is recorded in UTC.

---

## Requirements

This example intentionally keeps one primary obligation focus per block
(happy path, rejection path, permission/access, state effect, integration effect, NFR).

### Requirement 1 — Create tasks
**User Story:** As a user, I want to create a task with a title and due date, so that I can track work I need to complete.

**Acceptance Criteria (EARS):**
- WHEN a user submits a create-task request, THE Example Task Tracking Service SHALL create a new task with the provided title and due date.

**Verification:** API test for `POST /tasks` success responses and persisted task fields.

**Linked Artifacts:**
- LAR-001

---

### Requirement 2 — Reject invalid create-task requests
**User Story:** As a client developer, I want deterministic validation failures, so that I can handle invalid create requests predictably.

The specific missing-title case refines the broad invalid-data obligation; both stay because each is independently testable.

**Acceptance Criteria (EARS):**
- IF a create-task request contains invalid task data, THEN THE Example Task Tracking Service SHALL reject the request with a validation error.
- IF a create-task request is missing a title, THEN THE Example Task Tracking Service SHALL reject the request with a validation error identifying the missing title.

**Verification:** Backend automated API tests for `POST /tasks` covering invalid task data generally and the missing-title case specifically.

---

### Requirement 3 — Enforce create permissions
**User Story:** As a security operator, I want task creation to require proper scope, so that unauthorized users cannot create tasks.

**Acceptance Criteria (EARS):**
- WHEN a create-task request is submitted by a caller with `tasks:write` scope, THE Example Task Tracking Service SHALL process the request.
- IF the caller lacks `tasks:write` scope, THEN THE Example Task Tracking Service SHALL reject the create-task request with HTTP 403.

**Verification:** API authorization tests for `POST /tasks` with and without `tasks:write` scope.

---

### Requirement 4 — Persist immutable creation metadata
**User Story:** As an auditor, I want immutable creation metadata for each task, so that lifecycle state can be reconstructed reliably.

**Acceptance Criteria (EARS):**
- WHEN a task is created, THE Example Task Tracking Service SHALL persist an immutable creation timestamp for that task.

**Verification:** Database assertion test that creation timestamps are stored and immutable.

---

### Requirement 5 — Publish reminder integration events
**User Story:** As a user, I want reminder integrations to trigger reliably, so that I receive reminder notifications before due dates.

**Acceptance Criteria (EARS):**
- WHEN a task with reminders enabled is due within 24 hours, THE Example Task Tracking Service SHALL enqueue a reminder notification event for the task assignee.

**Verification:** Integration test that enables reminders and asserts an event is enqueued for eligible tasks.

**Linked Artifacts:**
- LAR-002

---

### Requirement 6 — Prevent edits after completion
**User Story:** As a user, I want completed tasks to be immutable, so that “done” work is not accidentally changed.

**Acceptance Criteria (EARS):**
- WHILE a task is in state `DONE`, THE Example Task Tracking Service SHALL reject requests that modify the task title.
- WHEN a user attempts to modify a `DONE` task, THE Example Task Tracking Service SHALL return a deterministic error code indicating the task is not editable.

**Verification:** API tests for `PATCH /tasks/{id}` against tasks in `DONE`.

---

### Requirement 7 — Delete behavior for missing tasks
**User Story:** As a client developer, I want consistent not-found responses, so that I can handle deletes predictably.

**Acceptance Criteria (EARS):**
- IF a user attempts to delete a task that does not exist, THEN THE Example Task Tracking Service SHALL return HTTP 404.

**Verification:** API test for `DELETE /tasks/{id}` with a non-existent id.

---

## Non-Functional Requirements

### NFR 1 — Query latency
**User Story:** As a user, I want task queries to be fast, so that the UI feels responsive.

**Acceptance Criteria (EARS):**
- THE Example Task Tracking Service SHALL return `GET /tasks` responses within 300 ms at p95 under the defined test load.

**Verification:** Load test report and CI performance gate for p95 latency.

---

## Linked Artifacts

- id: LAR-001
  title: Task Entity Data Schema
  type: data_schema
  locator: https://confluence.example.com/display/ETTS/task-entity-schema
- id: LAR-002
  title: Reminder Event Contract
  type: api_spec
  locator: https://confluence.example.com/display/ETTS/reminder-event-contract

---

## END OF EARS SPECIFICATION (GOLDEN EXAMPLE)
