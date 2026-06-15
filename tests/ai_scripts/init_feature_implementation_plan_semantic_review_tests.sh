#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/feature_implementation_plan_semantic_review.sh"
HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_implementation_plan_semantic_review_quality.sh"
PLAN_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_implementation_plan_quality.sh"
RULE_SRC="$SOURCE_ROOT/overmind/rules/implementation_plan_semantic_review_rule.md"
TEMPLATE_SRC="$SOURCE_ROOT/overmind/templates/implementation_plan_semantic_review_TEMPLATE.md"
GOLDEN_EXAMPLE_SRC="$SOURCE_ROOT/overmind/golden_examples/implementation_plan_semantic_review_GOLDEN_EXAMPLE.md"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "Assertion failed: expected output to contain: $needle" >&2
    echo "Actual output:" >&2
    echo "$haystack" >&2
    exit 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "Assertion failed: expected output to NOT contain: $needle" >&2
    echo "Actual output:" >&2
    echo "$haystack" >&2
    exit 1
  fi
}

assert_equal() {
  local expected="$1"
  local actual="$2"
  if [[ "$expected" != "$actual" ]]; then
    echo "Assertion failed: expected '$expected', got '$actual'" >&2
    exit 1
  fi
}

assert_nonzero_status() {
  local status="$1"
  if [[ "$status" -eq 0 ]]; then
    echo "Assertion failed: expected non-zero status" >&2
    exit 1
  fi
}

assert_file_exists() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Assertion failed: expected file to exist: $path" >&2
    exit 1
  fi
}

setup_workspace_layout() {
  local repo_dir="$1"
  mkdir -p \
    "$repo_dir/asdlc/.commands" \
    "$repo_dir/asdlc/.helper" \
    "$repo_dir/asdlc/.rules" \
    "$repo_dir/asdlc/.templates" \
    "$repo_dir/asdlc/.golden_examples" \
    "$repo_dir/asdlc/.setup" \
    "$repo_dir/asdlc/projects/p1/feature-a"

  cp "$SCRIPT_SRC" "$repo_dir/asdlc/.commands/feature_implementation_plan_semantic_review.sh"
  cp "$HELPER_SRC" "$repo_dir/asdlc/.helper/check_implementation_plan_semantic_review_quality.sh"
  cp "$PLAN_HELPER_SRC" "$repo_dir/asdlc/.helper/check_implementation_plan_quality.sh"
  cp "$RULE_SRC" "$repo_dir/asdlc/.rules/implementation_plan_semantic_review_rule.md"
  cp "$TEMPLATE_SRC" "$repo_dir/asdlc/.templates/implementation_plan_semantic_review_TEMPLATE.md"
  cp "$GOLDEN_EXAMPLE_SRC" "$repo_dir/asdlc/.golden_examples/implementation_plan_semantic_review_GOLDEN_EXAMPLE.md"
  chmod +x "$repo_dir/asdlc/.commands/feature_implementation_plan_semantic_review.sh"
  chmod +x "$repo_dir/asdlc/.helper/check_implementation_plan_semantic_review_quality.sh"
  chmod +x "$repo_dir/asdlc/.helper/check_implementation_plan_quality.sh"

  cat >"$repo_dir/asdlc/asdlc_metadata.yaml" <<'OUT'
meta:
  description: "test"
projects:
OUT

  mkdir -p "$repo_dir/asdlc/projects/p1"
  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<'OUT'
meta_info:
  project_id: "p1"
  project_type_code: "B"
  project_type_label: "Existing project with partial context"
  project_classes:
    - backend
    - frontend
steps:
  - step_number: "0"
    step_name: "placeholder"
OUT
}

setup_models_file() {
  local repo_dir="$1"
  cat >"$repo_dir/asdlc/.setup/models.md" <<'OUT'
# Phase | Command | Model | Extra Arg 1 (optional) | Extra Arg 2 (optional) | ...
implementation_plan_semantic_review | codex | gpt-5.4 | --config | model_reasoning_effort='high'
OUT
}

