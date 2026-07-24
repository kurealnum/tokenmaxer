#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 <issue-number> [--summary "3-5 word summary"] [pr-description]

Opens a PR for the current branch:
  - prints issue contents plus parent issue contents when present
  - uses --summary if given, otherwise prompts for a short 3-5 word PR title summary
  - title: {github-issue-label}: {summary-with-natural-case} - closes {issue number}
  - base: epic/{epic-number-from-parent-title} when a parent issue exists, otherwise main
  - sets the issue's ProjectV2 Status to "In Review"

If [pr-description] is omitted, the description is read from stdin.
Requires: gh, jq, git
USAGE
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/github/common.sh
source "${ROOT}/scripts/github/common.sh"

prompt_summary() {
  local summary
  while true; do
    read -r -p "Enter a short PR title summary based on the issue (3-5 words): " summary </dev/tty
    summary="$(printf '%s' "$summary" | xargs)"
    [[ -n "$summary" ]] && break
    echo "Summary is required." >&2
  done
  printf '%s' "$summary"
}

main() {
  [[ $# -ge 1 ]] || { usage >&2; exit 1; }
  require gh; require jq; require git
  gh auth status >/dev/null

  local issue_number="$1" body repo issue parent_issue label summary="" pr_title parent_number base branch
  shift

  if [[ "${1:-}" == "--summary" ]]; then
    [[ $# -ge 2 ]] || { echo "--summary requires a value" >&2; exit 1; }
    summary="$(printf '%s' "$2" | xargs)"
    [[ -n "$summary" ]] || { echo "--summary requires a non-empty value" >&2; exit 1; }
    shift 2
  fi

  if [[ $# -gt 0 ]]; then body="$*"; else body="$(cat)"; fi

  repo="$(repo_nwo)"
  issue="$(get_issue_json "$issue_number")"
  label="$(jq -r '.labels[0].name // "issue"' <<<"$issue")"

  parent_number="$(parent_from_graphql "$repo" "$issue_number")"
  if [[ -z "$parent_number" ]]; then parent_number="$(jq -r '.' <<<"$issue" | parent_from_body)"; fi

  print_issue_contents "Issue" "$issue"
  if [[ -n "$parent_number" ]]; then
    parent_issue="$(get_issue_json "$parent_number")"
    print_issue_contents "Parent Issue" "$parent_issue"
    base="$(epic_branch_name "$parent_issue" "$parent_number")"
  else
    base="main"
  fi

  [[ -n "$summary" ]] || summary="$(prompt_summary)"
  pr_title="${label}: ${summary} - closes #${issue_number}"

  branch="$(git rev-parse --abbrev-ref HEAD)"
  git push -u origin "$branch"
  gh pr create --base "$base" --head "$branch" --title "$pr_title" --body "$body"
  set_project_status "$issue_number" "In Review"
  echo "Opened PR from $branch into $base and set #$issue_number to In Review"
}

main "$@"
