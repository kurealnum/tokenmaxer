# SKILL: GitHub Epic Workflow

## Purpose

Standard workflow for completing an Epic on Github (Epic = Issue with subissues, implementing each subissue in order)

## Steps

1. Given an issue number

Run ./scripts/github/get-subissues.sh {issue-number}

2. Complete each issue in order that it was given

Use the `do-issue` skill on each issue. When a PR is opened, do the following:

- Merge the PR on GitHub
- Pull the Epic's branch from remote to local

3. Open a final PR to merge the epic back into main. Summarize the changes that were made, how this affects the repo, and anything to manually check (tests, etc.)

## Notes

Run scripts from repository root
Ensure you are on a clean working tree before starting
Run `git pull` and ensure you're on the respective epic branch (found from start-issue.sh or create-issue-branch.sh - if there is no epic, work off of main)
Do not skip branch creation step
