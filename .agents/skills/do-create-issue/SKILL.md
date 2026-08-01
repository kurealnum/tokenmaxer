# SKILL: Create GitHub Issue

## Purpose

Minimal-token entrypoint for creating a single GitHub issue.

## Inputs needed

Ask only for: title, label, body (skip asking anything else — no repo exploration).

## Steps

1. Create the issue

./scripts/github/create-issue.sh "{title}" "{label}" "{body}"

## Notes

Run from repository root.
Script prints only the issue number and URL.
