# Git Pull Request

- A pull request (PR) is a request to merge commits from one branch (or fork) into a target repository/branch
- PRs enable code review, discussion, and CI validation before changes are integrated
- Forks are required when you lack write access; PRs work within the same repo for team workflows too

# Architecture

```text
  +-------------------------+        +-------------------------+
  |  Original Repo          |        |  Your Fork              |
  |  (upstream)             |        |  (origin)               |
  |                         |        |                         |
  |  main  <-- PR --------- | ------ |  feature-branch         |
  |                         |        |                         |
  +-------------------------+        +-------------------------+
         ^                                    |
         |          git fetch upstream        |
         +------------------------------------+

  PR flow:
    fork --> clone --> branch --> commit --> push --> open PR
```

# Mental Model

```text
  1. Fork repo (if no write access)  -->  your copy on GitHub
  2. Clone fork locally              -->  git clone <fork-url>
  3. Create feature branch           -->  git switch -c fix-typo
  4. Commit changes                  -->  git add + git commit
  5. Push branch to fork             -->  git push -u origin fix-typo
  6. Open PR on GitHub               -->  base: upstream/main, compare: fix-typo
  7. Code review + CI checks         -->  reviewers comment, approve, or request changes
  8. Merge PR                        -->  maintainer merges via chosen strategy
```

Example: contributing to an open-source project

```bash
# after forking on GitHub
git clone https://github.com/you/project.git
cd project
git remote add upstream https://github.com/original/project.git
git switch -c fix-readme
# ... edit files ...
git add README.md
git commit -m "Fix broken link in README"
git push -u origin fix-readme
# open PR on GitHub: base=upstream/main, compare=fix-readme
```

# Core Building Blocks

### Fork

- Your own copy of someone else's repository on GitHub
- Required when you do not have write permission (not a collaborator)
- Forks live under your GitHub account; changes are proposed back via PRs
- Repository owner can accept (merge) or reject (close) the PR

Related notes: [004-git-remote-repository](./004-git-remote-repository.md)

### PR Anatomy

- **Title** — short summary of the change (under 70 characters)
- **Description** — detailed explanation: what changed, why, how to test
- **Base branch** — the branch you want to merge into (e.g., `main`)
- **Compare branch** — the branch containing your changes (e.g., `fix-readme`)
- **Reviewers** — team members assigned to review the code
- **Labels** — categorization tags (e.g., `bug`, `enhancement`, `docs`)
- **Linked issues** — reference issues with `Fixes #123` or `Closes #456` to auto-close on merge

Related notes: [003-git-branch](./003-git-branch.md)

### Code Review Process

- **Requesting review** — assign reviewers when creating the PR or afterward
- **Inline comments** — reviewers comment on specific lines of the diff
- **Suggestions** — reviewers can propose exact code changes that the author can accept with one click
- **Review outcomes:**
  - **Approve** — code is ready to merge
  - **Request changes** — issues must be addressed before merging
  - **Comment** — general feedback without explicit approval or rejection
- Author pushes new commits to the same branch to address feedback; the PR updates automatically

Related notes: [004-git-remote-repository](./004-git-remote-repository.md)

### Draft PRs

- Mark a PR as **Draft** to signal work-in-progress
- Draft PRs cannot be merged until marked as **Ready for review**
- Use drafts to:
  - Get early feedback on direction before code is complete
  - Run CI checks on partial work
  - Signal to the team that the branch is not yet ready

Related notes: [003-git-branch](./003-git-branch.md)

### Merge Strategies on GitHub

| Strategy | What happens | When to use |
|---|---|---|
| **Merge commit** | Creates a merge commit preserving all branch commits | Default; preserves full history |
| **Squash and merge** | Combines all PR commits into one commit on the base branch | Many small/WIP commits; want a clean history |
| **Rebase and merge** | Replays PR commits on top of the base branch (no merge commit) | Linear history preferred; each commit is meaningful |

- Repository settings control which strategies are allowed
- Squash is common for feature branches with messy commit history
- Rebase should not be used if commits have already been shared/referenced

Related notes: [003-git-branch](./003-git-branch.md), [004-git-remote-repository](./004-git-remote-repository.md)

### Keeping Fork in Sync

```bash
git remote add upstream <original-repo-url>     # one-time setup
git fetch upstream                               # download upstream changes
git switch main
git merge upstream/main                          # merge upstream into local main
git push origin main                             # update your fork on GitHub
```

- Always sync before creating a new feature branch to avoid conflicts
- `upstream` is the conventional name for the original repository remote

Related notes: [004-git-remote-repository](./004-git-remote-repository.md)

### PR Best Practices

- **Small, focused PRs** — one concern per PR; easier to review and less risky
- **Descriptive titles** — summarize the change, not the file (e.g., "Add rate limiting to auth endpoint" not "Update auth.py")
- **Link issues** — use `Fixes #N` in the description to auto-close related issues
- **CI checks** — ensure all automated tests and linters pass before requesting review
- **Self-review first** — review your own diff before assigning reviewers
- **Respond to feedback** — address all comments; push fix commits or explain why no change is needed

Related notes: [003-git-branch](./003-git-branch.md)

---

# Practical Command Set (Core)

```bash
# Fork workflow setup
git clone <fork-url>
git remote add upstream <original-url>

# Keep fork in sync
git fetch upstream
git switch main && git merge upstream/main
git push origin main

# Feature branch workflow
git switch -c feature-xyz
# ... make changes ...
git add <files> && git commit -m "Description"
git push -u origin feature-xyz
# --> open PR on GitHub

# After PR is merged — cleanup
git switch main && git pull
git branch -d feature-xyz
git push --delete origin feature-xyz
```

- Use `git push -u` on the first push to set upstream tracking for the new branch

# Troubleshooting Guide

```text
  PR has conflicts?
    |
    +--> Sync with base branch:
    |      git fetch origin
    |      git switch feature-xyz
    |      git merge origin/main (or git rebase origin/main)
    |      resolve conflicts --> git add --> git commit
    |      git push (or git push --force-with-lease after rebase)
    |
  CI checks failing?
    |
    +--> Read the CI log --> fix locally --> push new commit
    |
  PR not showing commits?
    |
    +--> Verify you pushed to the correct branch
    +--> Check base branch is set correctly on GitHub
```

# Quick Facts (Revision)

- Fork = your copy of someone else's repo; PR = request to merge back
- PR has a base branch (target) and compare branch (your changes)
- Three GitHub merge strategies: merge commit, squash and merge, rebase and merge
- Draft PRs signal work-in-progress and block merging
- `Fixes #N` in PR description auto-closes the linked issue on merge
- Keep forks in sync: `git fetch upstream` then `git merge upstream/main`
- Small, focused PRs with descriptive titles get reviewed faster
- Always run CI checks before requesting review
