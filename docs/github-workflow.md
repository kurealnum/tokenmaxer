# GitHub Issue/Epic Workflow

Scripts: `tokenmaxer/tokenmaxer/scripts/github/*.sh`. Skills: `.agents/skills/do-issue/SKILL.md`, `.agents/skills/do-issue/do-epic/SKILL.md`.

Two paradigms: single issue, epic with subissues.

## Paradigm 1: Single Issue

No parent issue. Work direct off `main`.

```
main ──┬── issue/{summary} ──► PR into main
       │
    (start-issue.sh, create-issue-branch.sh, implement, open-pr.sh)
```

Steps (do-issue skill):

1. `tokenmaxer/scripts/github/start-issue.sh {issue-number}` — print issue, assign self, Status → In Progress.
2. `tokenmaxer/scripts/github/create-issue-branch.sh {issue-number} {summary}` — branch off `origin/main`, name `{label}/{summary}`.
3. Implement.
4. `tokenmaxer/scripts/github/open-pr.sh {issue-number} --summary "..."` — push branch, PR base `main`, title `{label}: {summary} - closes #{issue}`, Status → In Review.

## Paradigm 2: Epic with Subissues

Parent issue (Epic) has subissues (stories). Epic gets own long-lived branch off main; each subissue branches off epic branch, merges back into epic branch; epic branch merges into main last.

```
main ──── epic/{epic-summary} ──┬── issue/{sub-1-summary} ──► PR into epic branch
                                 ├── issue/{sub-2-summary} ──► PR into epic branch
                                 └── issue/{sub-N-summary} ──► PR into epic branch
                                                                       │
                                                        (all subissues done)
                                                                       ▼
                                                          PR: epic branch ──► main
```

Steps (do-epic skill):

1. `tokenmaxer/scripts/github/get-subissues.sh {epic-issue-number}` — list subissue numbers, in order.
2. For each subissue, run `do-issue` skill (Paradigm 1 steps) — but branch/PR base auto-resolve to epic branch, not main:
   - `create-issue-branch.sh` detects parent via GraphQL/issue body, creates `epic/{epic-summary}` off `origin/main` first (if missing), checks it out, then branches subissue off it.
   - `open-pr.sh` same parent detection, sets PR base to `epic/{epic-summary}` instead of `main`.
   - After merging each subissue PR on GitHub, pull epic branch to local before starting next subissue.
3. After all subissues merged, open final PR: `epic/{epic-summary}` → `main`. Summarize changes, impact, manual checks needed.

## Creation Entrypoint

Scripts: `tokenmaxer/scripts/github/create-issue.sh`, `tokenmaxer/scripts/github/create-epic.sh`. Skills: `do-create-issue`, `do-create-epic`.

Mirrors `do-issue`/`do-epic` but for creation instead of implementation:

- `create-issue.sh {title} {label} [body]` — creates a single issue, prints number/url only. Feeds Paradigm 1.
- `create-epic.sh {epic-title} {subissue-title-1} [subissue-title-2 ...]` — creates the parent (epic) issue, then each subissue, linking each to the parent via GraphQL `addSubIssue` so `parent_from_graphql` picks it up. Prints epic number/url and each subissue number/url. Feeds Paradigm 2.

## Key mechanics (common.sh)

- Parent detection: `parent_from_graphql` (issue's GraphQL `parent` field) first, fallback `parent_from_body` (regex for `epic #123` / `parent #123` in issue body).
- `epic_branch_name`: derived from parent issue title, slugified, prefixed `epic/`.
- `set_project_status`: resolves whichever ProjectV2 the issue belongs to, updates Status field (In Progress / In Review).

## Notes

- Run scripts from repo root.
- Clean working tree before starting.
- `git pull` and check out correct epic branch before subissue work (no parent → work off `main`).
- Don't skip branch creation step.
