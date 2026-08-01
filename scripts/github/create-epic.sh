#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 <epic-title> <subissue-title-1> [subissue-title-2 ...]

Creates an epic (parent issue) plus subissues, linking each subissue to the
parent via the GraphQL addSubIssue mutation. Prints epic number/url and each
subissue number/url, nothing else.

Requires: gh, jq
USAGE
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/github/common.sh
source "${ROOT}/scripts/github/common.sh"

issue_node_id() {
  local repo="$1" number="$2" owner name
  owner="${repo%/*}"; name="${repo#*/}"
  gh api graphql -f owner="$owner" -f name="$name" -F number="$number" -f query='
    query($owner:String!, $name:String!, $number:Int!) {
      repository(owner:$owner, name:$name) { issue(number:$number) { id } }
    }' --jq '.data.repository.issue.id'
}

add_sub_issue() {
  local parent_id="$1" child_id="$2"
  gh api graphql -f parentId="$parent_id" -f childId="$child_id" -f query='
    mutation($parentId:ID!, $childId:ID!) {
      addSubIssue(input:{issueId:$parentId, subIssueId:$childId}) { subIssue { id } }
    }' >/dev/null
}

main() {
  [[ $# -ge 2 ]] || { usage >&2; exit 1; }
  require gh; require jq
  gh auth status >/dev/null

  local epic_title="$1"
  shift

  local repo epic_url epic_number epic_id
  repo="$(repo_nwo)"
  epic_url="$(gh issue create --title "$epic_title" --label "epic" --body "Epic: ${epic_title}")"
  epic_number="${epic_url##*/}"
  epic_id="$(issue_node_id "$repo" "$epic_number")"

  echo "Epic #${epic_number}: ${epic_url}"

  local title url number child_id
  for title in "$@"; do
    url="$(gh issue create --title "$title" --body "Subissue of #${epic_number}")"
    number="${url##*/}"
    child_id="$(issue_node_id "$repo" "$number")"
    add_sub_issue "$epic_id" "$child_id"
    echo "  #${number}: ${url}"
  done
}

main "$@"
