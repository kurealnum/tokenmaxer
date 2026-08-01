# Installer

Scripts: `install.sh`, `uninstall.sh`. Manifest: `installer/manifest.json`.

Install any subset of tokenmaxer's scripts/skills into another repo without cloning this one. Docs (`docs/*.md`) are not installed — they live only in this repo; read them here or at the links below.

## Install

Interactive (prompts you to pick components):

```
curl -fsSL https://raw.githubusercontent.com/kurealnum/tokenmaxer/main/install.sh | bash
```

Non-interactive, specific components:

```
curl -fsSL https://raw.githubusercontent.com/kurealnum/tokenmaxer/main/install.sh | bash -s -- --components do-issue,do-commit
```

From a local clone (dev/testing loop):

```
./install.sh --components do-issue
```

Dependencies of a requested component (e.g. `common` for any `github/*` component) are installed automatically.

## Components

| Component | Description | Files |
|---|---|---|
| `common` | Shared shell helpers required by all github/* scripts | `tokenmaxer/scripts/github/common.sh` |
| `do-issue` | Start/branch/PR workflow for a single GitHub issue | `tokenmaxer/scripts/github/start-issue.sh`, `tokenmaxer/scripts/github/create-issue-branch.sh`, `tokenmaxer/scripts/github/open-pr.sh`, `.agents/skills/do-issue/SKILL.md` |
| `do-epic` | Workflow for completing an epic and its subissues in order | `tokenmaxer/scripts/github/get-subissues.sh`, `.agents/skills/do-epic/SKILL.md` |
| `do-create-issue` | Create a single GitHub issue from a title/label/markdown body | `tokenmaxer/scripts/github/create-issue.sh`, `.agents/skills/do-create-issue/SKILL.md` |
| `do-create-epic` | Create an epic issue with linked subissues | `tokenmaxer/scripts/github/create-epic.sh`, `.agents/skills/do-create-epic/SKILL.md` |
| `do-commit` | Generate a Conventional Commits message from the current diff via a local LLM server | `tokenmaxer/scripts/git/commit-with-llm.sh`, `.agents/skills/do-commit/SKILL.md` |
| `do-close-pr` | Merge a PR once it has no changes-requested reviews and no failing checks | `tokenmaxer/scripts/github/close-pr.sh`, `.agents/skills/do-close-pr/SKILL.md` |

`do-commit` needs a local OpenAI-compatible LLM server. After installing it, `install.sh` prints the env vars to set (`LLM_BASE_URL`, `LLM_MODEL`, `LLM_API_KEY`) — see [`docs/local-llm-commit.md`](local-llm-commit.md).

This table is generated from `installer/manifest.json` — that file is the source of truth; check it if this drifts.

## Where files land

Installed files go into the target repo's own `tokenmaxer/scripts/` and `.agents/skills/` directories, matching their paths in this repo. `install.sh` records what it wrote in `.tokenmaxer/installed.json`: per component, its version and each file's path + checksum at install time, plus `source_commit` — the tokenmaxer `main` commit hash the install/update was pulled from, used as an overall version marker. This is what `uninstall.sh` and `install.sh --update` use to know what's safe to touch.

If a file `install.sh` would write already exists, it's left alone — printed as `BLOCKED (already exists, use --force to overwrite)`, with a summary listing every blocked file at the end — so it never silently clobbers a file that's already there. Pass `--force` to overwrite anyway.

## Uninstall

Remove one component:

```
./uninstall.sh do-commit
```

Remove everything installed:

```
./uninstall.sh --all
```

A file is only deleted if its current checksum still matches the one recorded at install time. If you've hand-edited an installed file, it's left in place and printed as `SKIP (modified since install): <path>` — remove it yourself if you're sure.

## Update

```
./install.sh --update
```

Re-fetches the manifest and, for each installed component, compares its version to the recorded one:

- Same version: skipped, no-op.
- Newer version, no local edits: files re-copied, checksums and version updated.
- Newer version, but a file was hand-edited since install: skipped and printed as needing `--force`.

To overwrite local edits and force the update through:

```
./install.sh --update --force
```

## Prerequisites

`bash`, `curl`, `jq` for the installer itself. Individual components may need more — the `github/*` components (`do-issue`, `do-epic`, `do-create-issue`, `do-create-epic`) need `gh` authenticated against the target repo.
