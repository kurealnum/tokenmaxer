# Local LLM Commit

`tokenmaxer/scripts/git/commit-with-llm.sh` generates a Conventional Commits message from the current diff using a local, OpenAI-compatible LLM server (LM Studio, Ollama's OpenAI endpoint, llama.cpp server, vLLM, etc.), then commits with it.

Uses the entire diff — do not use if you want to commit a partial diff.

## Setup

Point at a local OpenAI-compatible server:

```
export LLM_BASE_URL=http://localhost:1234/v1   # default shown
export LLM_MODEL=your-model-name               # required
export LLM_API_KEY=optional-key                # optional
```

## Usage

```
./tokenmaxer/scripts/git/commit-with-llm.sh              # commits with generated message
./tokenmaxer/scripts/git/commit-with-llm.sh --dry-run    # prints message only, no commit
```

Diff source: staged changes if present, otherwise working tree diff. Only the diff is sent to the model.
