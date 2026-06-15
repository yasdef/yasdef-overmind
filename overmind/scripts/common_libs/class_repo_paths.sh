#!/usr/bin/env bash

class_repo_paths_trim_value() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

class_repo_paths_extract_entries() {
  local definition_path="$1"
  local output_mode="${2:-}"

  awk -v output_mode="$output_mode" '
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
    if (output_mode == "include-policy") {
      print current_class "|" current_state "|" current_path "|" current_policy
    } else {
      print current_class "|" current_state "|" current_path
    }
  }
  current_class = ""
  current_state = ""
  current_path = ""
  current_policy = ""
}
BEGIN {
  in_meta = 0
  in_paths = 0
  current_class = ""
  current_state = ""
  current_path = ""
  current_policy = ""
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

  if (current_class != "" && $0 ~ /^[[:space:]]{6}policy:[[:space:]]*/) {
    line = $0
    sub(/^[[:space:]]{6}policy:[[:space:]]*/, "", line)
    current_policy = strip_yaml_quotes(line)
    next
  }
}
END {
  flush_entry()
}
' "$definition_path"
}

class_repo_paths_find_entry() {
  local definition_path="$1"
  local target_class="$2"
  local parsed_entries=""
  local entry=""
  local class_name=""
  local class_state=""
  local class_path=""
  local normalized_class=""

  if ! parsed_entries="$(class_repo_paths_extract_entries "$definition_path")"; then
    return 1
  fi

  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    IFS='|' read -r class_name class_state class_path <<<"$entry"
    normalized_class="$(printf '%s' "$(class_repo_paths_trim_value "$class_name")" | tr '[:upper:]' '[:lower:]')"
    if [[ "$normalized_class" == "$target_class" ]]; then
      printf '%s|%s\n' "$(class_repo_paths_trim_value "$class_state")" "$class_path"
      return 0
    fi
  done <<<"$parsed_entries"

  return 1
}

class_repo_paths_collect_ready_paths() {
  local definition_path="$1"
  local supported_classes_csv="${2:-}"
  local supported_classes=""
  local parsed_entries=""
  local entry=""
  local class_name=""
  local class_state=""
  local class_path=""
  local normalized_class=""
  local normalized_state=""
  local normalized_path=""
  local resolved_path=""
  local seen_paths=()
  local seen_path=""

  if [[ -z "${definition_path//[[:space:]]/}" ]]; then
    echo "class_repo_paths ready path resolution failed: definition path is required" >&2
    return 1
  fi
  if [[ ! -f "$definition_path" ]]; then
    echo "class_repo_paths ready path resolution failed: definition file not found: $definition_path" >&2
    return 1
  fi

  supported_classes="$(printf '%s' "$supported_classes_csv" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

  if ! parsed_entries="$(class_repo_paths_extract_entries "$definition_path" 2>/dev/null)"; then
    echo "class_repo_paths ready path resolution failed: could not read meta_info.class_repo_paths from $definition_path" >&2
    return 1
  fi

  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    IFS='|' read -r class_name class_state class_path <<<"$entry"

    class_name="$(class_repo_paths_trim_value "$class_name")"
    normalized_class="$(printf '%s' "$class_name" | tr '[:upper:]' '[:lower:]')"
    normalized_state="$(printf '%s' "$(class_repo_paths_trim_value "$class_state")" | tr '[:upper:]' '[:lower:]')"
    normalized_path="$(class_repo_paths_trim_value "$class_path")"
    [[ -n "$normalized_class" ]] || continue

    if [[ -n "$supported_classes" ]]; then
      case ",$supported_classes," in
        *",$normalized_class,"*) ;;
        *) continue ;;
      esac
    fi

    if [[ "$normalized_state" != "ready" ]]; then
      continue
    fi
    if [[ -z "$normalized_path" ]]; then
      echo "class_repo_paths ready path resolution failed for class '$class_name': ready state requires non-empty path" >&2
      return 1
    fi
    if [[ ! -d "$normalized_path" ]]; then
      echo "class_repo_paths ready path resolution failed for class '$class_name': path is not an existing directory: $normalized_path" >&2
      return 1
    fi
    if ! resolved_path="$(cd "$normalized_path" && pwd -P)"; then
      echo "class_repo_paths ready path resolution failed for class '$class_name': failed to resolve path: $normalized_path" >&2
      return 1
    fi

    for seen_path in "${seen_paths[@]-}"; do
      if [[ "$seen_path" == "$resolved_path" ]]; then
        resolved_path=""
        break
      fi
    done
    [[ -n "$resolved_path" ]] || continue

    seen_paths+=("$resolved_path")
    printf '%s|%s\n' "$normalized_class" "$resolved_path"
  done <<<"$parsed_entries"
}

