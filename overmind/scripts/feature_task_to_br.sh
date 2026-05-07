#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
FEATURE_PATH_INPUT=""
FEATURE_PATH=""
FEATURE_BR_FILE=""
USER_INPUT_FILE=""
MISSING_DATA_FILE=""
MODELS_FILE=".setup/models.md"
EXTERNAL_SOURCES_FILE=".setup/external_sources.yaml"
RULE_FILE=".rules/task_to_br_rule.md"
HELPER_SCRIPT=".helper/check_task_to_br_quality.sh"
MISSING_TEMPLATE_FILE=".templates/missing_br_data_TEMPLATE.md"
MISSING_GOLDEN_EXAMPLE_FILE=".golden_examples/missing_br_data_GOLDEN_EXAMPLE.md"
SCAFFOLD_HINT_SCRIPT=".commands/feature_br_scaffold.sh"
MODEL_PHASE="task_to_br"

MODEL_CMD=""
MODEL_MODEL=""
MODEL_ARGS=()

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    die "Required command not found: $command_name"
  fi
}

ensure_staged_command_runtime() {
  local script_dir=""
  local parent_dir=""

  if ! script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; then
    die "Failed to resolve script directory."
  fi
  parent_dir="$(dirname "$script_dir")"

  if [[ "$(basename "$script_dir")" != ".commands" || ! -f "$parent_dir/asdlc_metadata.yaml" ]]; then
    die "Run this command from ASDLC staged path: <asdlc>/.commands/$SCRIPT_BASENAME"
  fi

  printf '%s' "$parent_dir"
}

normalize_feature_path() {
  local raw_path="${1:-}"
  local normalized="$raw_path"

  normalized="${normalized#./}"
  while [[ "$normalized" == */ ]]; do
    normalized="${normalized%/}"
  done

  if [[ -z "$normalized" ]]; then
    die "feature_path must not be empty."
  fi

  printf '%s' "$normalized"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --feature_path)
      shift
      [[ $# -gt 0 ]] || die "Missing value for --feature_path."
      FEATURE_PATH_INPUT="$(normalize_feature_path "$1")"
      ;;
    *)
      die "Unknown argument: $1"
      ;;
    esac
    shift
  done

  [[ -n "$FEATURE_PATH_INPUT" ]] || die "Missing required argument: --feature_path <feature-folder-path>."
}

set_artifact_paths() {
  FEATURE_BR_FILE="$FEATURE_PATH/feature_br_summary.md"
  USER_INPUT_FILE="$FEATURE_PATH/user_br_input.md"
  MISSING_DATA_FILE="$FEATURE_PATH/missing_br_data.md"
}

