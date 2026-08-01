#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 [pr-number]

Merges a PR once it's safe to do so:
  - fails if any review is in "changes requested" state
  - fails if any CI check is failing (no checks at all is fine)
  - otherwise merges (plain merge, not squash) and deletes the branch

If [pr-number] is omitted, uses the PR for the current branch.
Requires: gh, jq
USAGE
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=tokenmaxer/scripts/github/common.sh
source "${ROOT}/tokenmaxer/scripts/github/common.sh"

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
  require gh; require jq
  gh auth status >/dev/null

  local pr_number="${1:-}"
  if [[ -z "$pr_number" ]]; then
    pr_number="$(gh pr view --json number -q .number)"
  fi

  local review_decision
  review_decision="$(gh pr view "$pr_number" --json reviewDecision -q '.reviewDecision // ""')"
  if [[ "$review_decision" == "CHANGES_REQUESTED" ]]; then
    echo "PR #$pr_number has unresolved changes-requested reviews; not merging." >&2
    exit 1
  fi

  local checks_json failing
  checks_json="$(gh pr checks "$pr_number" --json name,bucket 2>/dev/null || echo '[]')"
  failing="$(jq -r '[.[] | select(.bucket=="fail")] | length' <<<"$checks_json")"
  if [[ "$failing" -gt 0 ]]; then
    echo "PR #$pr_number has failing checks; not merging:" >&2
    jq -r '.[] | select(.bucket=="fail") | "  - " + .name' <<<"$checks_json" >&2
    exit 1
  fi

  gh pr merge "$pr_number" --merge --delete-branch
  echo "Merged PR #$pr_number."
}

main "$@"
