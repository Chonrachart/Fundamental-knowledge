# What is GIT
### Primative version control 
- Manual copy --> inefficient and error-prone.
- chaos from manual backups(have many backups).
### Why Git is needed 
- Trcked changes in files and data that is immutable.
- Maintains a history of who, what, when.
- every commit is content-addressed (hash).
- Enables easy roolback to stable version.

# Git Setup    
### Set up User
```sh
git config --global user.name "Name"  
git config --global user.email "example@email.com"
```
- These two command use to set up user to identify who is commit and who is author.
### Three GIT Areas
-  **Working Tree** (Working Directory) real file on disk that **editable**.
-  **Stageing Area** (Index) prepares snapshot **to be commited**. 
-  **Git Directory** (Repository, Local Repo) stored in .git that contain snapshot with unique hash
  Commit does NOT read from Working Directory. It **reads only from Index**.

     ![Git Areas](./pic/Git-diagram.png)

# Basic Git command

### Checking progress

```sh
git status
```

- show file states (modified, staged)
- Recommended use before commit.
### Making commit
- Each commit points to its parent commit, forming a linked history chain.
  
```bash
git commit
```

- Creates a new commit from the staging area and moves the current branch pointer.
- Use `git commit -m "commit message"` for quick commits.

### Git log

```sh
git log 
```
- show commits with author, date, and commit message.
- Use `git log --oneline --graph` show only hash of each commit and commit message.
- Use `git log -p` show the patch (diff) for each commit.

---

### Pointer in git log
    
- [Branch_name] = pointer to the latest commit in that branch.
- HEAD = pointer to the currently checked-out branch(in use).
- pointer flow {HEAD → branch → commit}

---

### .gitignore

- A file that tells Git which files or directories should NOT be tracked.
- .gitignore does NOT remove files from your system, it only prevents Git 
  from tracking them.
- Affects only untrack files.
- If already commit use `git rm --cached file_want_to_ignore` then commit the change.

---

#### Basic syntax

 | Pattern           | Meaning                              |
 | :---------------- | :----------------------------------- |
 | file.txt          | ignore file.txt                      |
 | *.log             | ignore all .log file                 |
 | folder/           | ignore entire folder/                |
 | !important.txt    | do not ignore this file              |
 | *.log + !keep.log | ignore all .log file except keep.log |