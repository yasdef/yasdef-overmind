# Requirements (EARS)

## Requirements

### Requirement 1 - Create task
**User Story:** As an operator, I want to create a task, so that work can be tracked.

**Acceptance Criteria (EARS):**
- WHEN a create-task request is submitted, THE System SHALL create a task record.

**Verification:** API test for create-task success.

### NFR 1 - Create task latency
**User Story:** As an operator, I want task creation to stay responsive, so that the queue keeps moving.

**Acceptance Criteria (EARS):**
- WHEN a create-task request is submitted, THE System SHALL respond within one second.

**Verification:** Performance test for create-task latency.
