# Local LLM Commit

`tokenmaxer/scripts/git/commit-with-llm.sh` generates a Conventional Commits message from the current diff using a local, OpenAI-compatible LLM server (LM Studio, Ollama's OpenAI endpoint, llama.cpp server, vLLM, etc.), then commits with it.

Uses the entire diff — do not use if you want to commit a partial diff.

## Setup

Point at a local OpenAI-compatible server. Config resolves from four sources, lowest to highest precedence:

1. `.tokenmaxer-llm.env` in repo root
2. `~/.config/tokenmaxer/llm.env`
3. Env vars (`LLM_BASE_URL`, `LLM_MODEL`, `LLM_API_KEY`)
4. CLI flags (`--base-url`, `--model`, `--api-key`)

Config file format (shell-sourced):

```
LLM_BASE_URL=http://localhost:1234/v1   # default shown
LLM_MODEL=your-model-name               # required
LLM_API_KEY=optional-key                # optional
```

A config file avoids per-call env exports — useful when an agent invokes the script directly and can't rely on shell profile sourcing. CLI flags override everything, for one-off model swaps.

## Usage

```
./tokenmaxer/scripts/git/commit-with-llm.sh                                   # config file / env vars already set
./tokenmaxer/scripts/git/commit-with-llm.sh --dry-run                        # prints message only, no commit
./tokenmaxer/scripts/git/commit-with-llm.sh --model your-model-name          # no config needed, pass model directly
./tokenmaxer/scripts/git/commit-with-llm.sh --model NAME --base-url URL --api-key KEY
```

Diff source: staged changes if present, otherwise working tree diff. Only the diff, plus the list of changed file paths, is sent to the model — no full file contents, no repo tree.

## Notes on small/local models

Small reasoning models (e.g. qwen3) tend to fixate on one file in a multi-file diff, and may emit blank `reasoning_content`-style lines before the actual message. The script sends an explicit file list ahead of the diff and instructs the model to summarize across all files, and extracts the first non-blank line of the response rather than strictly the first line.