seed_feature_sources() {
  local repo_dir="$1"
  local feature_path="${2:-projects/p1/feature-a}"
  mkdir -p "$repo_dir/asdlc/$feature_path"

  cat >"$repo_dir/asdlc/$feature_path/implementation_plan.md" <<'OUT'
# Implementation Plan

### Step 1.1 Backend status guard foundation [REQ-1]
#### Repo: backend
#### Depends on: none
#### Evidence: gap/TECH_REQ-1, comp/backend-status-guard
- [ ] Plan and discuss the step
- [ ] Add ACTIVE status guard in backend access middleware
- [ ] Add backend tests for ACTIVE guard behavior
- [ ] Review step implementation

### Step 1.2 Client workspace alignment [REQ-1] [REQ-2]
#### Repo: frontend
#### Depends on: 1.1
#### Evidence: gap/TECH_REQ-2, comp/frontend-workspace-client
- [ ] Plan and discuss the step
- [ ] Update client state for ACTIVE guard responses
- [ ] Add client tests for ACTIVE guard handling
- [ ] Review step implementation
OUT

  cat >"$repo_dir/asdlc/$feature_path/requirements_ears.md" <<'OUT'
# Requirements (EARS)

## Requirements

### Requirement 1 - ACTIVE guard
**Acceptance Criteria (EARS):**
- WHEN a workspace request is executed for a non-ACTIVE admin, THE System SHALL deny access.

### Requirement 2 - Client feedback
**Acceptance Criteria (EARS):**
- WHEN access is denied for non-ACTIVE admin state, THE System SHALL show a deterministic guard message.
OUT

  cat >"$repo_dir/asdlc/$feature_path/technical_requirements.md" <<'OUT'
# Technical Requirements

## 1. Document Meta
- feature_id: FEAT-SEM-001
- feature_title: workspace-active-guard
- project_type_code: B

## 4. Requirement Coverage and Gaps
### Requirement: REQ-1
- gap_to_close: add backend ACTIVE guard checks and tests

### Requirement: REQ-2
- gap_to_close: add frontend ACTIVE-denial handling and tests

## 5. Impacted Components
### Component: backend status guard
- repo: backend
- gap_to_close: add ACTIVE status middleware

### Component: frontend workspace client
- repo: frontend
- gap_to_close: add ACTIVE-denial state handling
OUT

  cat >"$repo_dir/asdlc/$feature_path/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## Requirement: REQ-1

### Prerequisite: backend-status-guard middleware
- status: present_in_repo
- evidence: src/middleware/status_guard.rb
- slice_ref:

### Prerequisite: frontend-workspace-client
- status: present_in_repo
- evidence: src/components/WorkspaceClient.tsx
- slice_ref:

## Requirement: REQ-2

### Prerequisite: denial message component
- status: present_in_repo
- evidence: src/components/DenialMessage.tsx
- slice_ref:
OUT

  cat >"$repo_dir/asdlc/$feature_path/project_surface_struct_resp_map_backend.md" <<'OUT'
# Backend Surface Map

## Section 4
- user_reachable_surface: POST /api/admin/workspace
OUT

  cat >"$repo_dir/asdlc/$feature_path/project_surface_struct_resp_map_frontend.md" <<'OUT'
# Frontend Surface Map

## Section 4
- user_reachable_surface: /admin/home
OUT
}

seed_surface_maps() {
  local repo_dir="$1"
  local feature_path="${2:-projects/p1/feature-a}"

  cat >"$repo_dir/asdlc/$feature_path/project_surface_struct_resp_map_backend.md" <<'OUT'
# Backend Surface Map

## Section 4
- user_reachable_surface: POST /api/admin/workspace
OUT

  cat >"$repo_dir/asdlc/$feature_path/project_surface_struct_resp_map_frontend.md" <<'OUT'
# Frontend Surface Map

## Section 4
- user_reachable_surface: /admin/home
OUT
}

setup_codex_stub() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/bin"
  cat >"$repo_dir/bin/codex" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:?TEST_CAPTURE_DIR must be set}"
target_plan="${TARGET_PLAN_FILE:-projects/p1/feature-a/implementation_plan.md}"
target_review="${TARGET_REVIEW_FILE:-projects/p1/feature-a/implementation_plan_semantic_review.md}"
review_variant="${STUB_REVIEW_VARIANT:-missing-inbound}"
feature_root="$(dirname "$target_plan")"

printf '%s\n' "$@" >"$capture_dir/codex_args.txt"
printf '%s' "${!#}" >"$capture_dir/codex_prompt.txt"

mkdir -p "$(dirname "$target_plan")" "$(dirname "$target_review")"

cat >"$target_plan" <<'PLAN'
# Implementation Plan

