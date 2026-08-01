# SKILL: Close GitHub PR

## Purpose

Safely merge a pull request: only proceed if there are no changes-requested reviews and no failing checks (no checks at all is fine).

## Steps

1. Run

./tokenmaxer/scripts/github/close-pr.sh {pr-number}

Omit `{pr-number}` to target the PR for the current branch.

2. If the script exits non-zero (changes requested, or failing checks), do not attempt to merge manually — report what's blocking to the user.

## Notes

Run from repository root.
Requires `gh`, `jq`.
Merges with a plain merge (no squash) and deletes the branch, matching this repo's merge convention.
