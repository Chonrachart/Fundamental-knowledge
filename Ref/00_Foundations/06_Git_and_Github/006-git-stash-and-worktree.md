# Git Stash and Worktree

- **Stash** temporarily shelves uncommitted changes so you can switch context without committing half-done work
- **Worktree** lets you check out multiple branches simultaneously in separate directories, all backed by a single `.git` repository
- Both tools solve the same core problem — context switching — but at different scales: stash for quick saves, worktree for parallel workstreams

# Architecture

```text
                        STASH                                      WORKTREE
                        -----                                      --------

  Working Directory                                  repo/  (main worktree)
        |                                              |
        v                                              +-- .git/
  git stash push                                       |     |
        |                                              |     +-- worktrees/
        v                                              |           +-- hotfix/  (metadata)
  +-------------+                                      |           +-- experiment/
  | stash@{0}   |  <-- most recent                     |
  | stash@{1}   |                                      +-- ../hotfix-worktree/  (linked worktree)
  | stash@{2}   |                                      +-- ../experiment/       (linked worktree)
  +-------------+
   (LIFO stack)                                   All worktrees share ONE .git object store.
                                                  Each worktree has its own HEAD, index, working tree.
```

# Mental Model

```text
STASH WORKFLOW:
  working on feature --> urgent bug report --> stash changes --> fix bug --> pop stash --> resume feature

  1. You have uncommitted changes on feature-branch
  2. git stash push -m "wip: feature X"    --> changes saved, working dir clean
  3. git checkout main                      --> switch to fix bug
  4. ... fix and commit ...
  5. git checkout feature-branch
  6. git stash pop                          --> changes restored, stash entry removed

WORKTREE WORKFLOW:
  working on feature --> urgent bug report --> add worktree --> fix bug in separate dir --> remove worktree

  1. You are working in ~/repo on feature-branch
  2. git worktree add ../hotfix main        --> new directory ../hotfix checked out at main
  3. cd ../hotfix && fix bug && commit && push
  4. cd ~/repo                              --> feature-branch still intact, no stash needed
  5. git worktree remove ../hotfix          --> clean up
```

```bash
# Stash example: save, inspect, restore
$ git stash push -m "wip: add login form"
Saved working directory and index state On feature-login: wip: add login form

$ git stash list
stash@{0}: On feature-login: wip: add login form

$ git stash pop
On branch feature-login
Changes not staged for commit:
  modified:   src/login.js
Dropped refs/stash@{0}
```

# Core Building Blocks

### git stash — saving and restoring changes

- `git stash` / `git stash push` — save tracked file changes (staged + unstaged) and reset working dir
- `git stash push -m "message"` — save with a descriptive label (always prefer this)
- `git stash -u` — also stash **untracked** files (new files not yet added)
- `git stash -a` — stash everything including **ignored** files
- Stash stores a special merge commit referencing the working tree state, index state, and optionally untracked files
- Each stash entry is identified as `stash@{N}` where 0 is the most recent

Related notes: [001-git-setup](./001-git-setup.md), [003-git-branch](./003-git-branch.md)

### git stash — inspecting and managing the stack

- `git stash list` — show all stash entries with their index and message
- `git stash show` — summary of changes in the most recent stash (like `--stat`)
- `git stash show -p` — full diff of the most recent stash
- `git stash show -p stash@{2}` — full diff of a specific stash entry
- `git stash drop stash@{N}` — remove a specific entry from the stash stack
- `git stash clear` — delete **all** stash entries (irreversible)

Related notes: [002-git-interaction](./002-git-interaction.md)

### git stash — applying changes

- `git stash pop` — apply the most recent stash and remove it from the stack
- `git stash pop stash@{N}` — apply a specific stash and remove it
- `git stash apply` — apply the most recent stash but **keep** it in the stack
- `git stash apply stash@{N}` — apply a specific stash, keep it
- If applying a stash causes conflicts, the stash is **not** dropped — resolve conflicts manually then `git stash drop`
- `git stash branch <branch-name>` — create a new branch from the commit where the stash was created, apply the stash, and drop it (useful when the stash no longer applies cleanly)

Related notes: [003-git-branch](./003-git-branch.md)

### git worktree — parallel working directories

- `git worktree add <path> <branch>` — create a new working directory checked out at `<branch>`
- `git worktree add -b <new-branch> <path> <start-point>` — create a new branch and worktree in one step
- All worktrees share one `.git` object store — commits, refs, and config are shared
- Each worktree has its own `HEAD`, index, and working tree
- **Restriction**: a branch can only be checked out in one worktree at a time
- Worktrees are lightweight — no cloning, no extra disk for object store

Related notes: [001-git-setup](./001-git-setup.md), [003-git-branch](./003-git-branch.md)

### git worktree — management and cleanup
Related notes: [001-git-setup](./001-git-setup.md)
- `git worktree list` — show all worktrees with their paths, HEAD commit, and branch
- `git worktree remove <path>` — remove a worktree (working directory must be clean)
- `git worktree remove --force <path>` — remove even with uncommitted changes
- `git worktree prune` — clean up stale worktree metadata (e.g., after manually deleting a worktree directory)
- `git worktree lock <path>` — prevent a worktree from being pruned (useful for worktrees on removable media)
- `git worktree unlock <path>` — reverse of lock