### Step 1.1 Backend status guard foundation [REQ-1]
#### Repo: backend
#### Depends on: none
#### Evidence: gap/TECH_REQ-1, comp/backend-status-guard
- [ ] Plan and discuss the step
- [ ] Add ACTIVE status guard in backend access middleware
- [ ] Add backend tests for ACTIVE guard behavior
- [ ] Review step implementation

### Step 1.2 Client ACTIVE-state alignment [REQ-1]
#### Repo: frontend
#### Depends on: 1.1
#### Evidence: gap/TECH_REQ-2, comp/frontend-workspace-client
- [ ] Plan and discuss the step
- [ ] Update client state transitions for ACTIVE guard responses
- [ ] Add client tests for ACTIVE guard state handling
- [ ] Review step implementation

### Step 1.3 Client denial messaging polish [REQ-2]
#### Repo: frontend
#### Depends on: 1.2
#### Evidence: gap/TECH_REQ-2, comp/frontend-workspace-client
- [ ] Plan and discuss the step
- [ ] Update denial message rendering and copy hook
- [ ] Add UI tests for denial messaging behavior
- [ ] Review step implementation
PLAN

case "$review_variant" in
  surface-map-driven)
    if grep -R "(in-flight " "$feature_root"/project_surface_struct_resp_map_*.md >/dev/null 2>&1; then
      cat >"$target_review" <<'REVIEW'
# Implementation Plan Semantic Review

## 1. Document Meta
- feature_id: FEAT-SEM-001
- feature_title: workspace-active-guard
- source_implementation_plan: projects/p1/feature-a/implementation_plan.md
- source_project_definition: projects/p1/init_progress_definition.yaml
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_technical_requirements: projects/p1/feature-a/technical_requirements.md
- review_status: complete
- last_updated: 2026-04-11

## 2. Review Guidance
- completion_rule: Set review_status complete only when every finding is terminal (applied, rejected, postponed) or no_findings true.
- user_question_format: Which finding numbers should I apply to implementation_plan.md? (examples: 1,3 | all | none | postpone 2 | reject 4)
- allowed_finding_types: step_scope_overlap, technical_gap_mix, dependency_ordering, requirement_grouping, delivered_surface_consumption_unclear, repo_scaffold_readiness_unclear
- allowed_severity: High, Medium, Low
- allowed_states: added, applied, rejected, postponed

## 3. Findings Ledger
### Finding 1 - In-flight sibling owns workspace route surface
- severity: Medium
- finding_type: step_scope_overlap
- state: postponed
- target_steps: Step 1.2
- related_requirements: REQ-1
- related_evidence: project_surface_struct_resp_map_frontend.md row tagged (in-flight feature-z)
- summary: Step 1.2 overlaps a surface-map row already promised by in-flight sibling feature-z.
- rationale: The current plan and sibling promise may duplicate product surface ownership unless the operator intentionally keeps both.
- recommendation: Decide whether to reuse the sibling promise, depend on it, or keep both with explicit ownership notes.
- user_selection: postponed
- plan_patch_summary: No implementation plan change in this pass.
- resolution_notes: User postponed the overlap decision for later plan alignment.
REVIEW
    else
      cat >"$target_review" <<'REVIEW'
# Implementation Plan Semantic Review

## 1. Document Meta
- feature_id: FEAT-SEM-001
- feature_title: workspace-active-guard
- source_implementation_plan: projects/p1/feature-a/implementation_plan.md
- source_project_definition: projects/p1/init_progress_definition.yaml
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_technical_requirements: projects/p1/feature-a/technical_requirements.md
- review_status: complete
- last_updated: 2026-04-11

## 2. Review Guidance
- completion_rule: Set review_status complete only when every finding is terminal (applied, rejected, postponed) or no_findings true.
- user_question_format: Which finding numbers should I apply to implementation_plan.md? (examples: 1,3 | all | none | postpone 2 | reject 4)
- allowed_finding_types: step_scope_overlap, technical_gap_mix, dependency_ordering, requirement_grouping, delivered_surface_consumption_unclear, repo_scaffold_readiness_unclear
- allowed_severity: High, Medium, Low
- allowed_states: added, applied, rejected, postponed

## 3. Findings Ledger
- no_findings: true
REVIEW
    fi
    ;;
  sibling-covered)
    cat >"$target_review" <<'REVIEW'
# Implementation Plan Semantic Review

