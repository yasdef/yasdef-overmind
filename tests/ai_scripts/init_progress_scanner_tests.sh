#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCANNER_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/init_progress_scanner.sh"

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

setup_asdlc_with_scanner() {
  local asdlc_root="$1"
  mkdir -p "$asdlc_root/.commands" "$asdlc_root/projects"
  cp "$SCANNER_SRC" "$asdlc_root/.commands/init_progress_scanner.sh"
  chmod +x "$asdlc_root/.commands/init_progress_scanner.sh"
}

test_scanner_renders_grouped_sections_and_persists_step_state() {
  local asdlc_root="$TMP_ROOT/asdlc-render"
  setup_asdlc_with_scanner "$asdlc_root"

  local project_dir="$asdlc_root/projects/project-a"
  local feature_dir="$project_dir/features/feature-a"
  mkdir -p "$feature_dir"

  cat >"$project_dir/init_progress_definition.yaml" <<'EOF_DEF'
meta_info:
  project_classes:
    - backend

steps:
  - step_number: 1
    phase_name: "init"
    step_name: "Initialize Repo ASDLC Metadata"
    finished_only_if_artefacts_present:
      - file: "repo_structure_summary.md"
  - step_number: 2
    phase_name: "init"
    step_name: "Create Cross-Repository Contract Definition For This Project"
    finished_only_if_artefacts_present:
      - file: "common_contract_definition.md"
  - step_number: 3
    phase_name: "feature"
    step_name: "Convert BR to EARS"
    finished_only_if_artefacts_present:
      - file: "requirements_ears_feature.md"
        special_folder: "/product"
  - step_number: 4
    phase_name: "feature"
    step_name: "BR readiness"
    finished_only_if_artefacts_present:
      - file: "feature_br_summary.md"
        special_folder: "/overmind/product"
        check_key_value:
          key: "ready_to_ears"
          equals: "true"
          section: "## 1. Document Meta"
EOF_DEF

  echo "summary" >"$project_dir/repo_structure_summary.md"
  echo "contracts" >"$project_dir/common_contract_definition.md"
  echo "ears" >"$feature_dir/requirements_ears_feature.md"
  cat >"$feature_dir/feature_br_summary.md" <<'EOF_BR'
## 1. Document Meta
feature_title: "Payments API Onboarding"
ready_to_ears: true
EOF_BR

  local out
  out="$($asdlc_root/.commands/init_progress_scanner.sh --path "$feature_dir")"

  assert_contains "$out" "# Overmind Bootstrap Checklist"
  assert_contains "$out" "---- PROJECT LEVEL TASKS ----"
  assert_contains "$out" "- [x] 1 Initialize Repo ASDLC Metadata"
  assert_contains "$out" "- [x] 2 Create Cross-Repository Contract Definition For This Project"
  assert_contains "$out" "--- FEATURE LEVEL TASKS Payments API Onboarding ---"
  assert_contains "$out" "- [x] 3 Convert BR to EARS"
  assert_contains "$out" "- [x] 4 BR readiness"
  assert_contains "$out" "next step: none"

  local state_path="$project_dir/step_state.md"
  assert_file_exists "$state_path"
  assert_equal "$(cat "$state_path")" "$out"
}

test_scanner_uses_deterministic_feature_heading_fallback_when_title_missing() {
  local asdlc_root="$TMP_ROOT/asdlc-feature-heading-fallback"
  setup_asdlc_with_scanner "$asdlc_root"

  local project_dir="$asdlc_root/projects/project-feature-heading-fallback"
  local feature_dir="$project_dir/feature-area"
  mkdir -p "$feature_dir"

  cat >"$project_dir/init_progress_definition.yaml" <<'EOF_DEF'
meta_info:
  project_classes:
    - frontend

steps:
  - step_number: 1
    phase_name: "feature"
    step_name: "Feature summary present"
    finished_only_if_artefacts_present:
      - file: "feature_br_summary.md"
        special_folder: "/overmind/product"
EOF_DEF

  cat >"$feature_dir/feature_br_summary.md" <<'EOF_BR'
## 1. Document Meta
ready_to_ears: true
EOF_BR

  local out
  out="$($asdlc_root/.commands/init_progress_scanner.sh --path "$feature_dir")"

  assert_contains "$out" "--- FEATURE LEVEL TASKS <feature not initialized> ---"
  assert_contains "$out" "- [x] 1 Feature summary present"
  assert_contains "$out" "next step: none"
}

