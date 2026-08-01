#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./get-subissues.sh <issue-number>
#
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <issue-number>"
    exit 1
fi

ISSUE_NUMBER="$1"

OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')

get_subissues() {
    local issue_number="$1"

    # Get the issue's GraphQL node ID
    local issue_id
    issue_id=$(
        gh api graphql \
            -F owner="$OWNER" \
            -F repo="$REPO" \
            -F number="$issue_number" \
            -f query='
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    issue(number: $number) {
      id
    }
  }
}' \
            --jq '.data.repository.issue.id'
    )

    # Print each direct subissue number
    gh api graphql \
        -F id="$issue_id" \
        -f query='
query($id: ID!) {
  node(id: $id) {
    ... on Issue {
      subIssues(first: 100) {
        nodes {
          number
        }
      }
    }
  }
}' \
        --jq '.data.node.subIssues.nodes[].number'
}

get_subissues "$ISSUE_NUMBER"
