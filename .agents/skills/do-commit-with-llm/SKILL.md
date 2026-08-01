# SKILL: Commit with Local LLM

## Purpose

Generate a Conventional Commits message from the current diff using a local, OpenAI-compatible LLM server, then commit.

Uses the entire diff — do not use if you want to commit a partial diff. See `docs/local-llm-commit.md` for setup.

## Steps

1. Ensure `LLM_MODEL` (and `LLM_BASE_URL`/`LLM_API_KEY` if not default) are set.
2. Run

./scripts/git/commit-with-llm.sh

Use `--dry-run` to preview the message without committing.

## Notes

Run from repository root.
Requires `curl`, `jq`, `git`.