resolve_feature_path() {
  local runtime_root="$1"
  local input_path="$2"
  local candidate_path=""
  local resolved_path=""

  if [[ "$input_path" = /* ]]; then
    candidate_path="$input_path"
  else
    candidate_path="$runtime_root/$input_path"
  fi

  if [[ ! -d "$candidate_path" ]]; then
    die "Feature path directory not found: $input_path"
  fi

  if ! resolved_path="$(cd "$candidate_path" && pwd -P)"; then
    die "Failed to resolve feature path: $input_path"
  fi

  case "$resolved_path" in
  "$runtime_root"/*)
    ;;
  *)
    die "Feature path must resolve inside ASDLC workspace: $resolved_path"
    ;;
  esac

  FEATURE_PATH="${resolved_path#"$runtime_root/"}"
}

ensure_feature_summary_exists() {
  local runtime_root="$1"
  local feature_br_path="$runtime_root/$FEATURE_BR_FILE"

  if [[ ! -f "$feature_br_path" ]]; then
    die "Required file not found: $FEATURE_BR_FILE. Run $SCAFFOLD_HINT_SCRIPT first."
  fi
}

trim_value() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

prompt_required_input() {
  local prompt="$1"
  local value=""

  while true; do
    printf '%s ' "$prompt" >&2
    if ! IFS= read -r value; then
      die "User input aborted."
    fi
    value="$(trim_value "$value")"
    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return 0
    fi
    echo "Input cannot be empty." >&2
  done
}

prompt_input_source_choice() {
  local choice=""

  while true; do
    printf 'Select input source:\n' >&2
    printf '  1) Provide a local file path\n' >&2
    printf '  2) Use Jira MCP ticket number (requires Jira MCP configured in your model environment)\n' >&2
    printf 'Choice [1/2]: ' >&2
    if ! IFS= read -r choice; then
      die "User input aborted."
    fi
    choice="$(trim_value "$choice")"
    case "$choice" in
      1|2) printf '%s' "$choice"; return 0 ;;
      *) echo "Invalid choice. Please enter 1 or 2." >&2 ;;
    esac
  done
}

prompt_jira_ticket_number() {
  prompt_required_input "Jira ticket number (e.g. PROJ-123):"
}

to_repo_relative_path() {
  local repo_root="$1"
  local absolute_path="$2"

  if [[ "$absolute_path" == "$repo_root/"* ]]; then
    printf '%s' "${absolute_path#"$repo_root/"}"
    return 0
  fi

  printf '%s' "$absolute_path"
}

validate_epic_story_source_file() {
  local repo_root="$1"
  local source_input="$2"
  local normalized_input="$source_input"
  local candidate_path=""
  local candidate_dir=""
  local candidate_file=""
  local resolved_dir=""
  local resolved_path=""
  local feature_root=""
  local resolved_feature_root=""
  local inside_feature_root="no"

  if [[ "$source_input" != *.txt && "$source_input" != *.md ]]; then
    echo "Epic/Story source file must use .txt or .md extension." >&2
    return 1
  fi

  normalized_input="${normalized_input#./}"

  if [[ "$normalized_input" = /* ]]; then
    candidate_path="$normalized_input"
  elif [[ "$normalized_input" == "$FEATURE_PATH"/* ]]; then
    candidate_path="$repo_root/$normalized_input"
  else
    candidate_path="$repo_root/$FEATURE_PATH/$normalized_input"
  fi

  candidate_dir="$(dirname "$candidate_path")"
  candidate_file="$(basename "$candidate_path")"

  if [[ ! -d "$candidate_dir" ]]; then
    echo "Epic/Story source directory not found: $candidate_dir" >&2
    return 1
  fi

  if ! resolved_dir="$(cd "$candidate_dir" && pwd -P)"; then
    echo "Unable to resolve Epic/Story source path: $source_input" >&2
    return 1
  fi
  resolved_path="$resolved_dir/$candidate_file"

  feature_root="$repo_root/$FEATURE_PATH"
  if [[ -d "$feature_root" ]]; then
    if resolved_feature_root="$(cd "$feature_root" && pwd -P)"; then
      if [[ "$resolved_path" == "$resolved_feature_root/"* ]]; then
        inside_feature_root="yes"
      fi
    fi
  fi

  if [[ "$inside_feature_root" != "yes" ]]; then
    echo "Epic/Story source file must be inside feature path root: $FEATURE_PATH" >&2
    return 1
  fi

  if [[ ! -f "$resolved_path" ]]; then
    echo "Epic/Story source file not found: $resolved_path" >&2
    return 1
  fi

  if [[ ! -s "$resolved_path" ]]; then
    echo "Epic/Story source file exists but it's empty: $resolved_path" >&2
    return 1
  fi

  printf '%s' "$resolved_path"
}

prompt_epic_story_source_file() {
  local repo_root="$1"
  local source_input=""
  local resolved_path=""

  while true; do
    source_input="$(prompt_required_input "Epic/Story source file path (inside feature path root, .txt/.md):")"
    if resolved_path="$(validate_epic_story_source_file "$repo_root" "$source_input")"; then
      printf '%s' "$resolved_path"
      return 0
    fi
    echo "Please provide a valid path/to/file.txt or path/to/file.md inside feature path root." >&2
  done
}

extract_project_type_code() {
  local feature_br_path="$1"
  extract_required_meta_from_feature_br "$feature_br_path" "project_type_code" "project type code"
}

extract_optional_meta_from_feature_br() {
  local feature_br_path="$1"
  local target_key="$2"
  local value=""

  if [[ ! -f "$feature_br_path" ]]; then
    die "Required file not found: $FEATURE_BR_FILE. Run $SCAFFOLD_HINT_SCRIPT first."
  fi

  value="$(
    awk -v target_key="$target_key" '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
{
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*/, "", line)
  if (line ~ ("^" target_key "[[:space:]]*:")) {
    sub(("^" target_key "[[:space:]]*:[[:space:]]*"), "", line)
    line = trim(line)
    if ((line ~ /^".*"$/) || (line ~ /^'\''.*'\''$/)) {
      line = substr(line, 2, length(line) - 2)
    }
    print line
    exit
  }
}
' "$feature_br_path"
  )"

  printf '%s' "$value"
}

