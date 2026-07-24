#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 <issue-number> <branch-summary>

Creates/checks out a local branch for a GitHub issue:
  - prints issue contents plus parent issue contents when present
  - uses the provided branch summary argument
  - creates/checks out an epic branch when a parent issue exists
  - creates/checks out the final working branch: {github-issue-label}/{summary}

Requires: gh, jq, git
USAGE
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/github/common.sh
source "${ROOT}/scripts/github/common.sh"

main() {
  [[ $# -ge 2 ]] || { usage >&2; exit 1; }
  require gh; require jq; require git
  gh auth status >/dev/null

  local issue_number="$1" provided_summary repo issue parent_issue label summary branch parent_number epic_branch
  shift
  provided_summary="$*"
  repo="$(repo_nwo)"
  issue="$(get_issue_json "$issue_number")"
  label="$(jq -r '.labels[0].name // "issue"' <<<"$issue" | slugify)"

  parent_number="$(parent_from_graphql "$repo" "$issue_number")"
  if [[ -z "$parent_number" ]]; then parent_number="$(jq -r '.' <<<"$issue" | parent_from_body)"; fi

  print_issue_contents "Issue" "$issue"
  if [[ -n "$parent_number" ]]; then
    parent_issue="$(get_issue_json "$parent_number")"
    print_issue_contents "Parent Issue" "$parent_issue"
  fi

  summary="$(printf '%s' "$provided_summary" | xargs | slugify)"
  branch="${label}/${summary}"

  git fetch origin main >/dev/null 2>&1 || true
  if [[ -n "$parent_number" ]]; then
    epic_branch="$(epic_branch_name "$parent_issue" "$parent_number")"
    echo "Parent issue detected: #$parent_number; using $epic_branch"
    if git show-ref --verify --quiet "refs/heads/$epic_branch"; then
      git checkout "$epic_branch"
    else
      git checkout -B "$epic_branch" "origin/main"
    fi
    git checkout -B "$branch" "$epic_branch"
  else
    git checkout -B "$branch" "origin/main"
  fi

  echo "Checked out $branch"
}

main "$@"
