# Git Remote Repository

- Each developer has a full copy of the repository locally.
- Sync work between local & remote repository through a Git server.

# Remote Branches

- Remote branches(e.g., origin/main, origin/featureA) represent the state of branches
  on the remote server.
- they are read only in local. you can't direct commit directly to them.

# Command

```bash
git clone <repo-url>
```

- Download full repository to your local machine and create folder with repository
  name.
- Automatically sets origin as the default remote name.
- Sets up the default tracking branch (e.g., local main tracking origin/main).

```bash
git remote 
```
- Shows all configured remote repositories.
- Use `git remote -v` to display fetch and push URLs.
- Use `git remote update` to fetch updates from all remotes.
- Use `git remote add <remote_name> <git_url>` to add a new remote.

```bash
git branch -u <remote_name>/<branch_name>
```

- To set upstream branch(tracking branch) for the current local branch..
- Defines where git pull and git push will operate by default.

```bash
git fetch [remote_name]
```

- Updates remote-tracking branches from the specified remote (default = origin).
- Does NOT modify your working directory or local branches.

```bash
git push
```

- Uploads local commits to the remote repository.
- By default, push to the upstream branch (depends on push.default setting).

```bash
git pull
```

- Fetches changes from the remote and merges them into the current branch.

Equivalent to:

```bash
git fetch <remote>
git merge <upstream-branch>
```

- It pull from the configured upstream branch.


# Git Rebase

- change the **base commit** of a branch.
- Avoids creating merge commits by rewriting history into a linear sequence.
- **!!! Do NOT rebase public/shared branches that have already been pushed.**.
  
## Step to Rebase (use local before push)

1. git switch <main_branch>
2. git pull
3. git switch <feature_branch>
4. git rebase <main_branch>
5. git push

Senario 

![git-before-rebase](./pic/git-before-rebase.png)

result

![git-after-rebase](./pic/git-after-rebase.png)

### Rebase conflict handling

- Happens when both branch edit the same part of a file.
    - open file --> remove conflict marker --> keep correct logic
    - After fixing use `git add <file(s)>` --> `git rebase --continue`
  
### Cleaning **After merge**

- Delete remote branch `git push --delete <remote_repository> <branch_name>`
- Delete local branch `git branch -d <branch_name>`


