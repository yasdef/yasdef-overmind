#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REGISTER_WORKER_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_register_worker.sh"

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

assert_matches() {
  local value="$1"
  local regex="$2"
  if [[ ! "$value" =~ $regex ]]; then
    echo "Assertion failed: expected '$value' to match regex '$regex'" >&2
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

count_occurrences() {
  local haystack="$1"
  local needle="$2"
  awk -v needle="$needle" '
BEGIN { count = 0 }
{
  line = $0
  while (index(line, needle) > 0) {
    count++
    line = substr(line, index(line, needle) + length(needle))
  }
}
END { print count }
' <<<"$haystack"
}

setup_workspace() {
  local asdlc_root="$1"

  mkdir -p "$asdlc_root/.commands" "$asdlc_root/projects"
  cat >"$asdlc_root/asdlc_metadata.yaml" <<'EOF'
meta:
  description: "test workspace"
projects:
EOF

  cp "$REGISTER_WORKER_SRC" "$asdlc_root/.commands/project_register_worker.sh"
  chmod +x "$asdlc_root/.commands/project_register_worker.sh"
}

create_project_with_definition() {
  local asdlc_root="$1"
  local folder_name="$2"
  local project_id="$3"
  local project_dir="$asdlc_root/projects/$folder_name"

  mkdir -p "$project_dir"
  cat >"$project_dir/init_progress_definition.yaml" <<EOF
meta_info:
  project_id: "$project_id"
steps: []
EOF

  printf '%s' "$project_dir"
}

extract_last_worker_uuid() {
  local workers_path="$1"
  awk '
/^[[:space:]]*-[[:space:]]*uuid:[[:space:]]*/ {
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*uuid:[[:space:]]*/, "", line)
  gsub(/"/, "", line)
  uuid = line
}
END {
  print uuid
}
' "$workers_path"
}

extract_last_worker_class() {
  local workers_path="$1"
  awk -F': ' '
/^[[:space:]]*class:[[:space:]]*/ {
  value = $2
  gsub(/"/, "", value)
  worker_class = value
}
END {
  print worker_class
}
' "$workers_path"
}

extract_last_worker_status() {
  local workers_path="$1"
  awk -F': ' '
/^[[:space:]]*status:[[:space:]]*/ {
  value = $2
  gsub(/"/, "", value)
  status = value
}
END {
  print status
}
' "$workers_path"
}

extract_last_registered_at() {
  local workers_path="$1"
  awk -F': ' '
/^[[:space:]]*registered_at:[[:space:]]*/ {
  value = $2
  gsub(/"/, "", value)
  registered_at = value
}
END {
  print registered_at
}
' "$workers_path"
}

count_registered_workers() {
  local workers_path="$1"
  grep -cE '^[[:space:]]*-[[:space:]]*uuid:[[:space:]]*' "$workers_path" || true
}

extract_last_nonempty_line() {
  local value="$1"
  awk 'NF { line = $0 } END { print line }' <<<"$value"
}

test_register_worker_rejects_missing_path_argument() {
  local asdlc_root="$TMP_ROOT/asdlc-missing-path"
  setup_workspace "$asdlc_root"

  local status=0
  local out=""
  set +e
  out="$("$asdlc_root/.commands/project_register_worker.sh" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --path <asdlc/projects/<project-id>>."
}

test_register_worker_rejects_non_project_or_nested_path() {
  local asdlc_root="$TMP_ROOT/asdlc-invalid-path"
  setup_workspace "$asdlc_root"
  local project_dir=""
  project_dir="$(create_project_with_definition "$asdlc_root" "demo-project" "demo-project")"
  mkdir -p "$project_dir/feature-a"

  local status=0
  local out=""
  set +e
  out="$(
    printf '1\n' | "$asdlc_root/.commands/project_register_worker.sh" --path "$asdlc_root" 2>&1
  )"
  status=$?
  set -e
  assert_nonzero_status "$status"
  assert_contains "$out" "Project path must resolve to asdlc/projects/<project-id>"

  status=0
  out=""
  set +e
  out="$(
    printf '1\n' | "$asdlc_root/.commands/project_register_worker.sh" --path "$project_dir/feature-a" 2>&1
  )"
  status=$?
  set -e
  assert_nonzero_status "$status"
  assert_contains "$out" "Project path must resolve to asdlc/projects/<project-id>"
}

test_register_worker_fails_when_project_metadata_missing_or_incomplete() {
  local asdlc_root="$TMP_ROOT/asdlc-missing-metadata"
  setup_workspace "$asdlc_root"
  local missing_definition_dir="$asdlc_root/projects/no-definition"
  mkdir -p "$missing_definition_dir"

  local status=0
  local out=""
  set +e
  out="$(
    printf '1\n' | "$asdlc_root/.commands/project_register_worker.sh" --path "$missing_definition_dir" 2>&1
  )"
  status=$?
  set -e
  assert_nonzero_status "$status"
  assert_contains "$out" "Project definition metadata is required"

  local missing_project_id_dir="$asdlc_root/projects/no-project-id"
  mkdir -p "$missing_project_id_dir"
  cat >"$missing_project_id_dir/init_progress_definition.yaml" <<'EOF'
meta_info:
  project_classes:
    - backend
steps: []
EOF

  status=0
  out=""
  set +e
  out="$(
    printf '1\n' | "$asdlc_root/.commands/project_register_worker.sh" --path "$missing_project_id_dir" 2>&1
  )"
  status=$?
  set -e
  assert_nonzero_status "$status"
  assert_contains "$out" "Canonical project_id metadata is required"
}

