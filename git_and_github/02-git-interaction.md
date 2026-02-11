1. Advance commit
    - `git commit -am "commit message"` this skips the staging step and commit 
        all midified tracked files directly.
    - It won't worked for new file (untracked) must add them first.
    - `git commit --amend` this will overwrite the most recent commit.
        Use when add missing file or update commit message
        can use with `git add` first (only local!!).
2. Delete and Rename
    - `git rm <file>` removes from repo. 
    - `git mv old new` renames or moves files within repo.
3. DIFF
    - `git diff` show different working directory vs staging area "what changed but not staged".
    - `git diff --staged` show different staging area vs last commit "what to be commit".
4. Discard unstaged change
    - `git restore <file>` restore file to the staging area (normaly staging area
        = HEAD if didn't add anything)
    - `git restore --sourec=HEAD <file>` restore file to the HEAD pointer.
5. Git reset
    - `git reset <file>` remove staged files from staging area.
    - `git reset <hash_commit>` this will move branch pointer (use local only!!)
6. Git revert
    - `git revert <hash_commit>` to create a new commit that cancels the 
        specified one.
    - This can keep consistent without deleting commits.
# Diagram
![Git Areas](Git-diagram.png)