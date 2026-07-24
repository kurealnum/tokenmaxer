#!/usr/bin/env bash
# shellcheck shell=bash
# Shared helpers for scripts/github/*.sh

set -euo pipefail

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }; }

slugify() {
  tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-{2,}/-/g' \
    | cut -c1-80
}

repo_nwo() { gh repo view --json nameWithOwner -q .nameWithOwner; }
get_issue_json() { gh issue view "$1" --json number,title,body,labels,url --jq '{number,title,body,labels,url}'; }

parent_from_body() {
  jq -r '.body // ""' | grep -Eio '(parent|epic)[^#]{0,30}#[0-9]+' | head -1 | grep -Eo '[0-9]+' || true
}

parent_from_graphql() {
  local repo="$1" issue_number="$2" owner name
  owner="${repo%/*}"; name="${repo#*/}"
  gh api graphql -f owner="$owner" -f name="$name" -F number="$issue_number" -f query='
    query($owner:String!, $name:String!, $number:Int!) {
      repository(owner:$owner, name:$name) { issue(number:$number) { parent { number } } }
    }' --jq '.data.repository.issue.parent.number // empty' 2>/dev/null || true
}

print_issue_contents() {
  local heading="$1" issue_json="$2" number title url labels body
  number="$(jq -r '.number' <<<"$issue_json")"
  title="$(jq -r '.title' <<<"$issue_json")"
  url="$(jq -r '.url' <<<"$issue_json")"
  labels="$(jq -r '[.labels[].name] | join(", ")' <<<"$issue_json")"
  body="$(jq -r '.body // ""' <<<"$issue_json")"
  cat <<CONTENTS

===== ${heading} #${number}: ${title} =====
URL: ${url}
Labels: ${labels:-none}

${body:-No issue body.}
===== End ${heading} #${number} =====
CONTENTS
}

epic_branch_name() {
  local parent_issue_json="$1" fallback_issue_number="$2" title epic_num
  title="$(jq -r '.title // ""' <<<"$parent_issue_json")"
  epic_num="$(grep -Eio '^Epic[[:space:]]+[0-9]+' <<<"$title" | grep -Eo '[0-9]+' | head -1 || true)"
  if [[ -n "$epic_num" ]]; then
    printf 'epic/%s' "$epic_num"
  else
    printf 'epic-unknown-%s' "$fallback_issue_number"
  fi
}

# Sets the issue's ProjectV2 Status field, resolving whichever project the
# issue actually belongs to (rather than assuming a fixed project number).
set_project_status() {
  local issue_number="$1" wanted_status="$2" repo owner name
  repo="$(repo_nwo)"; owner="${repo%/*}"; name="${repo#*/}"

  local data item_id project_id field_id option_id
  data="$(gh api graphql -f owner="$owner" -f name="$name" -F number="$issue_number" -f query='
    query($owner:String!, $name:String!, $number:Int!) {
      repository(owner:$owner, name:$name) {
        issue(number:$number) {
          projectItems(first:20) {
            nodes {
              id
              project {
                id
                fields(first:100) {
                  nodes {
                    ... on ProjectV2SingleSelectField { id name options { id name } }
                  }
                }
              }
            }
          }
        }
      }
    }')"

  item_id="$(jq -r '.data.repository.issue.projectItems.nodes[0].id // empty' <<<"$data")"
  project_id="$(jq -r '.data.repository.issue.projectItems.nodes[0].project.id // empty' <<<"$data")"
  field_id="$(jq -r '.data.repository.issue.projectItems.nodes[0].project.fields.nodes[]? | select(.name == "Status") | .id' <<<"$data" | head -1)"
  option_id="$(jq -r --arg status "$wanted_status" '.data.repository.issue.projectItems.nodes[0].project.fields.nodes[]? | select(.name == "Status") | .options[]? | select(.name == $status) | .id' <<<"$data" | head -1)"

  if [[ -z "$item_id" || -z "$project_id" || -z "$field_id" || -z "$option_id" ]]; then
    echo "Warning: could not find ProjectV2 Status option '$wanted_status' for issue #$issue_number; skipping project status update." >&2
    return 0
  fi

  gh api graphql -f projectId="$project_id" -f itemId="$item_id" -f fieldId="$field_id" -f optionId="$option_id" -f query='
    mutation($projectId:ID!, $itemId:ID!, $fieldId:ID!, $optionId:String!) {
      updateProjectV2ItemFieldValue(input:{projectId:$projectId,itemId:$itemId,fieldId:$fieldId,value:{singleSelectOptionId:$optionId}}) { projectV2Item { id } }
    }' >/dev/null
}
