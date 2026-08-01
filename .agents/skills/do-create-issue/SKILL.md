# SKILL: Create GitHub Issue

## Purpose

Minimal-token entrypoint for creating a single GitHub issue.

## Inputs needed

Ask only for: title, label, markdown description (skip asking anything else — no repo exploration).

## Steps

1. Create the issue, piping the full markdown description via stdin

./tokenmaxer/scripts/github/create-issue.sh "{title}" "{label}" <<'EOF'
{markdown-description}
EOF

## Notes

Run from repository root.
Write a real markdown description (not a one-liner) — headings, lists, code blocks are fine.
Script prints only the issue number and URL.
