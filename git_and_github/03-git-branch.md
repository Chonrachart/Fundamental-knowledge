# GIT Branch

### What are GIT branches

- A pointer to a commit that represents an independent line of
  development

### Why to use branches

- To **isolate** work without breakeng the main project.
- Allow experimentation can merge when stable or discard easily.

![Git-Branches](./pic/git-branches.png)

### Command

```bash
git branch
```

- This command use for list all branch in Repository.

```bash
git branch <name>
```

- This command use for create new branch.

```bash
git branch -d <name>
```

- safely removes merged branches and `-D` forces delete.
  
```bash
git switch <name>
```

- This command will change working directory to that branch's snapshot.

### Merge

```bash
git merge <name>
```

- Combines another branch into the current one.




  