#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 <issue-number>

Starts work on a GitHub issue:
  - prints issue contents plus parent issue contents when present
  - assigns the issue to the authenticated GitHub user
  - sets the issue's ProjectV2 Status to "In Progress"

Branch creation is handled separately by scripts/github/create-issue-branch.sh.

Requires: gh, jq, git
USAGE
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/github/common.sh
source "${ROOT}/scripts/github/common.sh"

main() {
  [[ $# -eq 1 ]] || { usage >&2; exit 1; }
  require gh; require jq; require git
  gh auth status >/dev/null

  local issue_number="$1" repo issue parent_issue parent_number user
  repo="$(repo_nwo)"
  issue="$(get_issue_json "$issue_number")"
  user="$(gh api user --jq .login)"

  parent_number="$(parent_from_graphql "$repo" "$issue_number")"
  if [[ -z "$parent_number" ]]; then parent_number="$(jq -r '.' <<<"$issue" | parent_from_body)"; fi

  print_issue_contents "Issue" "$issue"
  if [[ -n "$parent_number" ]]; then
    parent_issue="$(get_issue_json "$parent_number")"
    print_issue_contents "Parent Issue" "$parent_issue"
  fi

  echo "Assigning #$issue_number to $user and setting Status to In Progress..."
  gh issue edit "$issue_number" --add-assignee "$user" >/dev/null
  set_project_status "$issue_number" "In Progress"

  echo "Issue #$issue_number started. To create a branch, run: scripts/github/create-issue-branch.sh $issue_number"
}

main "$@"
