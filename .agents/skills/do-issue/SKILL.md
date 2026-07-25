# SKILL: GitHub Issue Workflow

## Purpose

Standard workflow for starting work on a GitHub issue, implementing changes, and opening a pull request using internal scripts.

## Requirements

All code must be documented - functions, fields, enums, structs, classes, etc.

## Steps

1. Start issue context

./scripts/github/start-issue.sh {issue-number}

2. Create issue branch

./scripts/github/create-issue-branch.sh {issue-number} {branch-summary-from-start-issue-output}

3. Implement the issue

4. Open a PR with "closes #{issue-number}" in the description

./scripts/github/open-pr.sh {issue-number} --summary "{3-to-5-word-summary}"

## Notes

Run scripts from repository root
Ensure you are on a clean working tree before starting
Run `git pull` and ensure you're on the respective epic branch (found from start-issue.sh or create-issue-branch.sh - if there is no epic, work off of main)
Do not skip branch creation step
