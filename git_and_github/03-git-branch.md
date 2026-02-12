# GIT Branch

### What are GIT branches

- A movable to a commit that represents an independent line of
  development

### Why to use branches

- To **isolate** work without breakeng the main project.
- Allow experimentation can merge when stable or discard easily.

![Git-Branches](./pic/git-branches.png)

### Command

```bash
git branch
```

- Lists all branches in the repository.

```bash
git branch <name>
```

- Creates a new branch at the current commit.

```bash
git branch -d <name>
```

- safely removes merged branches and `-D` forces delete.
  
```bash
git switch <name>
```

- Switches to the specified branch and updates the working directory.

### Merge

```bash
git merge <name>
```

- Combines another branch into the current one.

#### Merge Type

- **Fast-Forward merge** happen when the target branch has **No** new commits on
   target branch.

    - This only move pointer to last

Situation

![fast-forward-situation](./pic/git-before-branch-ff.png)

Merge Result

![fast-forward-result](./pic/git-merge-ff.png)

- **Three way merge** happens when both branches have new commits after diverging.
    
    - This create new commit with 2 ancestor in example from E and G
  
Situation

![three-way-merge-situation](./pic/git-before-branch_three-way.png)

Merge Result

![three-way-merge_result](./pic/git-merge-three-way.png)



  