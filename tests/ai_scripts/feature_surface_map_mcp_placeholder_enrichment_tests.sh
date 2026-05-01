#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/feature_surface_map_mcp_placeholder_enrichment.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PLACEHOLDER_LITERAL="<to be defined during implementation>"

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

assert_file_not_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    echo "Assertion failed: expected file to not exist: $path" >&2
    exit 1
  fi
}

assert_file_content_unchanged() {
  local original_content="$1"
  local file_path="$2"
  local actual_content
  actual_content="$(cat "$file_path")"
  if [[ "$original_content" != "$actual_content" ]]; then
    echo "Assertion failed: file content changed but should be unchanged: $file_path" >&2
    exit 1
  fi
}

setup_asdlc_workspace() {
  local asdlc_root="$1"

  mkdir -p "$asdlc_root/.commands" "$asdlc_root/.rules" "$asdlc_root/.helper" \
           "$asdlc_root/.setup" "$asdlc_root/projects/project-a"

  cp "$SCRIPT_SRC" "$asdlc_root/.commands/feature_surface_map_mcp_placeholder_enrichment.sh"
  chmod +x "$asdlc_root/.commands/feature_surface_map_mcp_placeholder_enrichment.sh"

  cat >"$asdlc_root/asdlc_metadata.yaml" <<'EOF'
meta:
  description: "test"
projects:
EOF

  cat >"$asdlc_root/.setup/models.md" <<'EOF'
feature_surface_map_mcp_placeholder_enrichment | codex | gpt-test | --config | model_reasoning_effort='high'
EOF

  cat >"$asdlc_root/.rules/feature_surface_map_mcp_placeholder_enrichment_rule.md" <<'EOF'
# MCP Placeholder Enrichment Rule
Test rule stub.
EOF

  cat >"$asdlc_root/.helper/check_feature_repo_surface_and_exec_context_be_quality.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$asdlc_root/.helper/check_feature_repo_surface_and_exec_context_be_quality.sh"

  cat >"$asdlc_root/.helper/check_feature_repo_surface_and_exec_context_fe_quality.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$asdlc_root/.helper/check_feature_repo_surface_and_exec_context_fe_quality.sh"

  cat >"$asdlc_root/projects/project-a/init_progress_definition.yaml" <<'EOF'
meta_info:
  project_id: "project-a"
  project_type_code: "A"
  project_type_label: "New project"
  project_classes: [backend]
  class_repo_paths: {}
steps: []
EOF

  (
    cd "$asdlc_root"
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"
    echo "seed" >README.md
    git add .
    git commit -qm "seed"
  )
}

write_codex_logging_stub() {
  local target_path="$1"
  local prompt_capture_file="$2"

  cat >"$target_path" <<STUB
#!/usr/bin/env bash
set -euo pipefail
# Capture the prompt (last non-flag arg) to the capture file
for arg in "\$@"; do :; done
printf '%s' "\${@: -1}" >"$prompt_capture_file"
STUB
  chmod +x "$target_path"
}

write_codex_modifying_stub() {
  local target_path="$1"
  local map_file_to_modify="$2"
  local replacement="$3"
  local prompt_capture_file="$4"

  cat >"$target_path" <<STUB
#!/usr/bin/env bash
set -euo pipefail
# Capture prompt
for arg in "\$@"; do :; done
printf '%s' "\${@: -1}" >"$prompt_capture_file"
# Simulate confirmed replacement by modifying the surface map
if [[ -f "$map_file_to_modify" ]]; then
  sed -i'' -e 's|<to be defined during implementation>|$replacement|g' "$map_file_to_modify" 2>/dev/null || \
    sed -i 's|<to be defined during implementation>|$replacement|g' "$map_file_to_modify"
fi
STUB
  chmod +x "$target_path"
}

