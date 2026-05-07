## ADDED Requirements

### Requirement: Checkpoint commit before step 5.1
The orchestrator SHALL create a git commit in the ASDLC workspace before running optional phase 5.1 (EARS Review), capturing all changes produced by phase 5.

#### Scenario: Workspace has uncommitted changes before 5.1
- **WHEN** phase 5 completes successfully and phase 5.1 is next
- **THEN** the orchestrator stages all workspace changes and commits with a message referencing "before step 5.1"

#### Scenario: Workspace is clean before 5.1
- **WHEN** phase 5 completes and there are no uncommitted changes in the workspace
- **THEN** the orchestrator logs that there is nothing to commit and continues without error

#### Scenario: Workspace is not a git repository before 5.1
- **WHEN** phase 5 completes and the ASDLC workspace is not a git repository
- **THEN** the orchestrator logs a warning and continues without error

### Requirement: Checkpoint commit before step 7.1
The orchestrator SHALL create a git commit in the ASDLC workspace before running optional phase 7.1 (MCP Placeholder Enrichment), capturing all changes produced by phases 6 and 7.

#### Scenario: Workspace has uncommitted changes before 7.1
- **WHEN** phase 7 completes successfully and phase 7.1 is next
- **THEN** the orchestrator stages all workspace changes and commits with a message referencing "before step 7.1"

#### Scenario: Workspace is clean before 7.1
- **WHEN** phase 7 completes and there are no uncommitted changes in the workspace
- **THEN** the orchestrator logs that there is nothing to commit and continues without error

### Requirement: Checkpoint commit before step 8.4
The orchestrator SHALL create a git commit in the ASDLC workspace before running optional phase 8.4 (Implementation Plan Semantic Review), capturing all changes produced by phases 8–8.3.

#### Scenario: Workspace has uncommitted changes before 8.4
- **WHEN** phase 8.3 completes successfully and phase 8.4 is next
- **THEN** the orchestrator stages all workspace changes and commits with a message referencing "before step 8.4"

#### Scenario: Workspace is clean before 8.4
- **WHEN** phase 8.3 completes and there are no uncommitted changes in the workspace
- **THEN** the orchestrator logs that there is nothing to commit and continues without error

### Requirement: Checkpoint commit after step 8.4
The orchestrator SHALL create a git commit in the ASDLC workspace after phase 8.4 finishes (whether it ran or was declined), preserving the final pipeline state.

#### Scenario: Phase 8.4 ran and produced changes
- **WHEN** phase 8.4 completes (run or skipped) and the workspace has uncommitted changes
- **THEN** the orchestrator stages all workspace changes and commits with a message referencing "after step 8.4"

#### Scenario: Phase 8.4 produced no changes
- **WHEN** phase 8.4 completes and there are no uncommitted changes in the workspace
- **THEN** the orchestrator logs that there is nothing to commit and continues without error

### Requirement: Checkpoint commit helper is non-fatal
The commit helper SHALL never abort the orchestrator pipeline; any git failure (missing binary, non-repo, nothing to commit) MUST result in a printed notice and return 0.

#### Scenario: git binary not found
- **WHEN** the commit helper is called and `git` is not in PATH
- **THEN** the helper prints a warning line and returns without propagating the error

#### Scenario: Commit exits non-zero for any reason
- **WHEN** `git commit` exits non-zero (e.g., nothing to commit, config missing)
- **THEN** the helper prints the exit status as a notice and returns 0
