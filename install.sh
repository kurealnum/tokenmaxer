#!/usr/bin/env bash
# Installs tokenmaxer components (scripts/skills/docs) into the current repo.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/kurealnum/tokenmaxer/main/install.sh | bash -s -- [--components a,b,c]
#   ./install.sh [--components a,b,c]
#   ./install.sh --update [--force]
#
# With no --components flag, runs an interactive menu.
# --update re-fetches the manifest and upgrades any installed component whose
# manifest version differs from the recorded version; use --force to also
# overwrite components with locally-edited files.

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

# Bare/empty target repos won't have these yet; create them up front rather
# than relying on mkdir -p per-file to notice they're missing.
ensure_base_dirs() {
  [[ -d ".agents" ]] || mkdir -p ".agents"
  [[ -d "tokenmaxer" ]] || mkdir -p "tokenmaxer"
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
  local names=() i=1 choice
  while IFS= read -r n; do names+=("$n"); done < <(component_names)

  # Menu/prompt text must go to stderr — this function's stdout is captured
  # by the caller as the selected component list.
  echo "Available tokenmaxer components:" >&2
  for n in "${names[@]}"; do
    echo "  $i) $n - $(component_field "$n" description)" >&2
    i=$((i+1))
  done

  read -r -p 'Select components (comma or space-separated numbers, or "all"): ' choice </dev/tty >&2

  local selected=() idx
  if [[ "$choice" == "all" ]]; then
    selected=("${names[@]}")
  else
    choice="${choice//,/ }"
    for idx in $choice; do
      if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx < 1 || idx > ${#names[@]} )); then
        echo "Invalid selection: $idx" >&2
        exit 1
      fi
      selected+=("${names[$((idx-1))]}")
    done
  fi
  printf '%s\n' "${selected[@]}"
}

# Returns the recorded sha256 for a file within an installed component, or
# empty if the component/file isn't in the install-state.
installed_file_sha() {
  local name="$1" path="$2"
  jq -r --arg n "$name" --arg p "$path" \
    '.components[$n].files[]? | select(.path==$p) | .sha256' "$STATE_FILE" 2>/dev/null
}

# Reports whether any file belonging to an installed component has been
# edited since install (current checksum differs from the recorded one).
component_has_local_edits() {
  local name="$1" path recorded current
  while IFS=$'\t' read -r path recorded; do
    [[ -z "$path" ]] && continue
    [[ -f "$path" ]] || continue
    current="$(sha256_of_file "$path")"
    [[ "$current" != "$recorded" ]] && return 0
  done < <(jq -r --arg n "$name" '.components[$n].files[] | [.path, .sha256] | @tsv' "$STATE_FILE")
  return 1
}

run_update() {
  local force="$1" name installed_version manifest_version

  if [[ ! -f "$STATE_FILE" ]]; then
    echo "No install state found at $STATE_FILE; nothing to update." >&2
    exit 1
  fi

  load_manifest
  ensure_base_dirs

  local updated=() skipped_same=() skipped_edited=()
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    installed_version="$(jq -r --arg n "$name" '.components[$n].version' "$STATE_FILE")"
    manifest_version="$(component_field "$name" version)"

    if [[ "$installed_version" == "$manifest_version" ]]; then
      skipped_same+=("$name")
      continue
    fi

    if [[ "$force" != "true" ]] && component_has_local_edits "$name"; then
      skipped_edited+=("$name")
      continue
    fi

    echo "Updating $name ($installed_version -> $manifest_version)..."
    install_component "$name"
    updated+=("$name")
  done < <(jq -r '.components | keys[]' "$STATE_FILE")

  echo
  echo "Updated: ${updated[*]:-none}"
  echo "Already up to date: ${skipped_same[*]:-none}"
  if [[ ${#skipped_edited[@]} -gt 0 ]]; then
    echo "Skipped (locally edited, re-run with --force to overwrite): ${skipped_edited[*]}"
  fi
}

main() {
  local components_arg="" update=false force=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --components)
        components_arg="$2"; shift 2 ;;
      --components=*)
        components_arg="${1#*=}"; shift ;;
      --update)
        update=true; shift ;;
      --force)
        force=true; shift ;;
      *)
        echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
  done

  if [[ "$update" == "true" ]]; then
    run_update "$force"
    return
  fi

  load_manifest
  ensure_base_dirs

  local requested=()
  if [[ -n "$components_arg" ]]; then
    IFS=',' read -r -a requested <<< "$components_arg"
  else
    local sel_output
    sel_output="$(interactive_select)" || exit 1
    while IFS= read -r n; do [[ -n "$n" ]] && requested+=("$n"); done <<< "$sel_output"
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
