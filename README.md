# tokenmaxer

Fable 5 shouldn't write commit messages.

It also shouldn't think about checking out branches or writing repeated GraphQL queries for GitHub.

Frontier models should be used as little as possible.

# how

- Script everything that can be scripted, and use skills (or harnesses!) to use these scripts in an efficient and effective manner.
- Use no or minimal MCPs
- Use token efficient harnesses (ex. [pi mono](https://github.com/earendil-works/pi), [omegon](https://github.com/styrene-lab/omegon))

# usage

This is a template repository, meaning that you can either add some or all of this repository to:

- A new project
- A pre-existing project

_Some scripts may need to be modified depending on your usecase_. For example, `start-issue.sh` sets the `Status` field of an issue to `In Progress` via the Projects V2 API. If you're not using Projects, you may want to remove this.

# future work

- Using local LLMs to generate commit messages, PR titles, etc.
- Providing multiple strict definitions as to how software projects should be built (ex. Agile: every issue is an Epic or Story, all Stories create PRs that merge into an Epic branch, etc.)
- See [CONTRIBUTING.md]