test_scanner_rejects_missing_path_argument() {
  local asdlc_root="$TMP_ROOT/asdlc-missing-path"
  setup_asdlc_with_scanner "$asdlc_root"

  local status=0
  local out=""
  set +e
  out="$($asdlc_root/.commands/init_progress_scanner.sh 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --path <path/to/feature>"
}

test_scanner_rejects_project_root_path_when_feature_is_required() {
  local asdlc_root="$TMP_ROOT/asdlc-project-root-reject"
  setup_asdlc_with_scanner "$asdlc_root"

  local project_dir="$asdlc_root/projects/project-root"
  mkdir -p "$project_dir/feature-a"

  cat >"$project_dir/init_progress_definition.yaml" <<'EOF_DEF'
steps:
  - step_number: 1
    step_name: "Any step"
    finished_only_if_artefacts_present:
      - file: "ready.md"
EOF_DEF

  local status=0
  local out=""
  set +e
  out="$($asdlc_root/.commands/init_progress_scanner.sh --path "$project_dir" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "--path must point to a feature-level folder inside project"
}

test_scanner_rejects_feature_path_outside_asdlc_projects() {
  local asdlc_root="$TMP_ROOT/asdlc-outside"
  setup_asdlc_with_scanner "$asdlc_root"

  local outside_feature="$TMP_ROOT/not-in-projects/feature-a"
  mkdir -p "$outside_feature"

  local status=0
  local out=""
  set +e
  out="$($asdlc_root/.commands/init_progress_scanner.sh --path "$outside_feature" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Selected feature path must be inside ASDLC projects directory"
}

test_scanner_infers_project_root_from_selected_feature_folder() {
  local asdlc_root="$TMP_ROOT/asdlc-infer-project"
  setup_asdlc_with_scanner "$asdlc_root"

  local project_dir="$asdlc_root/projects/project-infer"
  local feature_dir="$project_dir/features/payments"
  mkdir -p "$feature_dir"

  cat >"$project_dir/init_progress_definition.yaml" <<'EOF_DEF'
meta_info:
  project_classes:
    - backend

steps:
  - step_number: 1
    phase_name: "init"
    step_name: "Project artifact exists"
    finished_only_if_artefacts_present:
      - file: "project_ready.md"
  - step_number: 2
    phase_name: "feature"
    step_name: "Feature artifact exists"
    finished_only_if_artefacts_present:
      - file: "feature_ready.md"
        special_folder: "/product"
EOF_DEF

  echo "project ready" >"$project_dir/project_ready.md"
  echo "feature ready" >"$feature_dir/feature_ready.md"

  local out
  out="$($asdlc_root/.commands/init_progress_scanner.sh --path "$feature_dir")"

  assert_contains "$out" "- [x] 1 Project artifact exists"
  assert_contains "$out" "- [x] 2 Feature artifact exists"
  assert_file_exists "$project_dir/step_state.md"
}

