# SKILL: Commit with Local LLM

## Purpose

Generate a Conventional Commits message from the current diff using a local, OpenAI-compatible LLM server, then commit.

Uses the entire diff — do not use if you want to commit a partial diff. See `docs/local-llm-commit.md` for setup.

## Steps

Config comes from (lowest to highest precedence): `.tokenmaxer-llm.env` in repo root, `~/.config/tokenmaxer/llm.env`, shell env vars, CLI flags.

If a config file already sets `LLM_MODEL` (etc.), just run:

./tokenmaxer/scripts/git/commit-with-llm.sh

No config file present: pass flags directly, no need to export env vars first:

./tokenmaxer/scripts/git/commit-with-llm.sh --model MODEL_NAME [--base-url URL] [--api-key KEY]

Use `--dry-run` to preview the message without committing.

## Notes

Run from repository root.
Requires `curl`, `jq`, `git`.