extract_required_meta_from_feature_br() {
  local feature_br_path="$1"
  local target_key="$2"
  local field_label="$3"
  local value=""

  value="$(extract_optional_meta_from_feature_br "$feature_br_path" "$target_key")"

  if [[ -z "${value:-}" || "$value" == "[UNFILLED]" ]]; then
    die "Unable to define $field_label from $FEATURE_BR_FILE."
  fi

  printf '%s' "$value"
}

ensure_required_files() {
  local repo_root="$1"
  local required_paths=(
    "$FEATURE_BR_FILE"
    "$MODELS_FILE"
    "$RULE_FILE"
    "$HELPER_SCRIPT"
    "$MISSING_TEMPLATE_FILE"
    "$MISSING_GOLDEN_EXAMPLE_FILE"
  )
  local relative_path=""

  for relative_path in "${required_paths[@]}"; do
    if [[ ! -f "$repo_root/$relative_path" ]]; then
      die "Required file not found: $relative_path"
    fi
  done
}

write_user_input_context() {
  local output_path="$1"
  local feature_id="$2"
  local feature_title="$3"
  local epic_story_source_file="$4"
  local epic_story="$5"
  local request_summary="$6"
  local extra_context="$7"
  local jira_ticket="${8:-}"
  local generated_on=""
  local line=""

  generated_on="$(date +%F)"
  mkdir -p "$(dirname "$output_path")"

  cat >"$output_path" <<EOF
# User Business Input

## 1. Capture Meta
- captured_at: $generated_on
EOF

  if [[ -n "$jira_ticket" ]]; then
    printf '%s\n' "- jira_ticket: $jira_ticket" >>"$output_path"
  fi

  cat >>"$output_path" <<EOF

## 2. Epic/Story Input
- feature_id: $feature_id
- feature_title: $feature_title
- epic_story_source_file: $epic_story_source_file
- epic_or_story: |
EOF

  while IFS= read -r line || [[ -n "$line" ]]; do
    printf '  %s\n' "$line" >>"$output_path"
  done <<<"$epic_story"

  cat >>"$output_path" <<EOF
- request_summary: $request_summary
- additional_business_context: $extra_context
EOF
}

extract_jira_source_names() {
  local sources_path="$1"

  if [[ ! -f "$sources_path" ]]; then
    return 0
  fi

  awk '
function trim(v) { sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v); return v }
function strip_quotes(v) {
  v = trim(v)
  if ((v ~ /^".*"$/) || (v ~ /^'\''.*'\''$/)) v = substr(v, 2, length(v)-2)
  return trim(v)
}
BEGIN { in_sources=0; cur_name=""; cur_type="" }
/^sources:[[:space:]]*\[\][[:space:]]*$/ { exit }
/^sources:[[:space:]]*$/ { in_sources=1; next }
in_sources {
  if (/^[^[:space:]#]/) {
    if (cur_name != "" && index(tolower(cur_type),"jira") > 0) print cur_name
    exit
  }
  if (/^[[:space:]]*-[[:space:]]*name:/) {
    if (cur_name != "" && index(tolower(cur_type),"jira") > 0) print cur_name
    line=$0; sub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*/,"",line)
    cur_name=strip_quotes(line); cur_type=""
  } else if (/^[[:space:]]+type:/) {
    line=$0; sub(/^[[:space:]]+type:[[:space:]]*/,"",line)
    cur_type=strip_quotes(line)
  }
}
END { if (cur_name != "" && index(tolower(cur_type),"jira") > 0) print cur_name }
' "$sources_path"
}

