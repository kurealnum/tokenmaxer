# Installer

Scripts: `install.sh`, `uninstall.sh`. Manifest: `installer/manifest.json`.

Install any subset of tokenmaxer's scripts/skills/docs into another repo without cloning this one.

## Install

Interactive (prompts you to pick components):

```
curl -fsSL https://raw.githubusercontent.com/kurealnum/tokenmaxer/main/install.sh | bash
```

Non-interactive, specific components:

```
curl -fsSL https://raw.githubusercontent.com/kurealnum/tokenmaxer/main/install.sh | bash -s -- --components do-issue,do-commit-with-llm
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
| `do-issue` | Start/branch/PR workflow for a single GitHub issue | `tokenmaxer/scripts/github/start-issue.sh`, `tokenmaxer/scripts/github/create-issue-branch.sh`, `tokenmaxer/scripts/github/open-pr.sh`, `.agents/skills/do-issue/SKILL.md`, `docs/github-workflow.md` |
| `do-epic` | Workflow for completing an epic and its subissues in order | `tokenmaxer/scripts/github/get-subissues.sh`, `.agents/skills/do-epic/SKILL.md`, `docs/github-workflow.md` |
| `do-create-issue` | Create a single GitHub issue from a title/label/markdown body | `tokenmaxer/scripts/github/create-issue.sh`, `.agents/skills/do-create-issue/SKILL.md` |
| `do-create-epic` | Create an epic issue with linked subissues | `tokenmaxer/scripts/github/create-epic.sh`, `.agents/skills/do-create-epic/SKILL.md` |
| `do-commit-with-llm` | Generate a Conventional Commits message from the current diff via a local LLM server | `tokenmaxer/scripts/git/commit-with-llm.sh`, `.agents/skills/do-commit-with-llm/SKILL.md`, `docs/local-llm-commit.md` |

This table is generated from `installer/manifest.json` — that file is the source of truth; check it if this drifts.

## Where files land

Installed files go into the target repo's own `scripts/`, `.agents/skills/`, and `docs/` directories, matching their paths in this repo. `install.sh` records what it wrote in `.tokenmaxer/installed.json`: per component, its version and each file's path + checksum at install time. This is what `uninstall.sh` and `install.sh --update` use to know what's safe to touch.

## Uninstall

Remove one component:

```
./uninstall.sh do-commit-with-llm
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