## 1. Document Meta
- feature_id: FEAT-SEM-001
- feature_title: workspace-active-guard
- source_implementation_plan: projects/p1/feature-a/implementation_plan.md
- source_project_definition: projects/p1/init_progress_definition.yaml
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_technical_requirements: projects/p1/feature-a/technical_requirements.md
- review_status: complete
- last_updated: 2026-04-11

## 2. Review Guidance
- completion_rule: Set review_status complete only when every finding is terminal (applied, rejected, postponed) or no_findings true.
- user_question_format: Which finding numbers should I apply to implementation_plan.md? (examples: 1,3 | all | none | postpone 2 | reject 4)
- allowed_finding_types: step_scope_overlap, technical_gap_mix, dependency_ordering, requirement_grouping, delivered_surface_consumption_unclear, repo_scaffold_readiness_unclear
- allowed_severity: High, Medium, Low
- allowed_states: added, applied, rejected, postponed

## 3. Findings Ledger
- no_findings: true
REVIEW
    ;;
  repo-scaffold-readiness)
    cat >"$target_review" <<'REVIEW'
# Implementation Plan Semantic Review

## 1. Document Meta
- feature_id: FEAT-SEM-001
- feature_title: workspace-active-guard
- source_implementation_plan: projects/p1/feature-a/implementation_plan.md
- source_project_definition: projects/p1/init_progress_definition.yaml
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_technical_requirements: projects/p1/feature-a/technical_requirements.md
- review_status: complete
- last_updated: 2026-04-11

## 2. Review Guidance
- completion_rule: Set review_status complete only when every finding is terminal (applied, rejected, postponed) or no_findings true.
- user_question_format: Which finding numbers should I apply to implementation_plan.md? (examples: 1,3 | all | none | postpone 2 | reject 4)
- allowed_finding_types: step_scope_overlap, technical_gap_mix, dependency_ordering, requirement_grouping, delivered_surface_consumption_unclear, repo_scaffold_readiness_unclear
- allowed_severity: High, Medium, Low
- allowed_states: added, applied, rejected, postponed

## 3. Findings Ledger
### Finding 1 - Frontend repo scaffold readiness is unclear
- severity: Medium
- finding_type: repo_scaffold_readiness_unclear
- state: postponed
- target_steps: Step 1.2, Step 1.3
- related_requirements: REQ-1, REQ-2
- related_evidence: projects/p1/init_progress_definition.yaml class_repo_paths.frontend, comp/frontend-workspace-client
- summary: Type A frontend plan steps exist, but project metadata does not show a ready frontend repo path.
- rationale: Frontend execution can block if scaffold creation is not completed before feature implementation begins.
- recommendation: Add an early frontend scaffold verification step or record that a parallel first feature owns scaffold creation.
- user_selection: postponed
- plan_patch_summary: No implementation plan change in this pass.
- resolution_notes: User postponed because frontend scaffold creation is handled by another parallel first feature.
REVIEW
    ;;
  invalid-empty-resolution-notes)
    cat >"$target_review" <<'REVIEW'
# Implementation Plan Semantic Review

## 1. Document Meta
- feature_id: FEAT-SEM-001
- feature_title: workspace-active-guard
- source_implementation_plan: projects/p1/feature-a/implementation_plan.md
- source_project_definition: projects/p1/init_progress_definition.yaml
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_technical_requirements: projects/p1/feature-a/technical_requirements.md
- review_status: complete
- last_updated: 2026-04-11

## 2. Review Guidance
- completion_rule: Set review_status complete only when every finding is terminal (applied, rejected, postponed) or no_findings true.
- user_question_format: Which finding numbers should I apply to implementation_plan.md? (examples: 1,3 | all | none | postpone 2 | reject 4)
- allowed_finding_types: step_scope_overlap, technical_gap_mix, dependency_ordering, requirement_grouping, delivered_surface_consumption_unclear, repo_scaffold_readiness_unclear
- allowed_severity: High, Medium, Low
- allowed_states: added, applied, rejected, postponed

## 3. Findings Ledger
### Finding 1 - New admin route has no inbound affordance
- severity: High
- finding_type: delivered_surface_consumption_unclear
- state: applied
- target_steps: Step 1.2
- related_requirements: REQ-1
- related_evidence: gap/TECH_REQ-2, comp/frontend-workspace-client
- summary: Step 1.2 adds /admin/workspace with no inbound affordance.
- rationale: Route exists but operators cannot reach it from known entry points.
- recommendation: Add sibling plan step for inbound affordance.
- user_selection: selected
- plan_patch_summary: Added inbound affordance step before Step 1.2.
- resolution_notes:
REVIEW
    ;;
  invalid-missing-requirement-link)
    cat >"$target_review" <<'REVIEW'
