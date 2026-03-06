# Git

- Version control system; tracks changes in files over time.
- Runs locally; each commit has a unique hash (content-addressed).
- Maintains history: who, what, when; enables rollback.

# GitHub

- Web platform that hosts Git repositories.
- Adds collaboration: pull requests, code review, issues, forks.
- Git is the tool; GitHub is the hosting service.

# Three Git Areas

- **Working Tree** — editable files on disk.
- **Staging Area** (Index) — snapshot prepared for commit; `git add` stages here.
- **Repository** — stored in `.git`; commits live here. Commit reads from Index only.

# Basic Workflow

```
edit → git add → git commit → git push
```

# Topic Map

- [00-markdown](./00-markdown.md) — Markdown syntax for README, issues, PR
- [01-git-setup](./01-git-setup.md) — init, config, three areas, .gitignore
- [02-git-interaction](./02-git-interaction.md) — amend, diff, reset, revert
- [03-git-branch](./03-git-branch.md) — branches, merge, merge conflict
- [04-git-remote-repository](./04-git-remote-repository.md) — clone, remote, fetch, push, pull, rebase
- [05-git-pull-request](./05-git-pull-request.md) — fork, pull request workflow
