# Git Setup

- Git initializes a repository with `git init`, creating a hidden `.git/` directory that stores all metadata and history.
- Configuration (`user.name`, `user.email`) identifies the author on every commit; scoped globally or per-repo.
- Files flow through three areas (Working Tree, Staging Area, Repository) controlled by `git add` and `git commit`.

# Architecture

![Git Areas](./pic/Git-diagram.png)

# Mental Model

```text
1. git init              --> creates .git/ directory (skip if cloned)
2. git config            --> set identity (name, email)
3. edit files            --> Working Tree changes
4. git add <file>        --> snapshot staged in Index
5. git commit -m "msg"   --> Index becomes a new commit object in .git/
6. git log               --> inspect the commit chain
```

**Example: new repository from scratch**

```bash
mkdir my-project && cd my-project
git init
git config --local user.name "Alice"
git config --local user.email "alice@example.com"
echo "hello" > README.md
git add README.md
git commit -m "Initial commit"
git log --oneline
```

# Core Building Blocks

### Why Git (vs manual copies)

- Manual copying is error-prone and produces chaotic backups.
- Git tracks changes in files with immutable, content-addressed data.
- Every commit is a SHA-1 hash of its content -- guarantees integrity.
- Maintains a history of who, what, when; enables easy rollback to any stable version.

Related notes: [000-core](./000-core.md)

### Initialize a Repository

```bash
git init
```

- Creates a new Git repository in the current directory.
- Generates a hidden `.git/` directory storing all metadata and commit history.
- If you clone a repository (including inside WSL), you do not need to run `git init` because the repo is already initialized.

Related notes: [004-git-remote-repository](./004-git-remote-repository.md)

### Git Config

```bash
git config --global user.name "Name"
git config --global user.email "example@email.com"
```

- Sets the author identity attached to every commit.
- `--global` applies to all repos for the current OS user; `--local` applies to the current repo only (overrides global).
- `git config --global --list` -- check global config.
- `git config --local --list` -- check local config.

Related notes: [000-core](./000-core.md)

### Three Git Areas

- **Working Tree** (Working Directory) -- real files on disk that are editable.
- **Staging Area** (Index) -- prepares a snapshot to be committed.
- **Git Directory** (Repository, Local Repo) -- stored in `.git/`; contains snapshots with unique hashes.
- Commit does NOT read from Working Directory. It reads only from Index.

Related notes: [000-core](./000-core.md), [002-git-interaction](./002-git-interaction.md)

### Basic Commands

#### Checking progress

```bash
git status
```

- Shows file states (untracked, modified, staged).
- Recommended to run before every commit.

#### Making a commit

```bash
git commit -m "commit message"
```

- Creates a new commit from the Staging Area and moves the current branch pointer.
- Each commit points to its parent commit, forming a linked history chain.

#### Git log

```bash
git log
git log --oneline --graph
git log -p
```

- `git log` -- shows commits with author, date, and message.
- `git log --oneline --graph` -- compact view with hash and message, shows branch graph.
- `git log -p` -- shows the patch (diff) for each commit.

Related notes: [002-git-interaction](./002-git-interaction.md)

### Pointers in Git

- `[branch_name]` -- pointer to the latest commit on that branch.
- `HEAD` -- pointer to the currently checked-out branch (the one in use).
- Pointer flow: `HEAD --> branch --> commit`.

Related notes: [003-git-branch](./003-git-branch.md)

### .gitignore

- A file that tells Git which files or directories should NOT be tracked.
- Does NOT remove files from your system; only prevents Git from tracking them.
- Affects only untracked files.
- If a file is already committed, use `git rm --cached file_to_ignore` then commit the change.

#### Basic syntax

| Pattern           | Meaning                              |
| :---------------- | :----------------------------------- |
| file.txt          | ignore file.txt                      |
| *.log             | ignore all .log files                |
| folder/           | ignore entire folder/                |
| !important.txt    | do not ignore this file              |
| *.log + !keep.log | ignore all .log files except keep.log |

Related notes: [002-git-interaction](./002-git-interaction.md)

---

# Practical Command Set (Core)

```bash
# Initialize
git init

# Configure identity
git config --global user.name "Name"
git config --global user.email "name@example.com"

# Stage and commit
git add <file>
git commit -m "message"

# Inspect
git status
git log --oneline --graph
git log -p
```

Check config: `git config --global --list` or `git config --local --list`

# Troubleshooting Guide

```text
git init not working?
  +--> Already inside a repo? --> check for .git/ directory
  |
  +--> Cloned repo? --> no need to init
  |
git status shows unexpected files?
  +--> Check .gitignore patterns
  |
  +--> File already tracked? --> git rm --cached <file>, add to .gitignore, commit
  |
Config not taking effect?
  +--> --local overrides --global --> check both with --list
```

# Quick Facts (Revision)

- `git init` creates `.git/` directory; skip if repository was cloned.
- `git config --global` sets identity for all repos; `--local` overrides per-repo.
- Three areas: Working Tree (edit), Staging Area (stage), Repository (commit).
- Commit reads from Index only, never directly from Working Tree.
- HEAD points to current branch; branch points to latest commit.
- `.gitignore` affects untracked files only; use `git rm --cached` for already-tracked files.
- Each commit is a SHA-1 hash forming an immutable linked chain.