write_external_sources_yaml() {
  local path="$1"
  shift
  # Each remaining arg is a source entry: "name|type"
  if [[ $# -eq 0 ]]; then
    printf 'sources: []\n' >"$path"
    return
  fi

  printf 'sources:\n' >"$path"
  for entry in "$@"; do
    local name="${entry%%|*}"
    local type="${entry#*|}"
    printf '  - name: %s\n    type: %s\n    description: test\n' "$name" "$type" >>"$path"
  done
}

# ---- Tests ----

test_absent_surface_maps_noop_without_calling_codex() {
  local asdlc_root="$TMP_ROOT/absent-maps"
  setup_asdlc_workspace "$asdlc_root"

  local feature_dir="$asdlc_root/projects/project-a/feature-x"
  mkdir -p "$feature_dir"

  write_external_sources_yaml "$asdlc_root/.setup/external_sources.yaml" "tech-standards-kb|stack_knowledge_base"

  local prompt_capture="$TMP_ROOT/absent-maps-prompt.txt"
  write_codex_logging_stub "$asdlc_root/.commands/codex" "$prompt_capture"

  local out=""
  out="$(cd "$asdlc_root" && PATH="$asdlc_root/.commands:$PATH" \
    .commands/feature_surface_map_mcp_placeholder_enrichment.sh \
    --feature_path projects/project-a/feature-x 2>&1)"

  assert_contains "$out" "No surface maps with placeholders found"
  if [[ -f "$prompt_capture" ]]; then
    echo "Assertion failed: codex should not have been called for absent surface maps" >&2
    exit 1
  fi
}

test_maps_without_placeholders_noop_without_calling_codex() {
  local asdlc_root="$TMP_ROOT/no-placeholders"
  setup_asdlc_workspace "$asdlc_root"

  local feature_dir="$asdlc_root/projects/project-a/feature-y"
  mkdir -p "$feature_dir"

  printf '# Backend map\ntransport_layer: GET /api/v1/items\n' >"$feature_dir/project_surface_struct_resp_map_backend.md"

  write_external_sources_yaml "$asdlc_root/.setup/external_sources.yaml" "tech-standards-kb|stack_knowledge_base"

  local prompt_capture="$TMP_ROOT/no-placeholders-prompt.txt"
  write_codex_logging_stub "$asdlc_root/.commands/codex" "$prompt_capture"

  local out=""
  out="$(cd "$asdlc_root" && PATH="$asdlc_root/.commands:$PATH" \
    .commands/feature_surface_map_mcp_placeholder_enrichment.sh \
    --feature_path projects/project-a/feature-y 2>&1)"

  assert_contains "$out" "No surface maps with placeholders found"
  if [[ -f "$prompt_capture" ]]; then
    echo "Assertion failed: codex should not have been called when no placeholders" >&2
    exit 1
  fi
}

test_empty_sources_list_noop_without_calling_codex() {
  local asdlc_root="$TMP_ROOT/empty-sources"
  setup_asdlc_workspace "$asdlc_root"

  local feature_dir="$asdlc_root/projects/project-a/feature-z"
  mkdir -p "$feature_dir"

  printf '# Backend map\ntransport_layer: <to be defined during implementation>\n' \
    >"$feature_dir/project_surface_struct_resp_map_backend.md"

  write_external_sources_yaml "$asdlc_root/.setup/external_sources.yaml"

  local prompt_capture="$TMP_ROOT/empty-sources-prompt.txt"
  write_codex_logging_stub "$asdlc_root/.commands/codex" "$prompt_capture"

  local out=""
  out="$(cd "$asdlc_root" && PATH="$asdlc_root/.commands:$PATH" \
    .commands/feature_surface_map_mcp_placeholder_enrichment.sh \
    --feature_path projects/project-a/feature-z 2>&1)"

  assert_contains "$out" "No eligible knowledge-base sources configured"
  if [[ -f "$prompt_capture" ]]; then
    echo "Assertion failed: codex should not have been called when no KB sources" >&2
    exit 1
  fi
}

test_non_kb_source_name_noop_without_calling_codex() {
  local asdlc_root="$TMP_ROOT/non-kb-source"
  setup_asdlc_workspace "$asdlc_root"

  local feature_dir="$asdlc_root/projects/project-a/feature-nkb"
  mkdir -p "$feature_dir"

  printf '# Backend map\ntransport_layer: <to be defined during implementation>\n' \
    >"$feature_dir/project_surface_struct_resp_map_backend.md"

  # Source name "api-design-guide" does not contain "knowledge" or "kb"
  write_external_sources_yaml "$asdlc_root/.setup/external_sources.yaml" \
    "api-design-guide|stack_knowledge_base"

  local prompt_capture="$TMP_ROOT/non-kb-source-prompt.txt"
  write_codex_logging_stub "$asdlc_root/.commands/codex" "$prompt_capture"

  local out=""
  out="$(cd "$asdlc_root" && PATH="$asdlc_root/.commands:$PATH" \
    .commands/feature_surface_map_mcp_placeholder_enrichment.sh \
    --feature_path projects/project-a/feature-nkb 2>&1)"

  assert_contains "$out" "No eligible knowledge-base sources configured"
  if [[ -f "$prompt_capture" ]]; then
    echo "Assertion failed: codex should not have been called for non-KB source name" >&2
    exit 1
  fi
}

test_kb_source_name_bound_into_prompt_after_placeholders_found() {
  local asdlc_root="$TMP_ROOT/kb-source-prompt"
  setup_asdlc_workspace "$asdlc_root"

  local feature_dir="$asdlc_root/projects/project-a/feature-kb"
  mkdir -p "$feature_dir"

  printf '# Backend map\ntransport_layer: <to be defined during implementation>\n' \
    >"$feature_dir/project_surface_struct_resp_map_backend.md"

  write_external_sources_yaml "$asdlc_root/.setup/external_sources.yaml" \
    "tech-standards-kb|stack_knowledge_base"

  local prompt_capture="$TMP_ROOT/kb-source-prompt.txt"
  write_codex_logging_stub "$asdlc_root/.commands/codex" "$prompt_capture"

  local out=""
  out="$(cd "$asdlc_root" && PATH="$asdlc_root/.commands:$PATH" \
    .commands/feature_surface_map_mcp_placeholder_enrichment.sh \
    --feature_path projects/project-a/feature-kb 2>&1)" || true

  assert_file_exists "$prompt_capture"
  local prompt_content
  prompt_content="$(cat "$prompt_capture")"
  assert_contains "$prompt_content" "tech-standards-kb"
  assert_contains "$prompt_content" "project_surface_struct_resp_map_backend"
}

test_kb_source_not_bound_before_placeholders_checked() {
  local asdlc_root="$TMP_ROOT/kb-no-placeholder-order"
  setup_asdlc_workspace "$asdlc_root"

  local feature_dir="$asdlc_root/projects/project-a/feature-kbno"
  mkdir -p "$feature_dir"

  # Map exists but has no placeholder
  printf '# Backend map\ntransport_layer: GET /api/v1/items\n' \
    >"$feature_dir/project_surface_struct_resp_map_backend.md"

  write_external_sources_yaml "$asdlc_root/.setup/external_sources.yaml" \
    "tech-standards-kb|stack_knowledge_base"

  local prompt_capture="$TMP_ROOT/kb-no-placeholder-order-prompt.txt"
  write_codex_logging_stub "$asdlc_root/.commands/codex" "$prompt_capture"

  local out=""
  out="$(cd "$asdlc_root" && PATH="$asdlc_root/.commands:$PATH" \
    .commands/feature_surface_map_mcp_placeholder_enrichment.sh \
    --feature_path projects/project-a/feature-kbno 2>&1)"

  # No placeholder → codex never called → source not in prompt
  assert_contains "$out" "No surface maps with placeholders found"
  if [[ -f "$prompt_capture" ]]; then
    echo "Assertion failed: codex must not be called before placeholders are confirmed" >&2
    exit 1
  fi
}

test_user_rejection_leaves_maps_unchanged() {
  local asdlc_root="$TMP_ROOT/user-reject"
  setup_asdlc_workspace "$asdlc_root"

  local feature_dir="$asdlc_root/projects/project-a/feature-reject"
  mkdir -p "$feature_dir"

  local original_content
  original_content="# Backend map
transport_layer: <to be defined during implementation>"
  printf '%s\n' "$original_content" >"$feature_dir/project_surface_struct_resp_map_backend.md"

  write_external_sources_yaml "$asdlc_root/.setup/external_sources.yaml" \
    "tech-standards-kb|stack_knowledge_base"

  local prompt_capture="$TMP_ROOT/user-reject-prompt.txt"
  # Stub that does NOT modify the map (simulates user declining all replacements)
  write_codex_logging_stub "$asdlc_root/.commands/codex" "$prompt_capture"

  local out=""
  out="$(cd "$asdlc_root" && PATH="$asdlc_root/.commands:$PATH" \
    .commands/feature_surface_map_mcp_placeholder_enrichment.sh \
    --feature_path projects/project-a/feature-reject 2>&1)" || true

  assert_file_content_unchanged "$original_content" \
    "$feature_dir/project_surface_struct_resp_map_backend.md"
}

test_user_confirmation_applies_placeholder_replacement() {
  local asdlc_root="$TMP_ROOT/user-confirm"
  setup_asdlc_workspace "$asdlc_root"

  local feature_dir="$asdlc_root/projects/project-a/feature-confirm"
  mkdir -p "$feature_dir"

  printf '# Backend map\ntransport_layer: <to be defined during implementation>\n' \
    >"$feature_dir/project_surface_struct_resp_map_backend.md"

  write_external_sources_yaml "$asdlc_root/.setup/external_sources.yaml" \
    "tech-standards-kb|stack_knowledge_base"

  local prompt_capture="$TMP_ROOT/user-confirm-prompt.txt"
  local map_abs="$asdlc_root/projects/project-a/feature-confirm/project_surface_struct_resp_map_backend.md"
  # Stub that modifies the map (simulates confirmed replacement)
  write_codex_modifying_stub "$asdlc_root/.commands/codex" "$map_abs" "REST" "$prompt_capture"

  local out=""
  out="$(cd "$asdlc_root" && PATH="$asdlc_root/.commands:$PATH" \
    .commands/feature_surface_map_mcp_placeholder_enrichment.sh \
    --feature_path projects/project-a/feature-confirm 2>&1)" || true

  local updated_content
  updated_content="$(cat "$feature_dir/project_surface_struct_resp_map_backend.md")"
  assert_not_contains "$updated_content" "<to be defined during implementation>"
  assert_contains "$updated_content" "REST"
}

test_confirmed_enrichment_commits_changed_surface_map() {
  local asdlc_root="$TMP_ROOT/user-confirm-commit"
  setup_asdlc_workspace "$asdlc_root"

  local feature_dir="$asdlc_root/projects/project-a/feature-confirm-commit"
  mkdir -p "$feature_dir"

  printf '# Backend map\ntransport_layer: <to be defined during implementation>\n' \
    >"$feature_dir/project_surface_struct_resp_map_backend.md"

  write_external_sources_yaml "$asdlc_root/.setup/external_sources.yaml" \
    "tech-standards-kb|stack_knowledge_base"

  local prompt_capture="$TMP_ROOT/user-confirm-commit-prompt.txt"
  local map_abs="$asdlc_root/projects/project-a/feature-confirm-commit/project_surface_struct_resp_map_backend.md"
  write_codex_modifying_stub "$asdlc_root/.commands/codex" "$map_abs" "REST" "$prompt_capture"

  local before_head=""
  before_head="$(git -C "$asdlc_root" rev-parse HEAD)"

  local out=""
  out="$(cd "$asdlc_root" && PATH="$asdlc_root/.commands:$PATH" \
    .commands/feature_surface_map_mcp_placeholder_enrichment.sh \
    --feature_path projects/project-a/feature-confirm-commit 2>&1)"

  local after_head=""
  after_head="$(git -C "$asdlc_root" rev-parse HEAD)"

  if [[ "$before_head" == "$after_head" ]]; then
    echo "Assertion failed: expected changed map to be committed" >&2
    exit 1
  fi
  assert_equal "Enrich surface-map placeholders with MCP" "$(git -C "$asdlc_root" log -1 --pretty=%s)"
  assert_contains "$(git -C "$asdlc_root" show --name-only --pretty=format: HEAD)" \
    "projects/project-a/feature-confirm-commit/project_surface_struct_resp_map_backend.md"
  assert_contains "$out" "Updated projects/project-a/feature-confirm-commit/project_surface_struct_resp_map_backend.md"
}

test_backend_quality_helper_referenced_in_prompt_for_backend_map() {
  local asdlc_root="$TMP_ROOT/quality-be"
  setup_asdlc_workspace "$asdlc_root"

  local feature_dir="$asdlc_root/projects/project-a/feature-qbe"
  mkdir -p "$feature_dir"

  printf '# Backend map\ntransport_layer: <to be defined during implementation>\n' \
    >"$feature_dir/project_surface_struct_resp_map_backend.md"

  write_external_sources_yaml "$asdlc_root/.setup/external_sources.yaml" \
    "tech-standards-kb|stack_knowledge_base"

  local prompt_capture="$TMP_ROOT/quality-be-prompt.txt"
  write_codex_logging_stub "$asdlc_root/.commands/codex" "$prompt_capture"

  local out=""
  out="$(cd "$asdlc_root" && PATH="$asdlc_root/.commands:$PATH" \
    .commands/feature_surface_map_mcp_placeholder_enrichment.sh \
    --feature_path projects/project-a/feature-qbe 2>&1)" || true

  assert_file_exists "$prompt_capture"
  local prompt_content
  prompt_content="$(cat "$prompt_capture")"
  assert_contains "$prompt_content" "check_feature_repo_surface_and_exec_context_be_quality.sh"
}

test_frontend_quality_helper_referenced_in_prompt_for_frontend_map() {
  local asdlc_root="$TMP_ROOT/quality-fe"
  setup_asdlc_workspace "$asdlc_root"

  local feature_dir="$asdlc_root/projects/project-a/feature-qfe"
  mkdir -p "$feature_dir"

  printf '# Frontend map\ntransport_layer: <to be defined during implementation>\n' \
    >"$feature_dir/project_surface_struct_resp_map_frontend.md"

  write_external_sources_yaml "$asdlc_root/.setup/external_sources.yaml" \
    "tech-standards-kb|stack_knowledge_base"

  local prompt_capture="$TMP_ROOT/quality-fe-prompt.txt"
  write_codex_logging_stub "$asdlc_root/.commands/codex" "$prompt_capture"

  local out=""
  out="$(cd "$asdlc_root" && PATH="$asdlc_root/.commands:$PATH" \
    .commands/feature_surface_map_mcp_placeholder_enrichment.sh \
    --feature_path projects/project-a/feature-qfe 2>&1)" || true

  assert_file_exists "$prompt_capture"
  local prompt_content
  prompt_content="$(cat "$prompt_capture")"
  # Frontend map quality_gate line should reference fe quality helper
  assert_contains "$prompt_content" "check_feature_repo_surface_and_exec_context_fe_quality.sh"
  # The frontend map entry must not reference the backend quality helper in its quality_gate field
  assert_not_contains "$prompt_content" "class: frontend
    quality_gate: .helper/check_feature_repo_surface_and_exec_context_be_quality.sh"
}

test_mobile_quality_helper_referenced_in_prompt_for_mobile_map() {
  local asdlc_root="$TMP_ROOT/quality-mb"
  setup_asdlc_workspace "$asdlc_root"

  local feature_dir="$asdlc_root/projects/project-a/feature-qmb"
  mkdir -p "$feature_dir"

  printf '# Mobile map\ntransport_layer: <to be defined during implementation>\n' \
    >"$feature_dir/project_surface_struct_resp_map_mobile.md"

  write_external_sources_yaml "$asdlc_root/.setup/external_sources.yaml" \
    "tech-standards-kb|stack_knowledge_base"

  local prompt_capture="$TMP_ROOT/quality-mb-prompt.txt"
  write_codex_logging_stub "$asdlc_root/.commands/codex" "$prompt_capture"

  local out=""
  out="$(cd "$asdlc_root" && PATH="$asdlc_root/.commands:$PATH" \
    .commands/feature_surface_map_mcp_placeholder_enrichment.sh \
    --feature_path projects/project-a/feature-qmb 2>&1)" || true

  assert_file_exists "$prompt_capture"
  local prompt_content
  prompt_content="$(cat "$prompt_capture")"
  # Mobile map quality_gate line should reference fe/mobile quality helper
  assert_contains "$prompt_content" "class: mobile
    quality_gate: .helper/check_feature_repo_surface_and_exec_context_fe_quality.sh"
}

test_confirmed_enrichment_flips_was_enriched_with_mcp_flag_to_true() {
  local asdlc_root="$TMP_ROOT/flag-flip"
  setup_asdlc_workspace "$asdlc_root"

  local feature_dir="$asdlc_root/projects/project-a/feature-flag-flip"
  mkdir -p "$feature_dir"

  printf '## 1. Document Meta\n- was_enriched_with_mcp: false\n\ntransport_layer: <to be defined during implementation>\n' \
    >"$feature_dir/project_surface_struct_resp_map_backend.md"

  write_external_sources_yaml "$asdlc_root/.setup/external_sources.yaml" \
    "tech-standards-kb|stack_knowledge_base"

  local prompt_capture="$TMP_ROOT/flag-flip-prompt.txt"
  local map_abs="$asdlc_root/projects/project-a/feature-flag-flip/project_surface_struct_resp_map_backend.md"
  write_codex_modifying_stub "$asdlc_root/.commands/codex" "$map_abs" "REST" "$prompt_capture"

  local out=""
  out="$(cd "$asdlc_root" && PATH="$asdlc_root/.commands:$PATH" \
    .commands/feature_surface_map_mcp_placeholder_enrichment.sh \
    --feature_path projects/project-a/feature-flag-flip 2>&1)" || true

  local flag_value
  flag_value="$(grep 'was_enriched_with_mcp' "$feature_dir/project_surface_struct_resp_map_backend.md" | head -1)"
  assert_contains "$flag_value" "was_enriched_with_mcp: true"
}

test_rejected_enrichment_leaves_was_enriched_with_mcp_flag_false() {
  local asdlc_root="$TMP_ROOT/flag-no-flip"
  setup_asdlc_workspace "$asdlc_root"

  local feature_dir="$asdlc_root/projects/project-a/feature-flag-no-flip"
  mkdir -p "$feature_dir"

  printf '## 1. Document Meta\n- was_enriched_with_mcp: false\n\ntransport_layer: <to be defined during implementation>\n' \
    >"$feature_dir/project_surface_struct_resp_map_backend.md"

  write_external_sources_yaml "$asdlc_root/.setup/external_sources.yaml" \
    "tech-standards-kb|stack_knowledge_base"

  local prompt_capture="$TMP_ROOT/flag-no-flip-prompt.txt"
  # Logging stub does not modify the map (simulates user declining all replacements)
  write_codex_logging_stub "$asdlc_root/.commands/codex" "$prompt_capture"

  local out=""
  out="$(cd "$asdlc_root" && PATH="$asdlc_root/.commands:$PATH" \
    .commands/feature_surface_map_mcp_placeholder_enrichment.sh \
    --feature_path projects/project-a/feature-flag-no-flip 2>&1)" || true

  local flag_value
  flag_value="$(grep 'was_enriched_with_mcp' "$feature_dir/project_surface_struct_resp_map_backend.md" | head -1)"
  assert_contains "$flag_value" "was_enriched_with_mcp: false"
}

test_missing_external_sources_file_fails_when_placeholders_exist() {
  local asdlc_root="$TMP_ROOT/missing-external-sources"
  setup_asdlc_workspace "$asdlc_root"

  local feature_dir="$asdlc_root/projects/project-a/feature-missing-sources"
  mkdir -p "$feature_dir"

  printf '# Backend map\ntransport_layer: <to be defined during implementation>\n' \
    >"$feature_dir/project_surface_struct_resp_map_backend.md"
  rm -f "$asdlc_root/.setup/external_sources.yaml"

  local status=0
  local out=""
  set +e
  out="$(cd "$asdlc_root" && .commands/feature_surface_map_mcp_placeholder_enrichment.sh \
    --feature_path projects/project-a/feature-missing-sources 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: .setup/external_sources.yaml"
}

test_missing_runtime_rule_fails_before_model_invocation() {
  local asdlc_root="$TMP_ROOT/missing-rule"
  setup_asdlc_workspace "$asdlc_root"

  local feature_dir="$asdlc_root/projects/project-a/feature-missing-rule"
  mkdir -p "$feature_dir"

  printf '# Backend map\ntransport_layer: <to be defined during implementation>\n' \
    >"$feature_dir/project_surface_struct_resp_map_backend.md"

  write_external_sources_yaml "$asdlc_root/.setup/external_sources.yaml" \
    "tech-standards-kb|stack_knowledge_base"
  rm -f "$asdlc_root/.rules/feature_surface_map_mcp_placeholder_enrichment_rule.md"

  local prompt_capture="$TMP_ROOT/missing-rule-prompt.txt"
  write_codex_logging_stub "$asdlc_root/.commands/codex" "$prompt_capture"

  local status=0
  local out=""
  set +e
  out="$(cd "$asdlc_root" && PATH="$asdlc_root/.commands:$PATH" \
    .commands/feature_surface_map_mcp_placeholder_enrichment.sh \
    --feature_path projects/project-a/feature-missing-rule 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: .rules/feature_surface_map_mcp_placeholder_enrichment_rule.md"
  assert_file_not_exists "$prompt_capture"
}

test_copied_command_outside_staged_path_fails() {
  local asdlc_root="$TMP_ROOT/copied-command"
  setup_asdlc_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/not-commands"
  cp "$SCRIPT_SRC" "$asdlc_root/not-commands/feature_surface_map_mcp_placeholder_enrichment.sh"
  chmod +x "$asdlc_root/not-commands/feature_surface_map_mcp_placeholder_enrichment.sh"

  local status=0
  local out=""
  set +e
  out="$(cd "$asdlc_root" && not-commands/feature_surface_map_mcp_placeholder_enrichment.sh \
    --feature_path projects/project-a/feature-copied 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Run this command from ASDLC staged path: <asdlc>/.commands/feature_surface_map_mcp_placeholder_enrichment.sh"
}

test_quality_helper_is_not_executed_by_orchestrator() {
  local asdlc_root="$TMP_ROOT/helper-not-executed"
  setup_asdlc_workspace "$asdlc_root"

  local feature_dir="$asdlc_root/projects/project-a/feature-helper-not-executed"
  mkdir -p "$feature_dir"

  printf '# Backend map\ntransport_layer: <to be defined during implementation>\n' \
    >"$feature_dir/project_surface_struct_resp_map_backend.md"

  write_external_sources_yaml "$asdlc_root/.setup/external_sources.yaml" \
    "tech-standards-kb|stack_knowledge_base"

  local helper_marker="$TMP_ROOT/helper-not-executed.marker"
  cat >"$asdlc_root/.helper/check_feature_repo_surface_and_exec_context_be_quality.sh" <<EOF
#!/usr/bin/env bash
touch "$helper_marker"
exit 99
EOF
  chmod +x "$asdlc_root/.helper/check_feature_repo_surface_and_exec_context_be_quality.sh"

  local prompt_capture="$TMP_ROOT/helper-not-executed-prompt.txt"
  write_codex_logging_stub "$asdlc_root/.commands/codex" "$prompt_capture"

  local out=""
  out="$(cd "$asdlc_root" && PATH="$asdlc_root/.commands:$PATH" \
    .commands/feature_surface_map_mcp_placeholder_enrichment.sh \
    --feature_path projects/project-a/feature-helper-not-executed 2>&1)"

  assert_file_exists "$prompt_capture"
  assert_contains "$(cat "$prompt_capture")" ".helper/check_feature_repo_surface_and_exec_context_be_quality.sh"
  assert_file_not_exists "$helper_marker"
  assert_contains "$out" "MCP placeholder enrichment complete"
}

test_requires_feature_path_argument() {
  local asdlc_root="$TMP_ROOT/missing-arg"
  setup_asdlc_workspace "$asdlc_root"

  local status=0
  local out=""
  set +e
  out="$(cd "$asdlc_root" && .commands/feature_surface_map_mcp_placeholder_enrichment.sh 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --feature_path"
}

# ---- Run all tests ----

echo "Running feature_surface_map_mcp_placeholder_enrichment_tests.sh ..."

test_absent_surface_maps_noop_without_calling_codex
echo "  PASS: absent surface maps no-op"

test_maps_without_placeholders_noop_without_calling_codex
echo "  PASS: maps without placeholders no-op"

test_empty_sources_list_noop_without_calling_codex
echo "  PASS: empty sources list no-op"

test_non_kb_source_name_noop_without_calling_codex
echo "  PASS: non-KB source name no-op"

test_kb_source_name_bound_into_prompt_after_placeholders_found
echo "  PASS: KB source name bound into prompt after placeholders found"

test_kb_source_not_bound_before_placeholders_checked
echo "  PASS: KB source not bound before placeholders checked"

test_user_rejection_leaves_maps_unchanged
echo "  PASS: user rejection leaves maps unchanged"

test_user_confirmation_applies_placeholder_replacement
echo "  PASS: user confirmation applies placeholder replacement"

test_confirmed_enrichment_commits_changed_surface_map
echo "  PASS: confirmed enrichment commits changed surface map"

test_backend_quality_helper_referenced_in_prompt_for_backend_map
echo "  PASS: backend quality helper referenced in prompt for backend map"

test_frontend_quality_helper_referenced_in_prompt_for_frontend_map
echo "  PASS: frontend quality helper referenced in prompt for frontend map"

test_mobile_quality_helper_referenced_in_prompt_for_mobile_map
echo "  PASS: mobile quality helper referenced in prompt for mobile map"

test_requires_feature_path_argument
echo "  PASS: requires --feature_path argument"

test_confirmed_enrichment_flips_was_enriched_with_mcp_flag_to_true
echo "  PASS: confirmed enrichment flips was_enriched_with_mcp to true"

test_rejected_enrichment_leaves_was_enriched_with_mcp_flag_false
echo "  PASS: rejected enrichment leaves was_enriched_with_mcp as false"

test_missing_external_sources_file_fails_when_placeholders_exist
echo "  PASS: missing external sources file fails when placeholders exist"

test_missing_runtime_rule_fails_before_model_invocation
echo "  PASS: missing runtime rule fails before model invocation"

test_copied_command_outside_staged_path_fails
echo "  PASS: copied command outside staged path fails"

test_quality_helper_is_not_executed_by_orchestrator
echo "  PASS: quality helper is not executed by orchestrator"

echo "All tests passed."
