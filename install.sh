#!/usr/bin/env bash
# Installs tokenmaxer components (scripts/skills/docs) into the current repo.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/kurealnum/tokenmaxer/main/install.sh | bash -s -- [--components a,b,c]
#   ./install.sh [--components a,b,c]
#
# With no --components flag, runs an interactive menu.

set -euo pipefail

RAW_BASE="${TOKENMAXER_RAW_BASE:-https://raw.githubusercontent.com/kurealnum/tokenmaxer/main}"
STATE_DIR=".tokenmaxer"
STATE_FILE="${STATE_DIR}/installed.json"

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }; }
require curl
require jq

# Detects whether this script is running from a local clone of tokenmaxer
# (manifest present on disk) or via curl-pipe (must fetch everything remotely).
running_from_clone() { [[ -f "installer/manifest.json" ]]; }

fetch_manifest() {
  if running_from_clone; then
    cat "installer/manifest.json"
  else
    curl -fsSL "${RAW_BASE}/installer/manifest.json"
  fi
}

fetch_file() {
  local repo_path="$1"
  if running_from_clone; then
    cat "$repo_path"
  else
    curl -fsSL "${RAW_BASE}/${repo_path}"
  fi
}

sha256_of_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

manifest_json=""
load_manifest() { [[ -n "$manifest_json" ]] || manifest_json="$(fetch_manifest)"; }

component_names() { jq -r '.components[].name' <<<"$manifest_json"; }

component_field() {
  local name="$1" field="$2"
  jq -r --arg n "$name" --arg f "$field" '.components[] | select(.name==$n) | .[$f]' <<<"$manifest_json"
}

component_files() {
  local name="$1"
  jq -r --arg n "$name" '.components[] | select(.name==$n) | .files[]' <<<"$manifest_json"
}

# Expands the requested component list to include their transitive dependencies.
resolve_components() {
  local requested=("$@") resolved=() name dep
  local -A seen=()
  while [[ ${#requested[@]} -gt 0 ]]; do
    name="${requested[0]}"
    requested=("${requested[@]:1}")
    [[ -n "${seen[$name]:-}" ]] && continue
    seen["$name"]=1
    resolved+=("$name")
    while IFS= read -r dep; do
      [[ -n "$dep" ]] && requested+=("$dep")
    done < <(jq -r --arg n "$name" '.components[] | select(.name==$n) | (.depends // [])[]' <<<"$manifest_json")
  done
  printf '%s\n' "${resolved[@]}"
}

install_component() {
  local name="$1" version file dest dir sha
  version="$(component_field "$name" version)"

  local written_files_json="[]"
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    dest="$file"
    dir="$(dirname "$dest")"
    mkdir -p "$dir"
    fetch_file "$file" > "$dest"
    sha="$(sha256_of_file "$dest")"
    written_files_json="$(jq --arg p "$file" --arg s "$sha" '. + [{path:$p, sha256:$s}]' <<<"$written_files_json")"
    echo "  installed: $dest"
  done < <(component_files "$name")

  update_state "$name" "$version" "$written_files_json"
}

update_state() {
  local name="$1" version="$2" files_json="$3"
  mkdir -p "$STATE_DIR"
  [[ -f "$STATE_FILE" ]] || echo '{"components":{}}' > "$STATE_FILE"
  local tmp
  tmp="$(mktemp)"
  jq --arg n "$name" --arg v "$version" --argjson f "$files_json" \
    '.components[$n] = {version:$v, files:$f}' "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

interactive_select() {
  local names=() descriptions=() i=1 choice
  while IFS= read -r n; do names+=("$n"); done < <(component_names)

  echo "Available tokenmaxer components:"
  for n in "${names[@]}"; do
    echo "  $i) $n - $(component_field "$n" description)"
    i=$((i+1))
  done

  read -r -p 'Select components (space-separated numbers, or "all"): ' choice

  local selected=()
  if [[ "$choice" == "all" ]]; then
    selected=("${names[@]}")
  else
    for idx in $choice; do
      selected+=("${names[$((idx-1))]}")
    done
  fi
  printf '%s\n' "${selected[@]}"
}

main() {
  local components_arg=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --components)
        components_arg="$2"; shift 2 ;;
      --components=*)
        components_arg="${1#*=}"; shift ;;
      *)
        echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
  done

  load_manifest

  local requested=()
  if [[ -n "$components_arg" ]]; then
    IFS=',' read -r -a requested <<< "$components_arg"
  else
    while IFS= read -r n; do requested+=("$n"); done < <(interactive_select)
  fi

  local resolved=()
  while IFS= read -r n; do resolved+=("$n"); done < <(resolve_components "${requested[@]}")

  for name in "${resolved[@]}"; do
    echo "Installing $name..."
    install_component "$name"
  done

  echo "Done. Install state recorded in ${STATE_FILE}"
}

main "$@"
