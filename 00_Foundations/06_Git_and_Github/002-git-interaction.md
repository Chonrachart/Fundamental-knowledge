# Git Interaction

# Overview
- **Why it exists** —
- **What it is** —
- **One-liner** —

# Architecture

![Git Areas](./pic/Git-diagram.png)

# Core Building Blocks

### Advance Commit Options

```bash
git commit -am "commit message"
```

- stages and commits all modified tracked files (does NOT include untracked files).
- It won't worked for new file (untracked) must add them first.

```bash
git commit --amend
```

- rewrites the most recent commit (creates a new commit with a new hash). Use when add missing file or update commit message. can use with `git add` first (only local!!).

### Delete and Rename

```bash
git rm <file>
git mv old new
```

- `git rm` removes file from Working Directory and stages the deletion.
- `git mv` renames or moves files within repo.

### Diff

```bash
git diff
```

- show different working directory vs staging area "what changed but not staged".
- Use `git diff --staged` show different staging area vs last commit "what to be commit".

### Discard Unstaged Changes (git restore)

```bash
git restore <file>
```

- restores file in Working Directory from Index.
- Use `git restore --source=HEAD <file>` restores file in Working Directory from HEAD commit.

### Git Reset

```bash
git reset <file>
```

- remove staged files from staging area.

```bash
git reset <hash_commit>
```

- **What it is** — moves current branch pointer to specified commit may affect Index and Working Directory depending on mode (use local only!!)
  - --soft  (move branch only)
  - --mixed (move branch + reset Index) [default]
  - --hard  (move branch + reset Index + reset Working Directory)

### Git Revert
- **What it is** — create a new commit that cancels the specified one. keeps consistent without deleting commits.

```bash
git revert <hash_commit>
```