# Implementation Plan Semantic Review

## 1. Document Meta
- feature_id: FEAT-SEM-001
- feature_title: workspace-active-guard
- source_implementation_plan: projects/p1/feature-a/implementation_plan.md
- source_project_definition: projects/p1/init_progress_definition.yaml
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_technical_requirements: projects/p1/feature-a/technical_requirements.md
- review_status: complete
- last_updated: 2026-04-11

## 2. Review Guidance
- completion_rule: Set review_status complete only when every finding is terminal (applied, rejected, postponed) or no_findings true.
- user_question_format: Which finding numbers should I apply to implementation_plan.md? (examples: 1,3 | all | none | postpone 2 | reject 4)
- allowed_finding_types: step_scope_overlap, technical_gap_mix, dependency_ordering, requirement_grouping, delivered_surface_consumption_unclear, repo_scaffold_readiness_unclear
- allowed_severity: High, Medium, Low
- allowed_states: added, applied, rejected, postponed

## 3. Findings Ledger
### Finding 1 - New admin route has no inbound affordance
- severity: High
- finding_type: delivered_surface_consumption_unclear
- state: applied
- target_steps: Step 1.2
- related_requirements: none
- related_evidence: gap/TECH_REQ-2, comp/frontend-workspace-client
- summary: Step 1.2 adds /admin/workspace with no inbound affordance.
- rationale: Route exists but operators cannot reach it from known entry points.
- recommendation: Add sibling plan step for inbound affordance.
- user_selection: selected
- plan_patch_summary: Added inbound affordance step before Step 1.2.
- resolution_notes: User accepted this finding and requested explicit inbound navigation.
REVIEW
    ;;
  *)
    cat >"$target_review" <<'REVIEW'
# Implementation Plan Semantic Review

## 1. Document Meta
- feature_id: FEAT-SEM-001
- feature_title: workspace-active-guard
- source_implementation_plan: projects/p1/feature-a/implementation_plan.md
- source_project_definition: projects/p1/init_progress_definition.yaml
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_technical_requirements: projects/p1/feature-a/technical_requirements.md
- review_status: complete
- last_updated: 2026-04-11

## 2. Review Guidance
- completion_rule: Set review_status complete only when every finding is terminal (applied, rejected, postponed) or no_findings true.
- user_question_format: Which finding numbers should I apply to implementation_plan.md? (examples: 1,3 | all | none | postpone 2 | reject 4)
- allowed_finding_types: step_scope_overlap, technical_gap_mix, dependency_ordering, requirement_grouping, delivered_surface_consumption_unclear, repo_scaffold_readiness_unclear
- allowed_severity: High, Medium, Low
- allowed_states: added, applied, rejected, postponed

## 3. Findings Ledger
### Finding 1 - New admin route has no inbound affordance
- severity: High
- finding_type: delivered_surface_consumption_unclear
- state: applied
- target_steps: Step 1.2
- related_requirements: REQ-1
- related_evidence: gap/TECH_REQ-2, comp/frontend-workspace-client
- summary: Step 1.2 adds /admin/workspace with no inbound affordance.
- rationale: Route exists but operators cannot reach it from known entry points.
- recommendation: Add sibling plan step for inbound affordance.
- user_selection: selected
- plan_patch_summary: Added inbound affordance step before Step 1.2.
- resolution_notes: User accepted this finding and requested explicit inbound navigation.
REVIEW
    ;;
esac
OUT
  chmod +x "$repo_dir/bin/codex"
}

setup_git_workspace() {
  local repo_dir="$1"
  setup_workspace_layout "$repo_dir"
  setup_models_file "$repo_dir"
  seed_feature_sources "$repo_dir"
}

test_requires_feature_path_argument() {
  local repo_dir="$TMP_ROOT/repo-missing-arg"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_implementation_plan_semantic_review.sh 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --feature_path <feature-folder-path>."
}

test_requires_staged_command_location() {
  local repo_dir="$TMP_ROOT/repo-staged-required"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  cp "$repo_dir/asdlc/.commands/feature_implementation_plan_semantic_review.sh" "$repo_dir/feature_implementation_plan_semantic_review.sh"
  chmod +x "$repo_dir/feature_implementation_plan_semantic_review.sh"

  local status=0
  local out=""
  set +e
  out="$($repo_dir/feature_implementation_plan_semantic_review.sh --feature_path "$repo_dir/asdlc/projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Run this command from ASDLC staged path"
}