test_scanner_checks_init_phase_artifacts_from_project_root_even_with_product_special_folder() {
  local asdlc_root="$TMP_ROOT/asdlc-init-phase-project-root"
  setup_asdlc_with_scanner "$asdlc_root"

  local project_dir="$asdlc_root/projects/project-init-phase-root"
  local feature_dir="$project_dir/features/feature-a"
  mkdir -p "$feature_dir"

  cat >"$project_dir/init_progress_definition.yaml" <<'EOF_DEF'
meta_info:
  project_classes:
    - backend

steps:
  - step_number: 2
    phase_name: "init"
    step_name: "Create Cross-Repository Contract Definition For This Project"
    finished_only_if_artefacts_present:
      - file: "common_contract_definition.md"
        special_folder: "/product"
EOF_DEF

  # Feature-level copy should not satisfy init-phase step.
  echo "feature copy only" >"$feature_dir/common_contract_definition.md"

  local out_missing_project_file
  out_missing_project_file="$($asdlc_root/.commands/init_progress_scanner.sh --path "$feature_dir")"
  assert_contains "$out_missing_project_file" "- [ ] 2 Create Cross-Repository Contract Definition For This Project"
  assert_contains "$out_missing_project_file" "next step: 2 (Create Cross-Repository Contract Definition For This Project)"

  # Project-root copy should satisfy init-phase step regardless of special_folder value.
  echo "project canonical copy" >"$project_dir/common_contract_definition.md"

  local out_with_project_file
  out_with_project_file="$($asdlc_root/.commands/init_progress_scanner.sh --path "$feature_dir")"
  assert_contains "$out_with_project_file" "- [x] 2 Create Cross-Repository Contract Definition For This Project"
  assert_contains "$out_with_project_file" "next step: none"
}

test_scanner_evaluates_project_root_and_selected_feature_only() {
  local asdlc_root="$TMP_ROOT/asdlc-feature-isolation"
  setup_asdlc_with_scanner "$asdlc_root"

  local project_dir="$asdlc_root/projects/project-isolation"
  local feature_one="$project_dir/feature-1"
  local feature_two="$project_dir/feature-2"
  mkdir -p "$feature_one" "$feature_two"

  cat >"$project_dir/init_progress_definition.yaml" <<'EOF_DEF'
meta_info:
  project_classes:
    - backend

steps:
  - step_number: 1
    phase_name: "init"
    step_name: "Project readiness marker"
    finished_only_if_artefacts_present:
      - file: "project_ready.md"
  - step_number: 2
    phase_name: "feature"
    step_name: "EARS requirements generated"
    finished_only_if_artefacts_present:
      - file: "requirements_ears_feature.md"
        special_folder: "/overmind/product"
EOF_DEF

  echo "project ready" >"$project_dir/project_ready.md"
  echo "ears in sibling feature" >"$feature_two/requirements_ears_feature.md"
  cat >"$feature_two/feature_br_summary.md" <<'EOF_BR'
## 1. Document Meta
feature_title: "Sibling Feature"
ready_to_ears: true
EOF_BR

  local out_feature_one
  out_feature_one="$($asdlc_root/.commands/init_progress_scanner.sh --path "$feature_one")"
  assert_contains "$out_feature_one" "- [x] 1 Project readiness marker"
  assert_contains "$out_feature_one" "- [ ] 2 EARS requirements generated"
  assert_contains "$out_feature_one" "--- FEATURE LEVEL TASKS <feature not initialized> ---"

  local out_feature_two
  out_feature_two="$($asdlc_root/.commands/init_progress_scanner.sh --path "$feature_two")"
  assert_contains "$out_feature_two" "- [x] 1 Project readiness marker"
  assert_contains "$out_feature_two" "- [x] 2 EARS requirements generated"
  assert_contains "$out_feature_two" "--- FEATURE LEVEL TASKS Sibling Feature ---"
}

test_scanner_applies_required_if_project_classes() {
  local asdlc_root="$TMP_ROOT/asdlc-required-if"
  setup_asdlc_with_scanner "$asdlc_root"

  local project_dir="$asdlc_root/projects/project-required-if"
  local feature_dir="$project_dir/feature-a"
  mkdir -p "$feature_dir"

  cat >"$project_dir/init_progress_definition.yaml" <<'EOF_DEF'
meta_info:
  project_classes:
    - backend

steps:
  - step_number: 4
    step_name: "Conditional artifacts"
    finished_only_if_artefacts_present:
      - file: "project_tech_summary_be.md"
        required_if:
          meta_info:
            project_classes:
              any_of: ["backend"]
      - file: "project_tech_summary_fe.md"
        required_if:
          meta_info:
            project_classes:
              any_of: ["frontend", "mobile"]
EOF_DEF

  echo "backend summary" >"$project_dir/project_tech_summary_be.md"

  local out
  out="$($asdlc_root/.commands/init_progress_scanner.sh --path "$feature_dir")"
  assert_contains "$out" "- [x] 4 Conditional artifacts"
}

