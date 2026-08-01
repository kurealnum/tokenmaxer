#!/usr/bin/env bash
# Removes tokenmaxer components previously installed by install.sh.
#
# Usage:
#   ./uninstall.sh <component> [<component> ...]
#   ./uninstall.sh --all
#
# Only removes files recorded in .tokenmaxer/installed.json, and only if
# their content still matches the checksum recorded at install time.

set -euo pipefail

STATE_DIR=".tokenmaxer"
STATE_FILE="${STATE_DIR}/installed.json"

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }; }
require jq

sha256_of_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# Removes a directory only if it exists and is empty, then recurses upward.
prune_empty_dirs() {
  local dir="$1"
  while [[ -n "$dir" && "$dir" != "." && -d "$dir" ]]; do
    rmdir "$dir" 2>/dev/null || break
    dir="$(dirname "$dir")"
  done
}

uninstall_component() {
  local name="$1" file path sha recorded_sha
  if ! jq -e --arg n "$name" '.components[$n]' "$STATE_FILE" >/dev/null 2>&1; then
    echo "Not installed: $name" >&2
    return 0
  fi

  echo "Removing $name..."
  while IFS=$'\t' read -r path recorded_sha; do
    [[ -z "$path" ]] && continue
    if [[ ! -e "$path" ]]; then
      echo "  already gone: $path"
      continue
    fi
    sha="$(sha256_of_file "$path")"
    if [[ "$sha" != "$recorded_sha" ]]; then
      echo "  SKIP (modified since install): $path"
      continue
    fi
    rm -f "$path"
    prune_empty_dirs "$(dirname "$path")"
    echo "  removed: $path"
  done < <(jq -r --arg n "$name" '.components[$n].files[] | [.path, .sha256] | @tsv' "$STATE_FILE")

  local tmp
  tmp="$(mktemp)"
  jq --arg n "$name" 'del(.components[$n])' "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

main() {
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "No install state found at $STATE_FILE; nothing to uninstall." >&2
    exit 1
  fi

  if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <component> [<component> ...] | --all" >&2
    exit 1
  fi

  local components=()
  if [[ "$1" == "--all" ]]; then
    while IFS= read -r n; do components+=("$n"); done < <(jq -r '.components | keys[]' "$STATE_FILE")
  else
    components=("$@")
  fi

  for name in "${components[@]}"; do
    uninstall_component "$name"
  done
}

main "$@"
