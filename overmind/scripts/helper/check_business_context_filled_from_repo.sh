#!/usr/bin/env bash
set -euo pipefail

TARGET_RELATIVE_PATH="${1:-overmind/product/feature_br_summary.md}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

resolve_target_path() {
  local target_input="$1"

  [[ -n "$target_input" ]] || die "Missing target artifact path."

  if [[ "$target_input" = /* ]]; then
    printf '%s\n' "$target_input"
    return 0
  fi

  printf '%s/%s\n' "$PWD" "$target_input"
}

main() {
  local target_path=""
  target_path="$(resolve_target_path "$TARGET_RELATIVE_PATH")"
  if [[ ! -f "$target_path" ]]; then
    die "Target BR summary not found: $target_path"
  fi

  awk '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
function strip_quotes(v) {
  if ((v ~ /^".*"$/) || (v ~ /^'\''.*'\''$/)) {
    v = substr(v, 2, length(v) - 2)
  }
  return v
}
function normalize(v) {
  return strip_quotes(trim(v))
}
function is_unfilled(v, u) {
  u = toupper(v)
  return (v == "" || u == "[UNFILLED]")
}
BEGIN {
  in_meta = 0
  in_existing_context = 0
  saw_meta = 0
  saw_existing = 0
  existing_field_count = 0
  has_errors = 0
}
/^##[[:space:]]+/ {
  in_meta = ($0 ~ /^##[[:space:]]+1\.[[:space:]]+Document[[:space:]]+Meta[[:space:]]*$/)
  in_existing_context = ($0 ~ /^##[[:space:]]+13\.[[:space:]]+Existing-System[[:space:]]+Context[[:space:]]*$/)
  if (in_meta) {
    saw_meta = 1
  }
  if (in_existing_context) {
    saw_existing = 1
  }
  next
}
{
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*/, "", line)
  if (line ~ /^[A-Za-z0-9_]+[[:space:]]*:/) {
    key = line
    sub(/:.*/, "", key)
    key = trim(key)

    value = line
    sub(/^[^:]*:[[:space:]]*/, "", value)
    value = normalize(value)

    if (in_meta) {
      meta_values[key] = value
    }

    if (in_existing_context) {
      existing_values[key] = value
      existing_field_count++
    }
  }
}
END {
  if (!saw_meta) {
    print "quality gate failed: missing section ## 1. Document Meta"
    has_errors = 1
  }

  source_type = (("source_type" in meta_values) ? meta_values["source_type"] : "")
  last_updated = (("last_updated" in meta_values) ? meta_values["last_updated"] : "")

  if (!("source_type" in meta_values)) {
    print "quality gate failed: missing key source_type in ## 1. Document Meta"
    has_errors = 1
  } else if (is_unfilled(source_type)) {
    print "quality gate failed: key source_type is unfilled in ## 1. Document Meta"
    has_errors = 1
  }

  if (!("last_updated" in meta_values)) {
    print "quality gate failed: missing key last_updated in ## 1. Document Meta"
    has_errors = 1
  } else if (is_unfilled(last_updated)) {
    print "quality gate failed: key last_updated is unfilled in ## 1. Document Meta"
    has_errors = 1
  } else if (last_updated !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/) {
    print "quality gate failed: key last_updated must be YYYY-MM-DD in ## 1. Document Meta"
    has_errors = 1
  }

  if (!saw_existing) {
    print "quality gate failed: missing section ## 13. Existing-System Context"
    has_errors = 1
  } else if (existing_field_count == 0) {
    print "quality gate failed: no fields found in ## 13. Existing-System Context"
    has_errors = 1
  } else {
    for (field_name in existing_values) {
      if (is_unfilled(existing_values[field_name])) {
        print "quality gate failed: key " field_name " is unfilled in ## 13. Existing-System Context"
        has_errors = 1
      }
    }
  }

  if (has_errors) {
    exit 1
  }

  print "quality gate passed: business context fields are complete"
}
  ' "$target_path"
}

main "$@"
