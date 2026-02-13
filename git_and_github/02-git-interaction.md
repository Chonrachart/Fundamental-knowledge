# More Git interaction

### Advance commit

```bash
git commit -am "commit message"
```

stages and commits all modified tracked files (does NOT include untracked files).
- It won't worked for new file (untracked) must add them first.

```bash
git commit --amend
```

- rewrites the most recent commit (creates a new
    commit with a new hash). Use when add missing file or update commit message
    can use with `git add` first (only local!!).

---

### Delete and Rename

```bash
git rm <file>
```

- removes file from Working Directory and stages the deletion.
  
```bash
git mv old new
```

-  renames or moves files within repo.

---

### DIFF

```bash
git diff
``` 

- show different working directory vs staging area "what changed but not staged".
- Use `git diff --staged` show different staging area vs last commit "what to be 
  commit".

---

### Discard unstaged change

```bash
git restore <file>
```

- restores file in Working Directory from Index.
- Use `git restore --sourec=HEAD <file>` restores file in Working Directory from 
  HEAD commit.

---

### Git reset

```bash
git reset <file>
```

- remove staged files from staging area.

```bash
git reset <hash_commit>
```

-  moves current branch pointer to specified commit may affect Index and 
    Working Directory depending on mode (use local only!!)
     - --soft  (move branch only)
     - --mixed (move branch + reset Index) [default]
     - --hard  (move branch + reset Index + reset Working Directory)

---

### Git revert

```bash
git revert <hash_commit>
```

-  to create a new commit that cancels the specified one.
- This can keep consistent without deleting commits.

---

# Diagram

![Git Areas](./pic/Git-diagram.png)