test_register_worker_creates_workers_file_and_persists_normalized_active_entry() {
  local asdlc_root="$TMP_ROOT/asdlc-first-registration"
  setup_workspace "$asdlc_root"
  local project_dir=""
  local workers_path=""
  local out=""
  local worker_uuid=""
  local worker_class=""
  local worker_status=""
  local registered_at=""
  local last_line=""

  project_dir="$(create_project_with_definition "$asdlc_root" "billing-api-123" "billing-api-123")"
  workers_path="$project_dir/workers.yaml"

  out="$(
    cd "$TMP_ROOT" &&
    printf 'BACKEND\n' | "$asdlc_root/.commands/project_register_worker.sh" --path "projects/billing-api-123" 2>&1
  )"

  assert_file_exists "$workers_path"
  assert_contains "$(cat "$workers_path")" 'project_id: "billing-api-123"'
  assert_contains "$(cat "$workers_path")" "workers:"
  assert_equal "1" "$(count_registered_workers "$workers_path")"

  worker_uuid="$(extract_last_worker_uuid "$workers_path")"
  worker_class="$(extract_last_worker_class "$workers_path")"
  worker_status="$(extract_last_worker_status "$workers_path")"
  registered_at="$(extract_last_registered_at "$workers_path")"
  last_line="$(extract_last_nonempty_line "$out")"

  assert_matches "$worker_uuid" '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  assert_equal "backend" "$worker_class"
  assert_equal "active" "$worker_status"
  assert_matches "$registered_at" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
  assert_equal "new worker registered with uuid: $worker_uuid - copy and pass this unique id to developer so he'll register worker on he's side" "$last_line"
}

test_register_worker_retries_invalid_class_and_appends_on_repeat_runs() {
  local asdlc_root="$TMP_ROOT/asdlc-repeat-registration"
  setup_workspace "$asdlc_root"
  local project_dir=""
  local workers_path=""
  local first_out=""
  local second_out=""
  local first_uuid=""
  local second_uuid=""
  local invalid_count=""
  local last_line=""

  project_dir="$(create_project_with_definition "$asdlc_root" "search-app-444" "search-app-444")"
  workers_path="$project_dir/workers.yaml"

  first_out="$(
    printf 'unknown\n\n2\n' | "$asdlc_root/.commands/project_register_worker.sh" --path "$project_dir" 2>&1
  )"
  invalid_count="$(count_occurrences "$first_out" "Invalid selection. Enter 1, 2, 3, or 4 (backend/frontend/mobile/infrastructure).")"
  assert_equal "2" "$invalid_count"
  assert_equal "1" "$(count_registered_workers "$workers_path")"
  first_uuid="$(extract_last_worker_uuid "$workers_path")"
  assert_equal "frontend" "$(extract_last_worker_class "$workers_path")"

  second_out="$(
    printf '4\n' | "$asdlc_root/.commands/project_register_worker.sh" --path "$project_dir" 2>&1
  )"
  assert_equal "2" "$(count_registered_workers "$workers_path")"
  second_uuid="$(extract_last_worker_uuid "$workers_path")"
  assert_matches "$second_uuid" '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  if [[ "$first_uuid" == "$second_uuid" ]]; then
    echo "Assertion failed: expected unique UUIDs across registrations" >&2
    exit 1
  fi
  assert_contains "$(cat "$workers_path")" "uuid: \"$first_uuid\""
  assert_contains "$(cat "$workers_path")" "project_id: \"search-app-444\""
  assert_equal "infrastructure" "$(extract_last_worker_class "$workers_path")"
  assert_equal "active" "$(extract_last_worker_status "$workers_path")"

  last_line="$(extract_last_nonempty_line "$second_out")"
  assert_equal "new worker registered with uuid: $second_uuid - copy and pass this unique id to developer so he'll register worker on he's side" "$last_line"
}

