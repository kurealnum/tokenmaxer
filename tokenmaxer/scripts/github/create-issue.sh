#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 <title> <label> [body]

Creates a single GitHub issue. Prints only the resulting issue number and URL.

Body is a markdown description. If [body] is omitted, it is read from stdin
(pipe in a full markdown doc for a detailed description).
Requires: gh
USAGE
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=tokenmaxer/scripts/github/common.sh
source "${ROOT}/tokenmaxer/scripts/github/common.sh"

main() {
  [[ $# -ge 2 ]] || { usage >&2; exit 1; }
  require gh
  gh auth status >/dev/null

  local title="$1" label="$2" body
  shift 2

  if [[ $# -gt 0 ]]; then body="$*"; else body="$(cat)"; fi

  local url
  url="$(gh issue create --title "$title" --label "$label" --body "$body")"
  local number="${url##*/}"

  echo "#${number}: ${url}"
}

main "$@"
