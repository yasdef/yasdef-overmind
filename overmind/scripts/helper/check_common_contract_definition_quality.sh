#!/usr/bin/env bash
set -euo pipefail

TARGET_RELATIVE_PATH="${1:-common_contract_definition.md}"
REPO_MODE_HELPER_COMMAND_PATH="overmind/scripts/helper/check_common_contract_definition_quality.sh"
STAGED_MODE_HELPER_COMMAND_PATH=".helper/check_common_contract_definition_quality.sh"
HELPER_COMMAND_PATH="$REPO_MODE_HELPER_COMMAND_PATH"
WORKSPACE_ROOT=""

EXIT_CONTENT_FAILURE=1
EXIT_HELPER_FAILURE=2

helper_fail() {
  echo "ERROR: $*" >&2
  exit "$EXIT_HELPER_FAILURE"
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    helper_fail "Required command not found: $command_name"
  fi
}

resolve_workspace_root() {
  local script_dir=""
  local parent_dir=""
  local root=""

  if ! script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; then
    helper_fail "Failed to resolve script directory."
  fi

  parent_dir="$(dirname "$script_dir")"
  if [[ "$(basename "$script_dir")" == ".helper" && -f "$parent_dir/asdlc_metadata.yaml" ]]; then
    HELPER_COMMAND_PATH="$STAGED_MODE_HELPER_COMMAND_PATH"
    WORKSPACE_ROOT="$parent_dir"
    return 0
  fi

  require_command git
  if ! root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)"; then
    helper_fail "Not a git repository at script path: $script_dir"
  fi
  HELPER_COMMAND_PATH="$REPO_MODE_HELPER_COMMAND_PATH"
  WORKSPACE_ROOT="$root"
}

