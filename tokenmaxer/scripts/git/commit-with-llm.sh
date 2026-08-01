#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 [--dry-run]

Generates a Conventional Commits message from the current diff using a local
LLM served over an OpenAI-compatible API, then commits with it.

Diff source: staged changes (git diff --cached) if present, otherwise the
working tree diff (git diff). Only the diff is sent to the model — no full
file contents, no repo tree.

Uses the entire diff — do not use this if you want to commit a partial diff.

Env vars:
  LLM_BASE_URL   Base URL of the OpenAI-compatible API (default: http://localhost:1234/v1)
  LLM_MODEL      Model name (required)
  LLM_API_KEY    API key (optional; some local servers ignore it)

--dry-run   Print the generated commit message without committing.

Requires: curl, jq, git
USAGE
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=tokenmaxer/scripts/github/common.sh
source "${ROOT}/tokenmaxer/scripts/github/common.sh"

SYSTEM_PROMPT='You write Conventional Commits messages. Given a git diff, output exactly one line: type(scope): subject. No markdown fences, no explanation, no extra lines.'

main() {
  local dry_run=false
  if [[ "${1:-}" == "--dry-run" ]]; then dry_run=true; shift; fi
  [[ $# -eq 0 ]] || { usage >&2; exit 1; }

  require curl; require jq; require git

  local base_url="${LLM_BASE_URL:-http://localhost:1234/v1}"
  local model="${LLM_MODEL:?LLM_MODEL is required}"
  local api_key="${LLM_API_KEY:-}"

  local diff
  if ! git diff --cached --quiet 2>/dev/null; then
    diff="$(git diff --cached)"
  elif ! git diff --quiet 2>/dev/null; then
    diff="$(git diff)"
  else
    echo "Nothing to commit: no staged or working tree changes." >&2
    exit 1
  fi

  local payload
  payload="$(jq -n \
    --arg model "$model" \
    --arg system "$SYSTEM_PROMPT" \
    --arg diff "$diff" \
    '{model: $model, messages: [{role: "system", content: $system}, {role: "user", content: $diff}], temperature: 0.2}')"

  local response message
  response="$(curl -sS "${base_url}/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${api_key}" \
    -d "$payload")"

  message="$(jq -r '.choices[0].message.content // empty' <<<"$response" | head -1 | xargs)"

  if [[ -z "$message" ]]; then
    echo "Failed to get a commit message from the LLM. Response:" >&2
    echo "$response" >&2
    exit 1
  fi

  echo "$message"

  if [[ "$dry_run" == true ]]; then
    exit 0
  fi

  git commit -m "$message"
}

main "$@"
