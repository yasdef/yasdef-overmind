#!/usr/bin/env bash
set -euo pipefail

repo_path="${1:-}"

if [[ -z "${repo_path//[[:space:]]/}" ]]; then
  echo "ERROR: Missing required argument: <repo-path>" >&2
  exit 1
fi

abort_rebase_if_needed() {
  local git_dir=""
  if ! git_dir="$(git -C "$repo_path" rev-parse --git-dir 2>/dev/null)"; then
    return 0
  fi
  case "$git_dir" in
    /*) ;;
    *) git_dir="$repo_path/$git_dir" ;;
  esac

  if [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" ]]; then
    git -C "$repo_path" rebase --abort >/dev/null 2>&1 || true
  fi
}

if ! git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: $repo_path is not a git repository." >&2
  exit 1
fi

current_branch=""
if ! current_branch="$(git -C "$repo_path" rev-parse --abbrev-ref HEAD 2>/dev/null)"; then
  current_branch=""
fi

resolve_remote_default_branch() {
  local upstream_ref=""
  local remote_name=""
  local remote_head_ref=""
  local candidate=""

  if [[ -n "$current_branch" ]] &&
    upstream_ref="$(git -C "$repo_path" rev-parse --abbrev-ref --symbolic-full-name "${current_branch}@{upstream}" 2>/dev/null)"; then
    remote_name="${upstream_ref%%/*}"
    if [[ -n "$remote_name" ]] &&
      remote_head_ref="$(git -C "$repo_path" symbolic-ref --quiet "refs/remotes/$remote_name/HEAD" 2>/dev/null)"; then
      candidate="${remote_head_ref##*/}"
      if [[ "$candidate" == "main" || "$candidate" == "master" ]]; then
        printf '%s' "$candidate"
        return 0
      fi
    fi
  fi

  for remote_name in $(git -C "$repo_path" remote 2>/dev/null); do
    if remote_head_ref="$(git -C "$repo_path" symbolic-ref --quiet "refs/remotes/$remote_name/HEAD" 2>/dev/null)"; then
      candidate="${remote_head_ref##*/}"
      if [[ "$candidate" == "main" || "$candidate" == "master" ]]; then
        printf '%s' "$candidate"
        return 0
      fi
    fi
  done

  return 1
}

default_branch=""
has_main="no"
has_master="no"
if git -C "$repo_path" rev-parse --verify --quiet refs/heads/main >/dev/null; then
  has_main="yes"
fi
if git -C "$repo_path" rev-parse --verify --quiet refs/heads/master >/dev/null; then
  has_master="yes"
fi

if default_branch="$(resolve_remote_default_branch)"; then
  :
elif [[ "$has_main" == "yes" && "$has_master" == "no" ]]; then
  default_branch="main"
elif [[ "$has_main" == "no" && "$has_master" == "yes" ]]; then
  default_branch="master"
elif [[ "$has_main" == "yes" && "$has_master" == "yes" ]]; then
  echo "BLOCKED: $repo_path default branch is ambiguous; both main and master exist and no remote default is configured (D7) — configure the default branch and rerun" >&2
  exit 1
fi

if [[ -z "$default_branch" || "$current_branch" != "$default_branch" ]]; then
  echo "BLOCKED: $repo_path is not on its default branch; planning reads upstream-synchronized merged truth only (D7) — check out the default branch and rerun" >&2
  exit 1
fi

if [[ -n "$(git -C "$repo_path" status --porcelain)" ]]; then
  echo "BLOCKED: $repo_path has uncommitted changes; planning syncs and reads committed merged truth only (D7) — commit or stash and rerun" >&2
  exit 1
fi

if ! git -C "$repo_path" rev-parse --abbrev-ref --symbolic-full-name "${default_branch}@{upstream}" >/dev/null 2>&1; then
  echo "BLOCKED: $repo_path default branch has no upstream; planning cannot sync merged truth (D7) — configure upstream and rerun" >&2
  exit 1
fi

if ! git -C "$repo_path" pull --rebase >/dev/null 2>&1; then
  abort_rebase_if_needed
  echo "BLOCKED: $repo_path could not sync default branch with git pull --rebase; planning cannot read merged truth (D7) — resolve the repo and rerun" >&2
  exit 1
fi

if [[ -n "$(git -C "$repo_path" status --porcelain)" ]]; then
  echo "BLOCKED: $repo_path could not sync default branch with git pull --rebase; planning cannot read merged truth (D7) — resolve the repo and rerun" >&2
  exit 1
fi
