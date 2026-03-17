# Git Interaction

- Git provides commands to amend, compare, unstage, reset, and revert commits after the initial add/commit cycle.
- `git diff` and `git restore` operate across the three areas (Working Tree, Index, Repository).
- `git reset` rewrites local history; `git revert` safely undoes changes by creating a new commit.

# Architecture


![Git Areas](./pic/Git-diagram.png)

# Mental Model

```text
1. Want to see changes?        --> git diff (unstaged) / git diff --staged (staged)
2. Want to unstage a file?     --> git reset <file>
3. Want to discard edits?      --> git restore <file> (from Index) or --source=HEAD (from commit)
4. Want to fix last commit?    --> git commit --amend (local only, new hash)
5. Want to move branch back?   --> git reset <hash> --soft / --mixed / --hard (local only)
6. Want to undo a pushed commit? --> git revert <hash> (safe, creates new commit)
```

**Example: fix a commit then undo a bad one**

```bash
# Amend the last commit with a forgotten file
git add forgotten.txt
git commit --amend -m "Add feature X (with forgotten file)"

# Later, undo a bad commit safely
git revert abc1234
```

# Core Building Blocks

### Advance Commit Options

#### Stage and commit tracked files in one step

```bash
git commit -am "commit message"
```

- Stages and commits all modified tracked files in one command.
- Does NOT include untracked (new) files; those must be added with `git add` first.

#### Amend the last commit

```bash
git commit --amend
```

- Rewrites the most recent commit (creates a new commit with a new hash).
- Use when adding a missing file or updating the commit message.
- Can be combined with `git add` beforehand to include additional changes.
- Local only -- never amend commits that have been pushed.

Related notes: [001-git-setup](./001-git-setup.md)

### Delete and Rename

```bash
git rm <file>
```

- Removes file from Working Directory and stages the deletion.

```bash
git mv old new
```

- Renames or moves files within the repository (stages the change automatically).

Related notes: [001-git-setup](./001-git-setup.md)

### Diff

```bash
git diff
```

- Shows differences between Working Directory and Staging Area -- "what changed but is not staged".

```bash
git diff --staged
```

- Shows differences between Staging Area and last commit -- "what will be committed".

Related notes: [001-git-setup](./001-git-setup.md)

### Discard Unstaged Changes (git restore)

```bash
git restore <file>
```

- Restores file in Working Directory from Index (discards unstaged edits).

```bash
git restore --source=HEAD <file>
```

- Restores file in Working Directory from the HEAD commit (bypasses Index).

Related notes: [001-git-setup](./001-git-setup.md)

### Git Reset

#### Unstage a file

```bash
git reset <file>
```

- Removes a staged file from the Staging Area (opposite of `git add`).

#### Move branch pointer to a previous commit

```bash
git reset <hash_commit>
```

- Moves the current branch pointer to the specified commit.
- Affects Index and Working Directory depending on mode (use local only):
  - `--soft` -- move branch pointer only (staged changes preserved).
  - `--mixed` -- move branch pointer + reset Index (default).
  - `--hard` -- move branch pointer + reset Index + reset Working Directory (destructive).

Related notes: [003-git-branch](./003-git-branch.md)

### Git Revert

```bash
git revert <hash_commit>
```

- Creates a new commit that cancels (inverts) the specified commit.
- Keeps history consistent without deleting commits -- safe for shared branches.

Related notes: [003-git-branch](./003-git-branch.md), [004-git-remote-repository](./004-git-remote-repository.md)

---

# Practical Command Set (Core)

```bash
# Stage + commit tracked files
git commit -am "message"

# Amend last commit
git add <forgotten-file>
git commit --amend -m "updated message"

# Delete / rename
git rm <file>
git mv <old> <new>

# Compare changes
git diff                 # working vs staging
git diff --staged        # staging vs last commit

# Discard / unstage
git restore <file>               # discard working changes (from Index)
git restore --source=HEAD <file> # discard working changes (from HEAD)
git reset <file>                 # unstage a file

# Rewrite history (local only)
git reset --soft <hash>    # keep staged + working
git reset --mixed <hash>   # reset staged, keep working
git reset --hard <hash>    # reset everything

# Safe undo (shared branches)
git revert <hash>
```

All `git reset <hash>` modes are local-only operations; use `git revert` for pushed history.

# Troubleshooting Guide

```text
Staged a wrong file?
  +--> git reset <file>           --> unstages it
  |
Made changes you want to discard?
  +--> git restore <file>         --> reverts to Index version
  +--> git restore --source=HEAD  --> reverts to last commit version
  |
Last commit has a mistake?
  +--> Not pushed? --> git commit --amend
  +--> Already pushed? --> git revert <hash> (safe)
  |
Need to go back several commits?
  +--> Local only? --> git reset <hash> (choose --soft/--mixed/--hard)
  +--> Shared branch? --> git revert <hash> for each bad commit
```

# Quick Facts (Revision)

- `git commit -am` stages and commits tracked files only; new files need explicit `git add`.
- `git commit --amend` rewrites the last commit with a new hash -- local only.
- `git diff` compares Working Tree vs Index; `git diff --staged` compares Index vs last commit.
- `git restore <file>` discards unstaged changes from Index; add `--source=HEAD` to restore from commit.
- `git reset <file>` unstages; `git reset <hash>` moves the branch pointer.
- Reset modes: `--soft` (pointer only), `--mixed` (pointer + Index), `--hard` (everything).
- `git revert` is the safe undo -- creates a new inverting commit, preserves history.
- `git rm` deletes and stages; `git mv` renames and stages.
