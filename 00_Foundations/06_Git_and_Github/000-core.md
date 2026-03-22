# Git and GitHub

- Git is a distributed version control system; tracks changes locally with immutable, content-addressed hashes.
- GitHub is a web hosting platform for Git repositories; adds collaboration via pull requests, issues, and forks.
- Every commit records who, what, and when; the full history enables rollback to any prior state.

# Architecture

```text
+------------------+       git add       +------------------+     git commit     +------------------+
|   Working Tree   | ------------------> |  Staging Area    | -----------------> |   Repository     |
|  (editable disk  |                     |  (Index)         |                    |   (.git/)        |
|   files)         | <------------------ |                  | <-- git log ----   |   commits live   |
+------------------+   git restore       +------------------+                    +------------------+
                                                                                        |
                                                                                   git push
                                                                                        |
                                                                                        v
                                                                               +------------------+
                                                                               |  Remote (GitHub) |
                                                                               +------------------+
```

# Mental Model

```text
1. Edit files            --> Working Tree changes
2. git add <file>        --> snapshot moves to Staging Area (Index)
3. git commit -m "msg"   --> Index snapshot becomes a commit in .git/
4. git push              --> commit travels to remote repository
```

**Example: first commit workflow**

```bash
echo "# project" > README.md
git add README.md
git commit -m "Initial commit"
git push -u origin main
```

# Core Building Blocks

### Git (the tool)

- Distributed version control system running locally on your machine.
- Each commit is a content-addressed snapshot identified by a SHA-1 hash.
- Maintains an immutable, linked history chain (child points to parent).

Related notes: [001-git-setup](./001-git-setup.md), [002-git-interaction](./002-git-interaction.md)
- HEAD points to current branch; branch pointer points to latest commit.
- `.gitignore` prevents tracking of specified patterns; does not delete files.
- `git revert` is the safe undo (new commit); `git reset` rewrites history (local only).

### GitHub (the platform)

- Hosts Git repositories on the web with a UI for browsing code and history.
- Adds collaboration features: pull requests, code review, issues, forks, Actions CI/CD.
- Git is the engine; GitHub is the garage.

Related notes: [004-git-remote-repository](./004-git-remote-repository.md), [005-git-pull-request](./005-git-pull-request.md)
- GitHub adds PRs, issues, forks, and Actions on top of Git.

### Three Git Areas
- **Working Tree** (Working Directory) -- editable files on disk.
- **Staging Area** (Index) -- prepared snapshot of changes to be committed; populated by `git add`.
- **Repository** (.git/) -- committed snapshots with unique hashes. Commit reads from Index only, not Working Tree.
- Git is distributed -- every clone has the full history locally.
- Commits are immutable snapshots identified by SHA-1 hashes.
- Three areas: Working Tree, Staging Area (Index), Repository (.git/).
- `git add` stages; `git commit` records; `git push` shares.
---

# Troubleshooting Guide

```text
Problem unclear?
  |
  +--> git status          --> see file states (untracked / modified / staged)
  |
  +--> git log --oneline   --> check recent commit history
  |
  +--> git diff            --> what changed but not staged?
  |
  +--> git diff --staged   --> what is staged but not committed?
  |
  +--> Accidentally committed? --> git revert <hash> (safe) or git reset (local only)
  |
  +--> Wrong branch?       --> git stash, git switch <branch>, git stash pop
```

# Topic Map

- [001-git-setup](./001-git-setup.md) -- init, config, three areas, .gitignore
- [002-git-interaction](./002-git-interaction.md) -- amend, diff, reset, revert, restore
- [003-git-branch](./003-git-branch.md) -- branches, merge, merge conflict
- [004-git-remote-repository](./004-git-remote-repository.md) -- clone, remote, fetch, push, pull, rebase
- [005-git-pull-request](./005-git-pull-request.md) -- fork, pull request, code review
- [006-git-stash-and-worktree](./006-git-stash-and-worktree.md) -- stash, worktree
- [007-git-tag-and-release](./007-git-tag-and-release.md) -- tags, semantic versioning, releases
- [008-gitflow-and-strategies](./008-gitflow-and-strategies.md) -- branching strategies
- [markdown](./markdown.md) -- Markdown syntax reference