test_scanner_fails_on_malformed_required_if() {
  local asdlc_root="$TMP_ROOT/asdlc-malformed-required-if"
  setup_asdlc_with_scanner "$asdlc_root"

  local project_dir="$asdlc_root/projects/project-malformed"
  local feature_dir="$project_dir/feature-a"
  mkdir -p "$feature_dir"

  cat >"$project_dir/init_progress_definition.yaml" <<'EOF_DEF'
steps:
  - step_number: 4
    step_name: "Malformed required_if"
    finished_only_if_artefacts_present:
      - file: "project_tech_summary_be.md"
        required_if:
          meta_info:
            project_classes:
              any_of:
                - backend
EOF_DEF

  echo "backend summary" >"$project_dir/project_tech_summary_be.md"

  local status=0
  local out=""
  set +e
  out="$($asdlc_root/.commands/init_progress_scanner.sh --path "$feature_dir" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "required_if.any_of must be inline YAML list"
}

test_scanner_reports_split_required_steps_4_1_then_4_2() {
  local asdlc_root="$TMP_ROOT/asdlc-split-steps"
  setup_asdlc_with_scanner "$asdlc_root"

  local project_dir="$asdlc_root/projects/project-split-steps"
  local feature_dir="$project_dir/feature-a"
  mkdir -p "$feature_dir"

  cat >"$project_dir/init_progress_definition.yaml" <<'EOF_DEF'
steps:
  - step_number: 3
    phase_name: "feature"
    step_name: "Initialize and Enrich Business Requirements Structuring"
    finished_only_if_artefacts_present:
      - file: "feature_br_summary.md"
        special_folder: "/product"
        check_key_value:
          key: "ready_to_ears"
          equals: "true"
          section: "## 1. Document Meta"
  - step_number: 4.1
    phase_name: "feature"
    step_name: "Scan repo and apply task-to-BR update"
    finished_only_if_artefacts_present:
      - file: "scan_done.md"
        special_folder: "/product"
      - file: "task_done.md"
        special_folder: "/product"
  - step_number: 4.2
    phase_name: "feature"
    step_name: "Clarify BR and check EARS readiness"
    finished_only_if_artefacts_present:
      - file: "readiness_done.md"
        special_folder: "/product"
  - step_number: 5
    phase_name: "feature"
    step_name: "Convert Business Requirements Structuring to EARS"
    finished_only_if_artefacts_present:
      - file: "requirements_ears.md"
        special_folder: "/product"
EOF_DEF

  cat >"$feature_dir/feature_br_summary.md" <<'EOF_BR'
## 1. Document Meta
ready_to_ears: true
EOF_BR

  local out_without_4_1
  out_without_4_1="$($asdlc_root/.commands/init_progress_scanner.sh --path "$feature_dir")"
  assert_contains "$out_without_4_1" "- [x] 3 Initialize and Enrich Business Requirements Structuring"
  assert_contains "$out_without_4_1" "- [ ] 4.1 Scan repo and apply task-to-BR update"
  assert_contains "$out_without_4_1" "next step: 4.1 (Scan repo and apply task-to-BR update)"

  echo "done" >"$feature_dir/scan_done.md"
  echo "done" >"$feature_dir/task_done.md"

  local out_with_4_1_only
  out_with_4_1_only="$($asdlc_root/.commands/init_progress_scanner.sh --path "$feature_dir")"
  assert_contains "$out_with_4_1_only" "- [x] 4.1 Scan repo and apply task-to-BR update"
  assert_contains "$out_with_4_1_only" "- [ ] 4.2 Clarify BR and check EARS readiness"
  assert_contains "$out_with_4_1_only" "next step: 4.2 (Clarify BR and check EARS readiness)"
}