test_fails_when_required_file_is_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-required-file"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"
  rm -f "$repo_dir/asdlc/.rules/implementation_plan_semantic_review_rule.md"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_implementation_plan_semantic_review.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: .rules/implementation_plan_semantic_review_rule.md"
}

test_fails_when_model_phase_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-model-phase"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  cat >"$repo_dir/asdlc/.setup/models.md" <<'OUT'
# Phase | Command | Model | Extra Arg 1 (optional) | Extra Arg 2 (optional) | ...
repository_implementation_plan | codex | gpt-5.4
OUT

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_implementation_plan_semantic_review.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Invalid or missing 'implementation_plan_semantic_review' entry"
}

test_runs_codex_and_commits_plan_and_review_outputs() {
  local repo_dir="$TMP_ROOT/repo-success-default"
  local capture_dir="$TMP_ROOT/capture-success-default"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  local requirements_before=""
  local technical_before=""
  local definition_before=""
  definition_before="$(cat "$repo_dir/asdlc/projects/p1/init_progress_definition.yaml")"
  requirements_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears.md")"
  technical_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/technical_requirements.md")"
  echo "local-change" >>"$repo_dir/asdlc/README.md"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" .commands/feature_implementation_plan_semantic_review.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/implementation_plan.md"
  assert_contains "$out" "Updated projects/p1/feature-a/implementation_plan_semantic_review.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/implementation_plan.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/implementation_plan_semantic_review.md"
  assert_file_exists "$capture_dir/codex_args.txt"
  assert_file_exists "$capture_dir/codex_prompt.txt"

  local codex_args
  codex_args="$(cat "$capture_dir/codex_args.txt")"
  assert_contains "$codex_args" "-m"
  assert_contains "$codex_args" "gpt-5.4"
  assert_contains "$codex_args" "--config"
  assert_contains "$codex_args" "model_reasoning_effort='high'"

  local codex_prompt
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "Run optional Step 8.4 implementation-plan semantic review phase for this feature."
  assert_contains "$codex_prompt" ".rules/implementation_plan_semantic_review_rule.md"
  assert_contains "$codex_prompt" "projects/p1/init_progress_definition.yaml"
  assert_contains "$codex_prompt" "prerequisite_gaps.md"
  assert_contains "$codex_prompt" "Update only projects/p1/feature-a/implementation_plan.md and projects/p1/feature-a/implementation_plan_semantic_review.md."
  assert_contains "$codex_prompt" "Which finding numbers should I apply to implementation_plan.md?"
  assert_contains "$codex_prompt" ".helper/check_implementation_plan_semantic_review_quality.sh projects/p1/feature-a/implementation_plan_semantic_review.md"
  assert_contains "$codex_prompt" ".helper/check_implementation_plan_quality.sh projects/p1/feature-a/implementation_plan.md"

  assert_equal "$definition_before" "$(cat "$repo_dir/asdlc/projects/p1/init_progress_definition.yaml")"
  assert_equal "$requirements_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears.md")"
  assert_equal "$technical_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/technical_requirements.md")"

  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/implementation_plan.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/implementation_plan_semantic_review.md"
}

test_runs_with_absolute_feature_path() {
  local repo_dir="$TMP_ROOT/repo-success-override"
  local capture_dir="$TMP_ROOT/capture-success-override"
  local feature_path="projects/p1/custom-folder"
  local absolute_feature_path=""
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"
  seed_feature_sources "$repo_dir" "$feature_path"
  absolute_feature_path="$repo_dir/asdlc/$feature_path"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TARGET_PLAN_FILE="$feature_path/implementation_plan.md" TARGET_REVIEW_FILE="$feature_path/implementation_plan_semantic_review.md" \
      .commands/feature_implementation_plan_semantic_review.sh --feature_path "$absolute_feature_path"
  )"

  assert_contains "$out" "Updated $feature_path/implementation_plan.md"
  assert_contains "$out" "Updated $feature_path/implementation_plan_semantic_review.md"
  assert_file_exists "$repo_dir/asdlc/$feature_path/implementation_plan.md"
  assert_file_exists "$repo_dir/asdlc/$feature_path/implementation_plan_semantic_review.md"

  local codex_prompt
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "Feature root: $feature_path"
  assert_contains "$codex_prompt" "Mutable plan target: $feature_path/implementation_plan.md"
  assert_contains "$codex_prompt" "Mutable semantic review target: $feature_path/implementation_plan_semantic_review.md"
  assert_not_contains "$codex_prompt" "Mutable plan target: projects/p1/feature-a/implementation_plan.md"
}