test_register_worker_preserves_existing_workers_file_and_appends_once() {
  local asdlc_root="$TMP_ROOT/asdlc-preserve-existing"
  setup_workspace "$asdlc_root"
  local project_dir=""
  local workers_path=""
  local status=0
  local out=""

  project_dir="$(create_project_with_definition "$asdlc_root" "infra-core-888" "infra-core-888")"
  workers_path="$project_dir/workers.yaml"
  cat >"$workers_path" <<'EOF'
project_id: "infra-core-888"
workers:
  - uuid: "11111111-1111-1111-1111-111111111111"
    class: "backend"
    status: "active"
    registered_at: "2026-01-01T00:00:00Z"
EOF

  out="$(
    printf 'mobile\n' | "$asdlc_root/.commands/project_register_worker.sh" --path "$project_dir" 2>&1
  )"

  assert_equal "2" "$(count_registered_workers "$workers_path")"
  assert_contains "$(cat "$workers_path")" 'uuid: "11111111-1111-1111-1111-111111111111"'
  assert_equal "mobile" "$(extract_last_worker_class "$workers_path")"
  assert_contains "$out" "new worker registered with uuid:"

  cat >"$workers_path" <<'EOF'
project_id: "different-project"
workers:
EOF

  set +e
  out="$(
    printf '1\n' | "$asdlc_root/.commands/project_register_worker.sh" --path "$project_dir" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "workers registry project_id mismatch"
}

test_register_worker_rejects_workers_file_without_required_keys() {
  local asdlc_root="$TMP_ROOT/asdlc-malformed-workers"
  setup_workspace "$asdlc_root"
  local project_dir=""
  local workers_path=""
  local status=0
  local out=""

  project_dir="$(create_project_with_definition "$asdlc_root" "malformed-001" "malformed-001")"
  workers_path="$project_dir/workers.yaml"

  cat >"$workers_path" <<'EOF'
project_id: "malformed-001"
items:
  - bad: true
EOF

  set +e
  out="$(
    printf '1\n' | "$asdlc_root/.commands/project_register_worker.sh" --path "$project_dir" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "workers registry must contain top-level 'workers:' collection"
}

test_register_worker_rejects_missing_workers_project_id_key() {
  local asdlc_root="$TMP_ROOT/asdlc-workers-no-project-id"
  setup_workspace "$asdlc_root"
  local project_dir=""
  local workers_path=""
  local status=0
  local out=""

  project_dir="$(create_project_with_definition "$asdlc_root" "workers-no-project-id-001" "workers-no-project-id-001")"
  workers_path="$project_dir/workers.yaml"

  cat >"$workers_path" <<'EOF'
workers:
EOF

  set +e
  out="$(
    printf '1\n' | "$asdlc_root/.commands/project_register_worker.sh" --path "$project_dir" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "workers registry must contain top-level project_id"
}

test_register_worker_rejects_missing_path_argument
test_register_worker_rejects_non_project_or_nested_path
test_register_worker_fails_when_project_metadata_missing_or_incomplete
test_register_worker_creates_workers_file_and_persists_normalized_active_entry
test_register_worker_retries_invalid_class_and_appends_on_repeat_runs
test_register_worker_preserves_existing_workers_file_and_appends_once
test_register_worker_rejects_workers_file_without_required_keys
test_register_worker_rejects_missing_workers_project_id_key

echo "All register_worker script tests passed."