test_scanner_does_not_block_on_incomplete_optional_step() {
  local asdlc_root="$TMP_ROOT/asdlc-optional-step"
  setup_asdlc_with_scanner "$asdlc_root"

  local project_dir="$asdlc_root/projects/project-optional"
  local feature_dir="$project_dir/feature-a"
  mkdir -p "$feature_dir"

  cat >"$project_dir/init_progress_definition.yaml" <<'EOF_DEF'
steps:
  - step_number: 4
    phase_name: "feature"
    step_name: "Convert BR to EARS"
    finished_only_if_artefacts_present:
      - file: "requirements_ears.md"
        special_folder: "/product"
  - step_number: 4.1
    phase_name: "feature"
    step_name: "(optional) requirement_ears extra review"
    optional: true
    finished_only_if_artefacts_present:
      - file: "requirements_ears_review.md"
        special_folder: "/product"
        check_key_value:
          key: "review_status"
          equals: "complete"
          section: "## 1. Document Meta"
  - step_number: 5
    phase_name: "feature"
    step_name: "Define Feature Contract Delta"
    finished_only_if_artefacts_present:
      - file: "feature_contract_delta.md"
        special_folder: "/product"
EOF_DEF

  echo "ears" >"$feature_dir/requirements_ears.md"
  echo "delta" >"$feature_dir/feature_contract_delta.md"

  local out
  out="$($asdlc_root/.commands/init_progress_scanner.sh --path "$feature_dir")"

  assert_contains "$out" "- [x] 4 Convert BR to EARS"
  assert_contains "$out" "- [ ] 4.1 (optional) requirement_ears extra review"
  assert_contains "$out" "- [x] 5 Define Feature Contract Delta"
  assert_contains "$out" "next step: none"
}

test_scanner_detects_step_8_2_prerequisite_gaps() {
  local asdlc_root="$TMP_ROOT/asdlc-step-8-2"
  setup_asdlc_with_scanner "$asdlc_root"

  local project_dir="$asdlc_root/projects/project-step-8-2"
  local feature_dir="$project_dir/feature-a"
  mkdir -p "$feature_dir"

  cat >"$project_dir/init_progress_definition.yaml" <<'EOF_DEF'
steps:
  - step_number: 8.1
    phase_name: "feature"
    step_name: "Create Implementation Slice Planning Artifact"
    finished_only_if_artefacts_present:
      - file: "implementation_slices.md"
        special_folder: "/product"
  - step_number: 8.2
    phase_name: "feature"
    step_name: "Run Prerequisite Gap Trace"
    finished_only_if_artefacts_present:
      - file: "prerequisite_gaps.md"
        special_folder: "/product"
  - step_number: 8.3
    phase_name: "feature"
    step_name: "Create Shared Repository Implementation Plan"
    finished_only_if_artefacts_present:
      - file: "implementation_plan.md"
        special_folder: "/product"
EOF_DEF

  echo "slices" >"$feature_dir/implementation_slices.md"

  local out_after_8_1
  out_after_8_1="$($asdlc_root/.commands/init_progress_scanner.sh --path "$feature_dir")"
  assert_contains "$out_after_8_1" "- [x] 8.1 Create Implementation Slice Planning Artifact"
  assert_contains "$out_after_8_1" "- [ ] 8.2 Run Prerequisite Gap Trace"
  assert_contains "$out_after_8_1" "next step: 8.2 (Run Prerequisite Gap Trace)"

  echo "gaps" >"$feature_dir/prerequisite_gaps.md"

  local out_after_8_2
  out_after_8_2="$($asdlc_root/.commands/init_progress_scanner.sh --path "$feature_dir")"
  assert_contains "$out_after_8_2" "- [x] 8.1 Create Implementation Slice Planning Artifact"
  assert_contains "$out_after_8_2" "- [x] 8.2 Run Prerequisite Gap Trace"
  assert_contains "$out_after_8_2" "- [ ] 8.3 Create Shared Repository Implementation Plan"
  assert_contains "$out_after_8_2" "next step: 8.3 (Create Shared Repository Implementation Plan)"
}

