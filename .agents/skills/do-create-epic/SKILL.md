# SKILL: Create GitHub Epic

## Purpose

Minimal-token entrypoint for creating an epic (parent issue) with linked subissues.

## Inputs needed

Ask only for: epic title, subissue titles, and a markdown description for the epic and for each subissue (skip asking anything else — no repo exploration).

## Steps

1. Create the epic and subissues, piping markdown descriptions via stdin — one block per issue body, in order (epic first, then each subissue in the same order as the title args), separated by a line containing only `---`

./tokenmaxer/scripts/github/create-epic.sh "{epic-title}" "{subissue-title-1}" "{subissue-title-2}" ... <<'EOF'
{epic-markdown-description}
---
{subissue-1-markdown-description}
---
{subissue-2-markdown-description}
EOF

## Notes

Run from repository root.
Write real markdown descriptions (not one-liners) — headings, lists, code blocks are fine.
Block count must equal 1 + number of subissue titles, or the script errors out.
Script prints only the epic number/url and each subissue number/url.
Subissues are linked to the parent via GraphQL `addSubIssue`, so `parent_from_graphql` in `common.sh` picks them up in `do-issue`/`do-epic`.