test_missing_inbound_surface_emits_delivered_surface_finding() {
  local repo_dir="$TMP_ROOT/repo-missing-inbound-finding"
  local capture_dir="$TMP_ROOT/capture-missing-inbound-finding"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  (
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" STUB_REVIEW_VARIANT="missing-inbound" \
      .commands/feature_implementation_plan_semantic_review.sh --feature_path "projects/p1/feature-a"
  ) >/dev/null

  local review_artifact
  review_artifact="$(cat "$repo_dir/asdlc/projects/p1/feature-a/implementation_plan_semantic_review.md")"
  assert_contains "$review_artifact" "finding_type: delivered_surface_consumption_unclear"
  assert_contains "$review_artifact" "summary: Step 1.2 adds /admin/workspace with no inbound affordance."
}

test_sibling_inbound_surface_has_no_delivered_surface_finding() {
  local repo_dir="$TMP_ROOT/repo-sibling-inbound-covered"
  local capture_dir="$TMP_ROOT/capture-sibling-inbound-covered"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  (
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" STUB_REVIEW_VARIANT="sibling-covered" \
      .commands/feature_implementation_plan_semantic_review.sh --feature_path "projects/p1/feature-a"
  ) >/dev/null

  local review_artifact
  review_artifact="$(cat "$repo_dir/asdlc/projects/p1/feature-a/implementation_plan_semantic_review.md")"
  assert_contains "$review_artifact" "- no_findings: true"
  assert_not_contains "$review_artifact" "finding_type: delivered_surface_consumption_unclear"
}

test_prompt_includes_surface_maps_when_present() {
  local repo_dir="$TMP_ROOT/repo-surface-map-prompt"
  local capture_dir="$TMP_ROOT/capture-surface-map-prompt"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"
  seed_surface_maps "$repo_dir"

  (
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" STUB_REVIEW_VARIANT="sibling-covered" \
      .commands/feature_implementation_plan_semantic_review.sh --feature_path "projects/p1/feature-a"
  ) >/dev/null

  local codex_prompt
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "Read-only applicable surface-map artifacts:"
  assert_contains "$codex_prompt" "projects/p1/feature-a/project_surface_struct_resp_map_backend.md"
  assert_contains "$codex_prompt" "projects/p1/feature-a/project_surface_struct_resp_map_frontend.md"
}

test_in_flight_surface_map_row_emits_overlap_finding() {
  local repo_dir="$TMP_ROOT/repo-in-flight-overlap-finding"
  local capture_dir="$TMP_ROOT/capture-in-flight-overlap-finding"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  local rule_text
  rule_text="$(cat "$repo_dir/asdlc/.rules/implementation_plan_semantic_review_rule.md")"
  assert_contains "$rule_text" 'Treat every read-only surface-map row tagged `(in-flight <feature-folder>)` as an in-flight sibling promise overlap'
  assert_contains "$rule_text" "Use finding type \`step_scope_overlap\` for in-flight sibling promise overlaps"

  cat >"$repo_dir/asdlc/projects/p1/feature-a/project_surface_struct_resp_map_frontend.md" <<'OUT'
# Frontend Surface Map

## Section 4
- user_reachable_surface: /admin/workspace (in-flight feature-z)
OUT

  (
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" STUB_REVIEW_VARIANT="surface-map-driven" \
      .commands/feature_implementation_plan_semantic_review.sh --feature_path "projects/p1/feature-a"
  ) >/dev/null

  local review_artifact
  review_artifact="$(cat "$repo_dir/asdlc/projects/p1/feature-a/implementation_plan_semantic_review.md")"
  assert_contains "$review_artifact" "finding_type: step_scope_overlap"
  assert_contains "$review_artifact" "overlaps a surface-map row already promised by in-flight sibling feature-z"
  assert_contains "$review_artifact" "related_evidence: project_surface_struct_resp_map_frontend.md row tagged (in-flight feature-z)"
}