load_model_config() {
  local models_path="$1"
  local phase="$2"
  local fields=()
  local field=""

  if [[ ! -f "$models_path" ]]; then
    die "Models file not found: $MODELS_FILE"
  fi

  while IFS= read -r field; do
    fields+=("$field")
  done < <(
    awk -F'|' -v phase="$phase" '
      function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      /^[[:space:]]*#/ { next }
      NF < 3 { next }
      {
        key = trim($1)
        cmd = trim($2)
        model = trim($3)
        if (tolower(key) == tolower(phase)) {
          print cmd
          print model
          for (i = 4; i <= NF; i++) {
            arg = trim($i)
            if (arg != "") { print arg }
          }
          exit
        }
      }
    ' "$models_path"
  )

  if [[ ${#fields[@]} -lt 2 || -z "${fields[0]}" || -z "${fields[1]}" ]]; then
    die "Invalid or missing '$phase' entry in $MODELS_FILE (expected: $phase | codex | <model> | <args... optional>)"
  fi

  MODEL_CMD="${fields[0]}"
  MODEL_MODEL="${fields[1]}"
  MODEL_ARGS=()
  if [[ ${#fields[@]} -gt 2 ]]; then
    MODEL_ARGS=("${fields[@]:2}")
  fi
}

build_prompt() {
  local repo_root="$1"
  local project_type_code="$2"
  local feature_id="$3"
  local feature_title="$4"
  local epic_story_source_file="$5"
  local epic_story="$6"
  local request_summary="$7"
  local extra_context="$8"
  local jira_source_names="${9:-}"
  local gate_command="$HELPER_SCRIPT $FEATURE_BR_FILE"

  cat <<EOF
Update $FEATURE_BR_FILE using the captured user business input.

Hard constraints:
- Update $FEATURE_BR_FILE in place (no alternate output file).
- Preserve section order, headings, and field keys.
- Fill all sections as much as possible EXCEPT do not fill or edit \`## 13. Existing-System Context\`.
- Use only user-provided business context and the current BR content. Do not invent unsupported facts.
- Treat $USER_INPUT_FILE as the durable captured source-input artifact for this feature.
- Read and follow $RULE_FILE fully before editing.
- Treat $RULE_FILE as authoritative for this phase.
- When task-to-BR decomposition is complete, end your final response with this exact last line: "Task-to-BR phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase"

Context:
- Repository root: $repo_root
- Project type code: $project_type_code
- Runtime path bindings are authoritative for this invocation.
- Feature artifact root: $FEATURE_PATH
- Feature ID: $feature_id
- Feature title: $feature_title
- Captured user input file: $USER_INPUT_FILE
- Epic/Story source file: $epic_story_source_file
- Epic/Story input (from source file): $epic_story
- Business request summary: $request_summary
- Additional business context: $extra_context
- Target artifact: $FEATURE_BR_FILE
- Missing-data artifact: $MISSING_DATA_FILE
- Task-to-BR gate helper command: $gate_command

Instruction artifacts:
- Rule file: $RULE_FILE
- Missing-data template: $MISSING_TEMPLATE_FILE
- Missing-data golden example: $MISSING_GOLDEN_EXAMPLE_FILE
EOF

  if [[ "$epic_story_source_file" == jira:* ]]; then
    local jira_names_formatted=""
    local name=""
    while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      jira_names_formatted="${jira_names_formatted}
  - $name"
    done <<<"$jira_source_names"
    [[ -n "$jira_names_formatted" ]] || jira_names_formatted=" (none configured)"

    cat <<EOF

Jira MCP fetch instruction:
- Epic/story source is a Jira ticket: $epic_story_source_file
- External sources config: $EXTERNAL_SOURCES_FILE (read-only)
- Eligible Jira MCP source names:$jira_names_formatted
- Use one of the above named MCP servers to fetch the Jira ticket content and use it as the epic/story input.
- Before finalizing, update $USER_INPUT_FILE so \`## 2. Epic/Story Input -> epic_or_story\` contains the fetched Jira story text used for this run.
- Preserve the existing capture metadata in $USER_INPUT_FILE when adding the fetched Jira story text.
- If the eligible source list is empty, no listed MCP is reachable, or the ticket cannot be retrieved:
  ask the user what to do and mention that a local .txt or .md file can be provided instead.
EOF
  fi
}

main() {
  parse_args "$@"

  local repo_root=""
  repo_root="$(ensure_staged_command_runtime)"
  resolve_feature_path "$repo_root" "$FEATURE_PATH_INPUT"
  set_artifact_paths
  ensure_feature_summary_exists "$repo_root"
  ensure_required_files "$repo_root"

  local feature_br_path="$repo_root/$FEATURE_BR_FILE"
  local user_input_path="$repo_root/$USER_INPUT_FILE"
  local models_path="$repo_root/$MODELS_FILE"
  local project_type_code=""
  local prompt_arg=""
  local feature_id_input=""
  local feature_title_input=""
  local input_source_choice=""
  local epic_story_source_path=""
  local epic_story_source_rel=""
  local epic_story_input=""
  local jira_ticket_input=""
  local jira_source_names=""
  local request_summary_input=""
  local extra_context_input=""

  project_type_code="$(extract_project_type_code "$feature_br_path")"
  feature_id_input="$(extract_optional_meta_from_feature_br "$feature_br_path" "feature_id")"
  feature_title_input="$(extract_optional_meta_from_feature_br "$feature_br_path" "feature_title")"

  input_source_choice="$(prompt_input_source_choice)"

  if [[ "$input_source_choice" == "1" ]]; then
    epic_story_source_path="$(prompt_epic_story_source_file "$repo_root")"
    epic_story_source_rel="$(to_repo_relative_path "$repo_root" "$epic_story_source_path")"
    epic_story_input="$(cat "$epic_story_source_path")"
  else
    jira_ticket_input="$(prompt_jira_ticket_number)"
    epic_story_source_rel="jira:$jira_ticket_input"
    epic_story_input=""
    jira_source_names="$(extract_jira_source_names "$repo_root/$EXTERNAL_SOURCES_FILE")"
  fi

  request_summary_input="$feature_title_input"
  extra_context_input="[UNFILLED]"

  write_user_input_context \
    "$user_input_path" \
    "$feature_id_input" \
    "$feature_title_input" \
    "$epic_story_source_rel" \
    "$epic_story_input" \
    "$request_summary_input" \
    "$extra_context_input" \
    "$jira_ticket_input"

  load_model_config "$models_path" "$MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  prompt_arg="$(build_prompt \
    "$repo_root" \
    "$project_type_code" \
    "$feature_id_input" \
    "$feature_title_input" \
    "$epic_story_source_rel" \
    "$epic_story_input" \
    "$request_summary_input" \
    "$extra_context_input" \
    "$jira_source_names")"

  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi
  cmd+=("$prompt_arg")

  (
    cd "$repo_root"
    "${cmd[@]}"
  )

  if [[ ! -f "$feature_br_path" ]]; then
    die "Model run did not produce required file: $FEATURE_BR_FILE"
  fi

  echo "Updated $FEATURE_BR_FILE"
}

main "$@"
