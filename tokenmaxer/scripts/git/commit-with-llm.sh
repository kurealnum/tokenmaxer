#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 [--dry-run] [--model NAME] [--base-url URL] [--api-key KEY]

Generates a Conventional Commits message from the current diff using a local
LLM served over an OpenAI-compatible API, then commits with it.

Diff source: staged changes (git diff --cached) if present, otherwise the
working tree diff (git diff). Only the diff is sent to the model — no full
file contents, no repo tree.

Uses the entire diff — do not use this if you want to commit a partial diff.

Config resolution (lowest to highest precedence):
  1. Config file: ./.tokenmaxer-llm.env (repo root) or ~/.config/tokenmaxer/llm.env
     Shell-sourced, sets LLM_BASE_URL / LLM_MODEL / LLM_API_KEY.
  2. Env vars: LLM_BASE_URL, LLM_MODEL, LLM_API_KEY
  3. CLI flags: --base-url, --model, --api-key

LLM_MODEL (or --model) is required via one of the above.

--dry-run          Print the generated commit message without committing.
--model NAME       Model name.
--base-url URL     Base URL of the OpenAI-compatible API (default: http://localhost:1234/v1).
--api-key KEY      API key (optional; some local servers ignore it).

Requires: curl, jq, git
USAGE
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=tokenmaxer/scripts/github/common.sh
source "${ROOT}/tokenmaxer/scripts/github/common.sh"

SYSTEM_PROMPT='You write Conventional Commits messages. Given a git diff touching one or more files, output exactly one line: type(scope): subject.
The diff may touch many files — read the full file list before writing the subject. Summarize the overall change across ALL listed files, not just the first file or first hunk. Never name a single file in the subject unless only one file changed. No markdown fences, no explanation, no extra lines.'

load_config_file() {
  local config_file="$1"
  [[ -f "$config_file" ]] || return 0
  # shellcheck disable=SC1090
  set -a; source "$config_file"; set +a
}

main() {
  local dry_run=false
  local cli_model="" cli_base_url="" cli_api_key=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry_run=true; shift ;;
      --model) cli_model="$2"; shift 2 ;;
      --base-url) cli_base_url="$2"; shift 2 ;;
      --api-key) cli_api_key="$2"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; exit 1 ;;
    esac
  done

  require curl; require jq; require git

  load_config_file "${ROOT}/.tokenmaxer-llm.env"
  load_config_file "${HOME}/.config/tokenmaxer/llm.env"

  local base_url="${cli_base_url:-${LLM_BASE_URL:-http://localhost:1234/v1}}"
  local model="${cli_model:-${LLM_MODEL:-}}"
  local api_key="${cli_api_key:-${LLM_API_KEY:-}}"

  if [[ -z "$model" ]]; then
    echo "LLM_MODEL is required (config file, env var, or --model)." >&2
    exit 1
  fi

  local diff files file_count user_content
  if ! git diff --cached --quiet 2>/dev/null; then
    diff="$(git diff --cached)"
    files="$(git diff --cached --name-only)"
  elif ! git diff --quiet 2>/dev/null; then
    diff="$(git diff)"
    files="$(git diff --name-only)"
  else
    echo "Nothing to commit: no staged or working tree changes." >&2
    exit 1
  fi

  file_count="$(wc -l <<<"$files" | xargs)"
  user_content="$(printf 'Files changed (%s):\n%s\n\nDiff:\n%s' "$file_count" "$files" "$diff")"

  local payload
  payload="$(jq -n \
    --arg model "$model" \
    --arg system "$SYSTEM_PROMPT" \
    --arg content "$user_content" \
    '{model: $model, messages: [{role: "system", content: $system}, {role: "user", content: $content}], temperature: 0.2}')"

  local response message
  response="$(curl -sS "${base_url}/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${api_key}" \
    -d "$payload")"

  message="$(jq -r '.choices[0].message.content // empty' <<<"$response" | grep -m1 -v '^[[:space:]]*$' | xargs)"

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
