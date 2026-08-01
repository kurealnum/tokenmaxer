# SKILL: Create GitHub Epic

## Purpose

Minimal-token entrypoint for creating an epic (parent issue) with linked subissues.

## Inputs needed

Ask only for: epic title, subissue titles (skip asking anything else — no repo exploration).

## Steps

1. Create the epic and subissues

./scripts/github/create-epic.sh "{epic-title}" "{subissue-title-1}" "{subissue-title-2}" ...

## Notes

Run from repository root.
Script prints only the epic number/url and each subissue number/url.
Subissues are linked to the parent via GraphQL `addSubIssue`, so `parent_from_graphql` in `common.sh` picks them up in `do-issue`/`do-epic`.
