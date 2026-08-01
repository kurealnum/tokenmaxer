#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 <epic-title> <subissue-title-1> [subissue-title-2 ...]

Creates an epic (parent issue) plus subissues, linking each subissue to the
parent via the GraphQL addSubIssue mutation. Prints epic number/url and each
subissue number/url, nothing else.

Markdown descriptions are read from stdin: one block per issue body, in
order (epic body first, then one body per subissue title, same order as the
title args), separated by a line containing only ---. Block count must equal
1 + number of subissue titles. If stdin is empty/omitted, default bodies are
used ("Epic: {title}" / "Subissue of #{epic-number}").

Requires: gh, jq
USAGE
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=tokenmaxer/scripts/github/common.sh
source "${ROOT}/tokenmaxer/scripts/github/common.sh"

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
  local sub_titles=("$@")
  local expected_blocks=$(( ${#sub_titles[@]} + 1 ))

  local bodies=()
  if [[ ! -t 0 ]]; then
    local stdin_content
    stdin_content="$(cat)"
    if [[ -n "$stdin_content" ]]; then
      local block=""
      while IFS= read -r line; do
        if [[ "$line" == "---" ]]; then
          bodies+=("$block")
          block=""
        else
          block+="${line}"$'\n'
        fi
      done <<<"$stdin_content"
      bodies+=("$block")

      [[ "${#bodies[@]}" -eq "$expected_blocks" ]] || {
        echo "Expected ${expected_blocks} markdown blocks separated by ---, got ${#bodies[@]}" >&2
        exit 1
      }
    fi
  fi

  local repo epic_url epic_number epic_id epic_body
  repo="$(repo_nwo)"
  epic_body="${bodies[0]:-Epic: ${epic_title}}"
  epic_url="$(gh issue create --title "$epic_title" --label "epic" --body "$epic_body")"
  epic_number="${epic_url##*/}"
  epic_id="$(issue_node_id "$repo" "$epic_number")"

  echo "Epic #${epic_number}: ${epic_url}"

  local i=0 title url number child_id body
  for title in "${sub_titles[@]}"; do
    i=$((i + 1))
    body="${bodies[$i]:-Subissue of #${epic_number}}"
    url="$(gh issue create --title "$title" --body "$body")"
    number="${url##*/}"
    child_id="$(issue_node_id "$repo" "$number")"
    add_sub_issue "$epic_id" "$child_id"
    echo "  #${number}: ${url}"
  done
}

main "$@"