test_scanner_handles_optional_step_8_4_semantic_review_without_blocking_later_required_steps() {
  local asdlc_root="$TMP_ROOT/asdlc-optional-step-8-4"
  setup_asdlc_with_scanner "$asdlc_root"

  local project_dir="$asdlc_root/projects/project-optional-8-4"
  local feature_dir="$project_dir/feature-a"
  mkdir -p "$feature_dir"

  cat >"$project_dir/init_progress_definition.yaml" <<'EOF_DEF'
steps:
  - step_number: 8.1
    phase_name: "feature"
    step_name: "Create Implementation Slice Planning Artifact"
    finished_only_if_artefacts_present:
      - file: "implementation_slices.md"
        special_folder: "/product"
  - step_number: 8.2
    phase_name: "feature"
    step_name: "Run Prerequisite Gap Trace"
    finished_only_if_artefacts_present:
      - file: "prerequisite_gaps.md"
        special_folder: "/product"
  - step_number: 8.3
    phase_name: "feature"
    step_name: "Create Shared Repository Implementation Plan"
    finished_only_if_artefacts_present:
      - file: "implementation_plan.md"
        special_folder: "/product"
  - step_number: 8.4
    phase_name: "feature"
    step_name: "(optional) implementation plan semantic review"
    optional: true
    finished_only_if_artefacts_present:
      - file: "implementation_plan_semantic_review.md"
        special_folder: "/product"
        check_key_value:
          key: "review_status"
          equals: "complete"
          section: "## 1. Document Meta"
  - step_number: 9
    phase_name: "feature"
    step_name: "Ready for implementation handoff"
    finished_only_if_artefacts_present:
      - file: "handoff_ready.md"
        special_folder: "/product"
EOF_DEF

  echo "slices" >"$feature_dir/implementation_slices.md"
  echo "gaps" >"$feature_dir/prerequisite_gaps.md"
  echo "plan" >"$feature_dir/implementation_plan.md"
  echo "ready" >"$feature_dir/handoff_ready.md"

  local out_without_review
  out_without_review="$($asdlc_root/.commands/init_progress_scanner.sh --path "$feature_dir")"
  assert_contains "$out_without_review" "- [x] 8.1 Create Implementation Slice Planning Artifact"
  assert_contains "$out_without_review" "- [x] 8.2 Run Prerequisite Gap Trace"
  assert_contains "$out_without_review" "- [x] 8.3 Create Shared Repository Implementation Plan"
  assert_contains "$out_without_review" "- [ ] 8.4 (optional) implementation plan semantic review"
  assert_contains "$out_without_review" "- [x] 9 Ready for implementation handoff"
  assert_contains "$out_without_review" "next step: none"

  cat >"$feature_dir/implementation_plan_semantic_review.md" <<'EOF_REVIEW'
# Implementation Plan Semantic Review

## 1. Document Meta
- review_status: complete
EOF_REVIEW

  local out_with_review
  out_with_review="$($asdlc_root/.commands/init_progress_scanner.sh --path "$feature_dir")"
  assert_contains "$out_with_review" "- [x] 8.1 Create Implementation Slice Planning Artifact"
  assert_contains "$out_with_review" "- [x] 8.2 Run Prerequisite Gap Trace"
  assert_contains "$out_with_review" "- [x] 8.3 Create Shared Repository Implementation Plan"
  assert_contains "$out_with_review" "- [x] 8.4 (optional) implementation plan semantic review"
  assert_contains "$out_with_review" "- [x] 9 Ready for implementation handoff"
  assert_contains "$out_with_review" "next step: none"
}

test_scanner_renders_grouped_sections_and_persists_step_state
test_scanner_uses_deterministic_feature_heading_fallback_when_title_missing
test_scanner_rejects_missing_path_argument
test_scanner_rejects_project_root_path_when_feature_is_required
test_scanner_rejects_feature_path_outside_asdlc_projects
test_scanner_infers_project_root_from_selected_feature_folder
test_scanner_checks_init_phase_artifacts_from_project_root_even_with_product_special_folder
test_scanner_evaluates_project_root_and_selected_feature_only
test_scanner_applies_required_if_project_classes
test_scanner_fails_on_malformed_required_if
test_scanner_reports_split_required_steps_4_1_then_4_2
test_scanner_does_not_block_on_incomplete_optional_step
test_scanner_detects_step_8_2_prerequisite_gaps
test_scanner_handles_optional_step_8_4_semantic_review_without_blocking_later_required_steps

echo "All init progress scanner tests passed."
