import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";

export function createFeatureFixture(
  root: string,
  overrides: Partial<FeatureFixture> = {}
): string {
  const featureDir = path.join(root, "projects", "project-a", "feature-alpha");
  mkdirSync(featureDir, { recursive: true });
  writeFileSync(
    path.join(featureDir, "feature_br_summary.md"),
    overrides.summary ?? completeSummary()
  );
  if (overrides.userInput !== null) {
    writeFileSync(path.join(featureDir, "user_br_input.md"), overrides.userInput ?? userInput());
  }
  if (overrides.missingData !== null) {
    writeFileSync(
      path.join(featureDir, "missing_br_data.md"),
      overrides.missingData ?? emptyMissingData()
    );
  }
  return featureDir;
}

export interface FeatureFixture {
  summary: string;
  userInput: string | null;
  missingData: string | null;
}

export function userInput(): string {
  return `# User Business Input

## 1. Capture Meta
- captured_at: 2026-03-20

## 2. Epic/Story Input
- feature_id: FEAT-1
- feature_title: Invoice approvals
- epic_story_source_file: feature-story.md
- epic_or_story: |
  As a product owner I want invoice approval visibility.
- request_summary: Invoice approval visibility
- additional_business_context: [UNFILLED]
`;
}

export function jiraUserInput(): string {
  return `# User Business Input

## 1. Capture Meta
- captured_at: 2026-03-20
- jira_ticket: AUTH-241

## 2. Epic/Story Input
- feature_id: FEAT-RESET-001
- feature_title: Self-service password reset
- epic_story_source_file: jira:AUTH-241
- epic_or_story: |
  Users need to reset forgotten passwords without support tickets.
- request_summary: Self-service password reset
- additional_business_context: Existing email provider and rate limiting must be reused.
`;
}

export function userInputWithoutStoryContent(): string {
  return `# User Business Input

## 1. Capture Meta
- captured_at: 2026-03-20

## 2. Epic/Story Input
- feature_id: FEAT-1
- feature_title: Invoice approvals
- epic_story_source_file: jira:CRP-122
- epic_or_story: |
- request_summary: Invoice approval visibility
- additional_business_context: [UNFILLED]
`;
}

export function emptyMissingData(): string {
  return `# Missing Business Data

## 2. Missing Business Fields
- none

## 3. Unresolved Items Ledger (Rised)

## 6. Latest User Answers
- answers: [UNFILLED]

## 7. Loop Decision
- unresolved_after_stop: none
`;
}

export function completeSummary(): string {
  return `# Feature Business Requirements Summary

## 1. Document Meta
- source_type: User input
- last_updated: 2026-03-20

## 2. Source Request Snapshot
### 2.1 Original request summary
- short summary: Product owners need invoice approval turnaround visibility.

## 3. Feature Intent
### 3.1 Business goal
- primary_business_goal: Reduce billing approval cycle time.

## 14. Assumptions
### Needs validation
- assumptions_needing_validation: [UNFILLED]

## 5. Scope Definition
### 5.3 Open scope boundaries
- unclear_scope_points: [UNFILLED]

## 6. Functional Requirements
- FR-1: System captures required invoice approval fields from product owner.

## 7. Business Rules and Decision Logic
- BR-1: Approval requests above threshold require compliance review before release.

## 15. Open Questions
### Critical questions
- critical_questions: [UNFILLED]

### Non-critical questions
- non_critical_questions: [UNFILLED]
`;
}

export function goldenBasedValidSummary(): string {
  return `# Feature Business Requirements Summary

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

## 3. Feature Intent
### 3.1 Business goal
- primary_business_goal: Reduce account-recovery support volume.

## 5. Scope Definition
### 5.3 Open scope boundaries
- unclear_scope_points: rised=false; unresolved_item=Whether SMS fallback is required for pilot cohort.

## 6. Functional Requirements
- FR-1: Registered end user can request a password-reset link using account email without opening a support ticket.

## 7. Business Rules and Decision Logic
- BR-1: Reset token expires 15 minutes after issuance.

## 14. Assumptions
### Needs validation
- assumptions_needing_validation: rised=false; unresolved_item=Whether SMS fallback is required by compliance.

## 15. Open Questions
### Critical questions
- critical_questions: rised=false; unresolved_item=Is forced MFA re-verification required after reset?

### Non-critical questions
- non_critical_questions: [UNFILLED]
`;
}