test_no_in_flight_surface_map_rows_adds_no_overlap_finding() {
  local repo_dir="$TMP_ROOT/repo-no-in-flight-overlap-finding"
  local capture_dir="$TMP_ROOT/capture-no-in-flight-overlap-finding"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"
  seed_surface_maps "$repo_dir"

  local rule_text
  rule_text="$(cat "$repo_dir/asdlc/.rules/implementation_plan_semantic_review_rule.md")"
  assert_contains "$rule_text" 'Treat every read-only surface-map row tagged `(in-flight <feature-folder>)` as an in-flight sibling promise overlap'

  (
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" STUB_REVIEW_VARIANT="surface-map-driven" \
      .commands/feature_implementation_plan_semantic_review.sh --feature_path "projects/p1/feature-a"
  ) >/dev/null

  local review_artifact
  review_artifact="$(cat "$repo_dir/asdlc/projects/p1/feature-a/implementation_plan_semantic_review.md")"
  assert_contains "$review_artifact" "- no_findings: true"
  assert_not_contains "$review_artifact" "in-flight sibling"
  assert_not_contains "$review_artifact" "finding_type: step_scope_overlap"
}

test_fails_when_active_surface_map_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-active-map"
  local capture_dir="$TMP_ROOT/capture-missing-active-map"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"
  rm -f "$repo_dir/asdlc/projects/p1/feature-a/project_surface_struct_resp_map_frontend.md"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" \
      .commands/feature_implementation_plan_semantic_review.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required surface-map artifacts not found for active repo classes: frontend"
}

test_type_a_repo_scaffold_readiness_finding_is_supported() {
  local repo_dir="$TMP_ROOT/repo-scaffold-readiness"
  local capture_dir="$TMP_ROOT/capture-scaffold-readiness"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<'OUT'
meta_info:
  project_id: "p1"
  project_type_code: "A"
  project_type_label: "New project"
  project_classes:
    - backend
    - frontend
  class_repo_paths:
    backend:
      state: ready
      path: /tmp/backend-ready
    frontend:
      state: missing
      path: ""
steps:
  - step_number: "0"
    step_name: "placeholder"
OUT

  (
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" STUB_REVIEW_VARIANT="repo-scaffold-readiness" \
      .commands/feature_implementation_plan_semantic_review.sh --feature_path "projects/p1/feature-a"
  ) >/dev/null

  local review_artifact
  review_artifact="$(cat "$repo_dir/asdlc/projects/p1/feature-a/implementation_plan_semantic_review.md")"
  assert_contains "$review_artifact" "finding_type: repo_scaffold_readiness_unclear"
  assert_contains "$review_artifact" "Frontend repo scaffold readiness is unclear"

  local codex_prompt
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "Read-only project definition source: projects/p1/init_progress_definition.yaml"
}

test_terminal_delivered_surface_finding_requires_resolution_notes() {
  local repo_dir="$TMP_ROOT/repo-missing-resolution-notes"
  local capture_dir="$TMP_ROOT/capture-missing-resolution-notes"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" STUB_REVIEW_VARIANT="invalid-empty-resolution-notes" \
      .commands/feature_implementation_plan_semantic_review.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "quality gate failed: finding block 1 (delivered_surface_consumption_unclear) has terminal state with empty resolution_notes"
}

test_delivered_surface_finding_requires_requirement_link() {
  local repo_dir="$TMP_ROOT/repo-missing-requirement-link"
  local capture_dir="$TMP_ROOT/capture-missing-requirement-link"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" STUB_REVIEW_VARIANT="invalid-missing-requirement-link" \
      .commands/feature_implementation_plan_semantic_review.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "must reference at least one REQ-* or NFR-* id in related_requirements"
}

test_requires_feature_path_argument
test_requires_staged_command_location
test_fails_when_required_file_is_missing
test_fails_when_model_phase_missing
test_runs_codex_and_commits_plan_and_review_outputs
test_runs_with_absolute_feature_path
test_missing_inbound_surface_emits_delivered_surface_finding
test_sibling_inbound_surface_has_no_delivered_surface_finding
test_prompt_includes_surface_maps_when_present
test_in_flight_surface_map_row_emits_overlap_finding
test_no_in_flight_surface_map_rows_adds_no_overlap_finding
test_fails_when_active_surface_map_missing
test_type_a_repo_scaffold_readiness_finding_is_supported
test_terminal_delivered_surface_finding_requires_resolution_notes
test_delivered_surface_finding_requires_requirement_link

echo "All implementation plan semantic review initializer tests passed."
