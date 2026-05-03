#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
FEATURE_PATH_INPUT=""
FEATURE_PATH=""
FEATURE_BR_FILE=""
MODELS_FILE=".setup/models.md"
RULE_FILE=".rules/repo_br_scan_rule.md"
REPO_GATE_HELPER=".helper/check_business_context_filled_from_repo.sh"
MODEL_PHASE="repo_analyse"
PROJECT_DEFINITION_FILE=""
REPO_PATHS=()
REPO_CONTEXT_LINES=()

die() {
  echo "ERROR: $*" >&2
  exit 1
}

fail_project_type_undefined() {
  echo "unable to define project type" >&2
  exit 1
}

fail_new_project_not_applicable() {
  echo "for new projects repo scan not applicable" >&2
  exit 1
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    die "Required command not found: $command_name"
  fi
}

trim_value() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

strip_quotes() {
  local value="$1"
  value="$(trim_value "$value")"
  if [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "$(trim_value "$value")"
}

array_contains() {
  local needle="$1"
  shift || true
  local item=""
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
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

resolve_runtime_root() {
  local script_dir=""
  local parent_dir=""

  if ! script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; then
    die "Failed to resolve script directory."
  fi
  parent_dir="$(dirname "$script_dir")"

  if [[ "$(basename "$script_dir")" != ".commands" || ! -f "$parent_dir/asdlc_metadata.yaml" ]]; then
    die "Run this command from ASDLC staged path: <asdlc>/.commands/$SCRIPT_BASENAME"
  fi

  if ! git -C "$parent_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "ASDLC workspace is not a git repository: $parent_dir"
  fi

  printf '%s' "$parent_dir"
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

resolve_definition_file_from_ancestor() {
  local runtime_root="$1"
  local search_dir="$runtime_root/$FEATURE_PATH"
  local candidate=""

  while true; do
    candidate="$search_dir/init_progress_definition.yaml"
    if [[ -f "$candidate" ]]; then
      PROJECT_DEFINITION_FILE="${candidate#"$runtime_root/"}"
      return 0
    fi

    if [[ "$search_dir" == "$runtime_root" ]]; then
      break
    fi

    search_dir="$(dirname "$search_dir")"
    case "$search_dir" in
    "$runtime_root"|"$runtime_root"/*)
      ;;
    *)
      break
      ;;
    esac
  done

  die "Required file not found: <path ancestor>/init_progress_definition.yaml (path: $FEATURE_PATH)"
}

set_artifact_paths() {
  FEATURE_BR_FILE="$FEATURE_PATH/feature_br_summary.md"
}

ensure_feature_summary_exists() {
  local runtime_root="$1"

  if [[ ! -f "$runtime_root/$FEATURE_BR_FILE" ]]; then
    die "Required file not found: $FEATURE_BR_FILE"
  fi
}

extract_project_type_code() {
  local feature_br_path="$1"
  local code=""

  if [[ ! -f "$feature_br_path" ]]; then
    fail_project_type_undefined
  fi

  code="$(
    awk '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
{
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*/, "", line)
  if (line ~ /^project_type_code[[:space:]]*:/) {
    sub(/^project_type_code[[:space:]]*:[[:space:]]*/, "", line)
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

  if [[ -z "${code:-}" || "$code" == "[UNFILLED]" ]]; then
    fail_project_type_undefined
  fi

  printf '%s' "$code"
}

extract_meta_class_repo_path_entries() {
  local definition_path="$1"

  awk '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
function strip_yaml_quotes(v) {
  v = trim(v)
  if ((v ~ /^".*"$/) || (v ~ /^'\''.*'\''$/)) {
    v = substr(v, 2, length(v) - 2)
  }
  return trim(v)
}
function flush_entry() {
  if (current_class != "") {
    print current_class "|" current_state "|" current_path
  }
  current_class = ""
  current_state = ""
  current_path = ""
}
BEGIN {
  in_meta = 0
  in_paths = 0
  current_class = ""
  current_state = ""
  current_path = ""
}
/^meta_info:[[:space:]]*$/ {
  in_meta = 1
  next
}
/^steps:[[:space:]]*$/ {
  if (in_meta == 1) {
    flush_entry()
    exit 0
  }
}
{
  if (in_meta == 0) {
    next
  }

  if (in_paths == 0) {
    if ($0 ~ /^[[:space:]]{2}class_repo_paths:[[:space:]]*\{\}[[:space:]]*$/) {
      exit 0
    }
    if ($0 ~ /^[[:space:]]{2}class_repo_paths:[[:space:]]*$/) {
      in_paths = 1
      next
    }
    next
  }

  if ($0 ~ /^[[:space:]]{2}[A-Za-z0-9_.-]+:[[:space:]]*$/) {
    flush_entry()
    exit 0
  }

  if ($0 ~ /^[[:space:]]{4}[A-Za-z0-9_.-]+:[[:space:]]*$/) {
    flush_entry()
    line = $0
    sub(/^[[:space:]]{4}/, "", line)
    sub(/:[[:space:]]*$/, "", line)
    current_class = trim(line)
    next
  }

  if (current_class != "" && $0 ~ /^[[:space:]]{6}state:[[:space:]]*/) {
    line = $0
    sub(/^[[:space:]]{6}state:[[:space:]]*/, "", line)
    current_state = strip_yaml_quotes(line)
    next
  }

  if (current_class != "" && $0 ~ /^[[:space:]]{6}path:[[:space:]]*/) {
    line = $0
    sub(/^[[:space:]]{6}path:[[:space:]]*/, "", line)
    current_path = strip_yaml_quotes(line)
    next
  }
}
END {
  flush_entry()
}
' "$definition_path"
}

collect_usable_repo_paths() {
  local definition_path="$1"
  local parsed_entries=""
  local entry=""
  local class_name=""
  local class_state=""
  local class_path=""
  local normalized_state=""
  local normalized_path=""
  local resolved_path=""

  REPO_PATHS=()
  REPO_CONTEXT_LINES=()

  if ! parsed_entries="$(extract_meta_class_repo_path_entries "$definition_path" 2>/dev/null)"; then
    die "Failed to read meta_info.class_repo_paths from $PROJECT_DEFINITION_FILE."
  fi

  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    IFS='|' read -r class_name class_state class_path <<<"$entry"

    class_name="$(trim_value "$class_name")"
    normalized_state="$(printf '%s' "$(trim_value "$class_state")" | tr '[:upper:]' '[:lower:]')"
    normalized_path="$(strip_quotes "$class_path")"
    [[ -n "$class_name" ]] || continue

    if [[ "$normalized_state" != "ready" ]]; then
      continue
    fi

    if [[ -z "$normalized_path" ]]; then
      die "Repo path for class '$class_name' is marked ready but path is empty in $PROJECT_DEFINITION_FILE."
    fi

    if [[ ! -d "$normalized_path" ]]; then
      die "Repo path for class '$class_name' does not exist or is not a directory: $normalized_path"
    fi

    if ! resolved_path="$(cd "$normalized_path" && pwd)"; then
      die "Failed to resolve repo path for class '$class_name': $normalized_path"
    fi

    if ! array_contains "$resolved_path" "${REPO_PATHS[@]-}"; then
      REPO_PATHS+=("$resolved_path")
      REPO_CONTEXT_LINES+=("- $class_name: $resolved_path")
    fi
  done <<<"$parsed_entries"

  if [[ ${#REPO_PATHS[@]} -eq 0 ]]; then
    die "No usable repository paths found in meta_info.class_repo_paths (state: ready with existing directories required)."
  fi
}

render_repo_context_lines() {
  local line=""
  for line in "${REPO_CONTEXT_LINES[@]}"; do
    printf '%s\n' "$line"
  done
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
  local runtime_root="$1"
  local project_type_code="$2"
  local definition_file="$3"
  local repo_context_lines=""
  local gate_command="$REPO_GATE_HELPER $FEATURE_BR_FILE"

  repo_context_lines="$(render_repo_context_lines)"

  cat <<EOF_PROMPT
Analyze configured project repositories and update $FEATURE_BR_FILE.

Hard constraints:
- Update $FEATURE_BR_FILE in place (no alternate output file).
- Preserve section order and key structure in the target artifact.
- Use repository evidence; do not invent unsupported claims.
- Read and follow the prompt rules in $RULE_FILE before editing.
- Treat $RULE_FILE as authoritative for repository-scan enrichment behavior.
- Follow Gate sections defined in $RULE_FILE. Gate section completeion is mandatory, when it's complete - repository-scan enrichment phase is fully complete.
- When repository-scan enrichment phase is fully complete, end your final response with this exact last line: "Repo scan phase to enrich BR is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase"

Context:
- ASDLC workspace root: $runtime_root
- Project type code: $project_type_code
- Runtime path bindings are authoritative for this invocation.
- Feature artifact root: $FEATURE_PATH
- Target artifact: $FEATURE_BR_FILE
- Project definition file: $definition_file
- Repositories to scan (meta_info.class_repo_paths with state=ready):
$repo_context_lines
- Do not analyze files outside listed repositories.
- Repo-scan gate helper command: $gate_command

Rule prompt file:
- Read directly from repo.
- Path: $RULE_FILE
EOF_PROMPT
}

commit_feature_br_summary_if_changed() {
  local runtime_root="$1"

  if ! git -C "$runtime_root" add "$FEATURE_BR_FILE"; then
    die "Failed to stage $FEATURE_BR_FILE."
  fi

  if git -C "$runtime_root" diff --cached --quiet -- "$FEATURE_BR_FILE"; then
    return 0
  fi

  if ! git -C "$runtime_root" commit -m "Update feature BR summary from repo scan" -- "$FEATURE_BR_FILE" >/dev/null 2>&1; then
    die "Failed to commit $FEATURE_BR_FILE."
  fi
}

main() {
  require_command git
  parse_args "$@"

  local runtime_root=""
  runtime_root="$(resolve_runtime_root)"
  resolve_feature_path "$runtime_root" "$FEATURE_PATH_INPUT"
  set_artifact_paths
  ensure_feature_summary_exists "$runtime_root"
  resolve_definition_file_from_ancestor "$runtime_root"

  local models_path="$runtime_root/$MODELS_FILE"
  local rule_path="$runtime_root/$RULE_FILE"
  local project_type_code=""
  local prompt_arg=""

  if [[ ! -f "$rule_path" ]]; then
    die "Rules file not found: $RULE_FILE"
  fi

  project_type_code="$(extract_project_type_code "$runtime_root/$FEATURE_BR_FILE")"
  if [[ "$project_type_code" == "A" ]]; then
    fail_new_project_not_applicable
  fi
  collect_usable_repo_paths "$runtime_root/$PROJECT_DEFINITION_FILE"

  load_model_config "$models_path" "$MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  prompt_arg="$(build_prompt "$runtime_root" "$project_type_code" "$PROJECT_DEFINITION_FILE")"

  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi
  cmd+=("$prompt_arg")

  (
    cd "$runtime_root"
    "${cmd[@]}"
  )

  if [[ ! -f "$runtime_root/$FEATURE_BR_FILE" ]]; then
    die "Model run did not produce required file: $FEATURE_BR_FILE"
  fi

  commit_feature_br_summary_if_changed "$runtime_root"
  echo "Updated $FEATURE_BR_FILE"
}

main "$@"