class_repo_paths_validate_coherence() {
  local definition_path="$1"
  local target_class="${2:-}"
  local parsed_entries=""
  local entry=""
  local class_name=""
  local class_state=""
  local class_path=""
  local normalized_class=""
  local normalized_target_class=""
  local normalized_state=""
  local normalized_path=""
  local resolved_path=""
  local policy=""
  local matched=0

  if [[ -z "${definition_path//[[:space:]]/}" ]]; then
    echo "class_repo_paths coherence failed: definition path is required" >&2
    return 1
  fi
  if [[ ! -f "$definition_path" ]]; then
    echo "class_repo_paths coherence failed: definition file not found: $definition_path" >&2
    return 1
  fi

  normalized_target_class="$(printf '%s' "$(class_repo_paths_trim_value "$target_class")" | tr '[:upper:]' '[:lower:]')"

  if ! parsed_entries="$(class_repo_paths_extract_entries "$definition_path" "include-policy")"; then
    echo "class_repo_paths coherence failed: could not read meta_info.class_repo_paths from $definition_path" >&2
    return 1
  fi

  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    IFS='|' read -r class_name class_state class_path policy <<<"$entry"

    class_name="$(class_repo_paths_trim_value "$class_name")"
    normalized_class="$(printf '%s' "$class_name" | tr '[:upper:]' '[:lower:]')"
    if [[ -n "$normalized_target_class" && "$normalized_class" != "$normalized_target_class" ]]; then
      continue
    fi
    matched=1

    normalized_state="$(printf '%s' "$(class_repo_paths_trim_value "$class_state")" | tr '[:upper:]' '[:lower:]')"
    normalized_path="$(class_repo_paths_trim_value "$class_path")"

    case "$normalized_state" in
      ready)
        if [[ -z "$normalized_path" ]]; then
          echo "class_repo_paths coherence failed for class '$class_name': state ready requires non-empty path" >&2
          return 1
        fi
        if [[ ! -d "$normalized_path" ]]; then
          echo "class_repo_paths coherence failed for class '$class_name': path is not an existing directory: $normalized_path" >&2
          return 1
        fi
        if ! resolved_path="$(cd "$normalized_path" && pwd -P)"; then
          echo "class_repo_paths coherence failed for class '$class_name': failed to resolve path: $normalized_path" >&2
          return 1
        fi
        if [[ ! -e "$resolved_path/.git" ]]; then
          echo "class_repo_paths coherence failed for class '$class_name': path does not contain .git: $resolved_path" >&2
          return 1
        fi
        ;;
      deferred)
        if [[ -n "$normalized_path" ]]; then
          echo "class_repo_paths coherence failed for class '$class_name': state deferred requires empty or absent path" >&2
          return 1
        fi
        ;;
      *)
        echo "class_repo_paths coherence failed for class '$class_name': state must be ready or deferred, got '$class_state'" >&2
        return 1
        ;;
    esac

    if [[ -n "$policy" ]]; then
      case "$policy" in
        B|C) ;;
        *)
          echo "class_repo_paths coherence failed for class '$class_name': policy must be B or C when present, got '$policy'" >&2
          return 1
          ;;
      esac
    fi
  done <<<"$parsed_entries"

  if [[ -n "$normalized_target_class" && "$matched" -eq 0 ]]; then
    echo "class_repo_paths coherence failed for class '$target_class': class not found" >&2
    return 1
  fi

  return 0
}