resolve_target_path() {
  local repo_root="$1"
  local target_input="$2"

  if [[ "$target_input" = /* ]]; then
    printf '%s\n' "$target_input"
    return 0
  fi

  printf '%s/%s\n' "$repo_root" "$target_input"
}

validate_content() {
  local target_path="$1"
  local status=0
  local rerun_command=""
  rerun_command="$HELPER_COMMAND_PATH $target_path"

  set +e
  awk -v rerun_command="$rerun_command" -v target_path="$target_path" '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
function normalize(v) {
  v = trim(v)
  if ((v ~ /^".*"$/) || (v ~ /^'\''.*'\''$/)) {
    v = substr(v, 2, length(v) - 2)
  }
  return v
}
function is_unfilled(v, u) {
  u = toupper(trim(v))
  return (trim(v) == "" || u == "[UNFILLED]")
}
function fail_quality(message) {
  print "quality gate failed: " message
  has_errors = 1
}
function is_integer(v) {
  return (v ~ /^[0-9]+$/)
}
function is_allowed_contract_status(v, normalized_status) {
  normalized_status = tolower(trim(v))
  return (normalized_status == "aligned" || normalized_status == "drifted" || normalized_status == "single_source" || normalized_status == "inferred")
}
function is_allowed_contract_kind(v, normalized_kind) {
  normalized_kind = tolower(trim(v))
  return (normalized_kind == "http_api" || normalized_kind == "event" || normalized_kind == "async_message" || normalized_kind == "db_schema" || normalized_kind == "config" || normalized_kind == "auth_token" || normalized_kind == "file_interface" || normalized_kind == "library_api" || normalized_kind == "other")
}
function is_allowed_interaction_mode(v, normalized_mode) {
  normalized_mode = tolower(trim(v))
  return (normalized_mode == "sync" || normalized_mode == "async" || normalized_mode == "pull" || normalized_mode == "push")
}
function is_allowed_trust_boundary(v, normalized_boundary) {
  normalized_boundary = tolower(trim(v))
  return (normalized_boundary == "public" || normalized_boundary == "internal" || normalized_boundary == "service_to_service" || normalized_boundary == "admin_only" || normalized_boundary == "none")
}
function is_compact_structured_shape(v, normalized_shape) {
  normalized_shape = tolower(trim(v))
  if (is_unfilled(normalized_shape)) {
    return 0
  }

  if (normalized_shape ~ /\.[[:space:]]*$/) {
    return 0
  }

  if (normalized_shape ~ /request[[:space:]]*:/ ||
      normalized_shape ~ /response[[:space:]]*:/ ||
      normalized_shape ~ /payload[[:space:]]*:/ ||
      normalized_shape ~ /schema[[:space:]]*:/ ||
      normalized_shape ~ /topic[[:space:]]/ ||
      normalized_shape ~ /->[[:space:]]*/ ||
      index(normalized_shape, "{") > 0 ||
      index(normalized_shape, "}") > 0 ||
      index(normalized_shape, "[") > 0 ||
      index(normalized_shape, "]") > 0) {
    return 1
  }

  return 0
}
function start_repository_block(block_name) {
  finish_repository_block()
  finish_contract_block()

  in_repository_block = 1
  repository_blocks++
  repository_name = normalize(block_name)
  repository_class = ""
  repository_path = ""
  repository_contract_evidence_summary = ""
  repository_key_surfaces_reviewed = ""
  repository_notes = ""
}
function finish_repository_block() {
  if (!in_repository_block) {
    return
  }

  if (is_unfilled(repository_name)) fail_quality("repository block heading is empty in section 2")
  if (is_unfilled(repository_class)) fail_quality("repository " repository_name " has unfilled key class")
  if (is_unfilled(repository_path)) fail_quality("repository " repository_name " has unfilled key repo_path")
  if (is_unfilled(repository_contract_evidence_summary)) fail_quality("repository " repository_name " has unfilled key contract_evidence_summary")
  if (is_unfilled(repository_key_surfaces_reviewed)) fail_quality("repository " repository_name " has unfilled key key_surfaces_reviewed")
  if (is_unfilled(repository_notes)) fail_quality("repository " repository_name " has unfilled key notes")

  in_repository_block = 0
}
function start_contract_block(block_name) {
  finish_repository_block()
  finish_contract_block()

  in_contract_block = 1
  contract_blocks++
  contract_name = normalize(block_name)
  contract_contract_kind = ""
  contract_interaction_mode = ""
  contract_producer_repositories = ""
  contract_consumer_repositories = ""
  contract_contract_surface = ""
  contract_contract_status = ""
  contract_source_of_truth = ""
  contract_canonical_shape = ""
  contract_shared_types = ""
  contract_trust_boundary = ""
  contract_compatibility_rule = ""
  contract_planning_implication = ""
  contract_notes = ""
}
function finish_contract_block() {
  if (!in_contract_block) {
    return
  }

  if (is_unfilled(contract_name)) fail_quality("contract block heading is empty in section 3")
  if (is_unfilled(contract_contract_kind)) fail_quality("contract " contract_name " has unfilled key contract_kind")
  if (is_unfilled(contract_interaction_mode)) fail_quality("contract " contract_name " has unfilled key interaction_mode")
  if (is_unfilled(contract_producer_repositories)) fail_quality("contract " contract_name " has unfilled key producer_repositories")
  if (is_unfilled(contract_consumer_repositories)) fail_quality("contract " contract_name " has unfilled key consumer_repositories")
  if (is_unfilled(contract_contract_surface)) fail_quality("contract " contract_name " has unfilled key contract_surface")
  if (is_unfilled(contract_contract_status)) fail_quality("contract " contract_name " has unfilled key contract_status")
  if (is_unfilled(contract_source_of_truth)) fail_quality("contract " contract_name " has unfilled key source_of_truth")
  if (is_unfilled(contract_canonical_shape)) fail_quality("contract " contract_name " has unfilled key canonical_shape")
  if (is_unfilled(contract_shared_types)) fail_quality("contract " contract_name " has unfilled key shared_types")
  if (is_unfilled(contract_trust_boundary)) fail_quality("contract " contract_name " has unfilled key trust_boundary")
  if (is_unfilled(contract_compatibility_rule)) fail_quality("contract " contract_name " has unfilled key compatibility_rule")
  if (is_unfilled(contract_planning_implication)) fail_quality("contract " contract_name " has unfilled key planning_implication")
  if (is_unfilled(contract_notes)) fail_quality("contract " contract_name " has unfilled key notes")
  if (!is_unfilled(contract_contract_status) && !is_allowed_contract_status(contract_contract_status)) {
    fail_quality("contract " contract_name " has invalid contract_status: " contract_contract_status " (allowed: aligned, drifted, single_source, inferred)")
  }
  if (!is_unfilled(contract_contract_kind) && !is_allowed_contract_kind(contract_contract_kind)) {
    fail_quality("contract " contract_name " has invalid contract_kind: " contract_contract_kind " (allowed: http_api, event, async_message, db_schema, config, auth_token, file_interface, library_api, other)")
  }
  if (!is_unfilled(contract_interaction_mode) && !is_allowed_interaction_mode(contract_interaction_mode)) {
    fail_quality("contract " contract_name " has invalid interaction_mode: " contract_interaction_mode " (allowed: sync, async, pull, push)")
  }
  if (!is_unfilled(contract_trust_boundary) && !is_allowed_trust_boundary(contract_trust_boundary)) {
    fail_quality("contract " contract_name " has invalid trust_boundary: " contract_trust_boundary " (allowed: public, internal, service_to_service, admin_only, none)")
  }
  if (!is_unfilled(contract_canonical_shape) && !is_compact_structured_shape(contract_canonical_shape)) {
    fail_quality("contract " contract_name " key canonical_shape must be compact and structured (not narrative prose)")
  }

  in_contract_block = 0
}
BEGIN {
  has_errors = 0
  section = ""

  saw_section_1 = 0
  saw_section_2 = 0
  saw_section_3 = 0
  saw_section_4 = 0
  saw_section_5 = 0
  saw_section_6 = 0

  project_id = ""
  source_repo_count = ""
  last_updated = ""
  confidence_level = ""
  repository_blocks = 0
  contract_blocks = 0
  decision_count = 0
  uncertainty_count = 0
  prep_count = 0
  uncertainty_1 = ""
  has_unfilled = 0
  in_repository_block = 0
  in_contract_block = 0
}
{
  if (toupper($0) ~ /\[UNFILLED\]/) {
    has_unfilled = 1
  }
}
/^##[[:space:]]+/ {
  finish_repository_block()
  finish_contract_block()

  heading = trim($0)
  section = ""
  if (heading ~ /^##[[:space:]]+1\.[[:space:]]+Document[[:space:]]+Meta[[:space:]]*$/) {
    section = "1"
    saw_section_1 = 1
  } else if (heading ~ /^##[[:space:]]+2\.[[:space:]]+Source[[:space:]]+Repository[[:space:]]+Evidence[[:space:]]*$/) {
    section = "2"
    saw_section_2 = 1
  } else if (heading ~ /^##[[:space:]]+3\.[[:space:]]+Common[[:space:]]+Contract[[:space:]]+Baseline[[:space:]]*$/) {
    section = "3"
    saw_section_3 = 1
  } else if (heading ~ /^##[[:space:]]+4\.[[:space:]]+Reconciliation[[:space:]]+Decisions[[:space:]]*$/) {
    section = "4"
    saw_section_4 = 1
  } else if (heading ~ /^##[[:space:]]+5\.[[:space:]]+Known[[:space:]]+Risks[[:space:]]*\/[[:space:]]*Uncertainties[[:space:]]*$/) {
    section = "5"
    saw_section_5 = 1
  } else if (heading ~ /^##[[:space:]]+6\.[[:space:]]+Common[[:space:]]+Planning[[:space:]]+Signals[[:space:]]*$/) {
    section = "6"
    saw_section_6 = 1
  }
  next
}
/^###[[:space:]]+Repository:[[:space:]]*/ {
  block_name = $0
  sub(/^###[[:space:]]+Repository:[[:space:]]*/, "", block_name)
  start_repository_block(block_name)
  next
}
/^###[[:space:]]+Contract:[[:space:]]*/ {
  block_name = $0
  sub(/^###[[:space:]]+Contract:[[:space:]]*/, "", block_name)
  start_contract_block(block_name)
  next
}
{
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*/, "", line)
  colon_idx = index(line, ":")
  if (colon_idx <= 0) {
    next
  }

  key = trim(substr(line, 1, colon_idx - 1))
  value = normalize(substr(line, colon_idx + 1))

  if (section == "1") {
    if (key == "project_id") project_id = value
    else if (key == "source_repo_count") source_repo_count = value
    else if (key == "last_updated") last_updated = value
    else if (key == "confidence_level") confidence_level = value
  } else if (section == "4") {
    if (key ~ /^decision_[0-9]+$/ && !is_unfilled(value)) {
      decision_count++
    }
  } else if (section == "5") {
    if (key ~ /^uncertainty_[0-9]+$/ && !is_unfilled(value)) {
      uncertainty_count++
    }
    if (key == "uncertainty_1") {
      uncertainty_1 = value
    }
  } else if (section == "6") {
    if (key ~ /^prep_[0-9]+$/ && !is_unfilled(value)) {
      prep_count++
    }
  }

  if (in_repository_block) {
    if (key == "class") repository_class = value
    else if (key == "repo_path") repository_path = value
    else if (key == "contract_evidence_summary") repository_contract_evidence_summary = value
    else if (key == "key_surfaces_reviewed") repository_key_surfaces_reviewed = value
    else if (key == "notes") repository_notes = value
  }

  if (in_contract_block) {
    if (key == "contract_kind") contract_contract_kind = value
    else if (key == "interaction_mode") contract_interaction_mode = value
    else if (key == "producer_repositories") contract_producer_repositories = value
    else if (key == "consumer_repositories") contract_consumer_repositories = value
    else if (key == "contract_surface") contract_contract_surface = value
    else if (key == "contract_status") contract_contract_status = value
    else if (key == "source_of_truth") contract_source_of_truth = value
    else if (key == "canonical_shape") contract_canonical_shape = value
    else if (key == "shared_types") contract_shared_types = value
    else if (key == "trust_boundary") contract_trust_boundary = value
    else if (key == "compatibility_rule") contract_compatibility_rule = value
    else if (key == "planning_implication") contract_planning_implication = value
    else if (key == "notes") contract_notes = value
  }
}
END {
  finish_repository_block()
  finish_contract_block()

  if (!saw_section_1) fail_quality("missing section ## 1. Document Meta")
  if (!saw_section_2) fail_quality("missing section ## 2. Source Repository Evidence")
  if (!saw_section_3) fail_quality("missing section ## 3. Common Contract Baseline")
  if (!saw_section_4) fail_quality("missing section ## 4. Reconciliation Decisions")
  if (!saw_section_5) fail_quality("missing section ## 5. Known Risks / Uncertainties")
  if (!saw_section_6) fail_quality("missing section ## 6. Common Planning Signals")

  if (has_unfilled) fail_quality("artifact still contains [UNFILLED] placeholders")

  if (is_unfilled(project_id)) fail_quality("key project_id is unfilled in section 1")
  if (!is_integer(source_repo_count)) fail_quality("key source_repo_count must be a non-negative integer in section 1")
  if (is_integer(source_repo_count) && source_repo_count < 1) fail_quality("key source_repo_count must be >= 1 in section 1")
  if (is_unfilled(last_updated)) fail_quality("key last_updated is unfilled in section 1")
  if (last_updated !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/) fail_quality("key last_updated must be YYYY-MM-DD in section 1")
  if (is_unfilled(confidence_level)) fail_quality("key confidence_level is unfilled in section 1")

  if (repository_blocks < 1) fail_quality("section 2 must contain at least one ### Repository block")
  if (contract_blocks < 1) fail_quality("section 3 must contain at least one ### Contract block")
  if (decision_count < 1) fail_quality("section 4 must include at least one filled decision_N entry")
  if (uncertainty_count < 1) fail_quality("section 5 must include at least one filled uncertainty_N entry (use explicit values like none or not_observed when applicable)")
  if (is_unfilled(uncertainty_1)) fail_quality("key uncertainty_1 is required and must be explicit (use none or not_observed if no active uncertainty)")
  if (prep_count < 1) fail_quality("section 6 must include at least one filled prep_N entry")
  if (is_integer(source_repo_count) && source_repo_count != repository_blocks) {
    fail_quality("source_repo_count must match number of repository blocks in section 2")
  }

  if (has_errors) {
    print "quality gate guidance: fix reported fields in " target_path " and rerun: " rerun_command
    exit 1
  }

  print "quality gate passed: common contract definition is complete"
}
' "$target_path"
  status=$?
  set -e

  case "$status" in
  0)
    return 0
    ;;
  1)
    echo "quality gate guidance: model must update $target_path and rerun helper command until it exits 0." >&2
    return "$EXIT_CONTENT_FAILURE"
    ;;
  *)
    helper_fail "Validation runtime failure for $target_path (awk exit $status)."
    ;;
  esac
}

main() {
  require_command awk
  require_command grep

  local repo_root=""
  resolve_workspace_root
  repo_root="$WORKSPACE_ROOT"

  local target_path=""
  target_path="$(resolve_target_path "$repo_root" "$TARGET_RELATIVE_PATH")"

  if [[ ! -f "$target_path" ]]; then
    helper_fail "Target common contract definition artifact not found: $target_path"
  fi

  if ! grep -q '[^[:space:]]' "$target_path"; then
    echo "quality gate failed: target common contract definition artifact is empty: $target_path"
    exit "$EXIT_CONTENT_FAILURE"
  fi

  validate_content "$target_path"
}

main "$@"
