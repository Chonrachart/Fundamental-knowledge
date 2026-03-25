# Gitflow and Branching Strategies

- Branching strategies define **how** a team creates, names, merges, and releases branches — they bring consistency to collaboration
- The right strategy depends on team size, release cadence, and CI/CD maturity — there is no universal best choice
- The three dominant strategies are **GitHub Flow** (simple), **Gitflow** (structured), and **Trunk-Based Development** (fast)

# Architecture

```text
GITHUB FLOW (simple)
=====================
  main ──●──●──●──●──●──●──●──●──●──  (always deployable)
          \          /
           ●──●──●──               feature branch (short-lived)
              PR + review


GITFLOW (structured)
=====================
  main    ──●────────────────●────────●──  (production releases)
             \              / \      /
  release     \      ●──●──   \    /       release/1.0
               \    /          \  /
  develop  ──●──●──●──●──●──●──●──●──     (integration branch)
              \       /   \       /
  feature      ●──●──      ●──●──         feature/* branches
                                    \
  hotfix                             ●──   hotfix/* (from main, merges to main + develop)


TRUNK-BASED DEVELOPMENT
=========================
  main ──●──●──●──●──●──●──●──●──●──●──  (trunk — everyone commits here)
          \  /       \  /
           ●          ●                   very short-lived branches (hours, not days)
                                          feature flags hide incomplete work
```

# Mental Model

```text
CHOOSING A STRATEGY:
  How often do you release?
    |
    +-> Every merge / continuously? -----> GitHub Flow or Trunk-Based
    |
    +-> On a schedule (weekly/monthly)? -> Gitflow
    |
    +-> Multiple versions in production? -> Gitflow (with release branches)

  How mature is your CI/CD?
    |
    +-> Full pipeline, feature flags? ---> Trunk-Based
    |
    +-> Basic CI, manual QA? -----------> Gitflow
    |
    +-> CI with auto-deploy? -----------> GitHub Flow
```

```bash
# GitHub Flow example
$ git checkout -b feature/add-search main
$ # ... develop and commit ...
$ git push -u origin feature/add-search
$ gh pr create --title "Add search feature" --body "Implements full-text search"
$ # ... review, approve, merge via PR ...
$ # main is deployed automatically
```

# Core Building Blocks

### Why branching strategies matter

- Without a strategy, teams create ad-hoc branches that conflict, stall, or get abandoned
- A shared strategy answers: where do I branch from? where do I merge to? how do I release?
- Reduces merge conflicts — everyone follows predictable patterns
- Enables automation — CI/CD pipelines can key off branch naming conventions
- Makes onboarding easier — new engineers learn one workflow, not per-person habits

Related notes: [003-git-branch](./003-git-branch.md)

### GitHub Flow

- **One long-lived branch**: `main` — always deployable
- **Workflow**: create feature branch from `main` --> commit --> push --> open PR --> review --> merge --> deploy
- Feature branches are short-lived (days, not weeks)
- Every merge to `main` triggers deployment
- No `develop` branch, no release branches — simplicity is the point
- **Best for**: continuous deployment, small teams, SaaS products
- **Limitation**: no concept of release staging or multiple versions in production

```text
  GITHUB FLOW - step by step:
  1. git checkout -b feature/x main
  2. ... make commits ...
  3. git push -u origin feature/x
  4. Open Pull Request against main
  5. Code review + CI checks pass
  6. Merge PR (squash or merge commit)
  7. main is deployed automatically
  8. Delete feature branch
```

Related notes: [003-git-branch](./003-git-branch.md), [005-git-pull-request](./005-git-pull-request.md)
- **Team size 1-5, deploying continuously** --> GitHub Flow

### Gitflow

- **Two long-lived branches**: `main` (production) and `develop` (integration)
- **Three short-lived branch types**:
  - `feature/*` — branch from `develop`, merge back to `develop`
  - `release/*` — branch from `develop`, merge to `main` AND `develop`
  - `hotfix/*` — branch from `main`, merge to `main` AND `develop`
- Release branches allow final QA, version bumps, and changelog prep without blocking feature work
- Hotfix branches enable emergency patches without touching the development pipeline
- Tags mark each merge to `main` with a version number
- **Best for**: scheduled releases, larger teams, products with versioned deployments
- **Limitation**: overhead of maintaining two long-lived branches, more merge operations

```text
  GITFLOW - branch lifecycle:

  feature:  develop ──> feature/login ──> develop (PR merge)
  release:  develop ──> release/1.2 ──> main + develop (tag v1.2.0)
  hotfix:   main ──> hotfix/crash-fix ──> main + develop (tag v1.2.1)

  Key rules:
  - Never commit directly to main or develop
  - Feature branches only merge to develop
  - Only release and hotfix branches touch main
  - After merging to main, always tag the commit
```

```bash
# Gitflow commands
git checkout -b feature/payment develop            # feature from develop
git checkout develop && git merge feature/payment   # merge back to develop
git checkout -b release/1.2.0 develop              # cut release branch
git checkout main && git merge release/1.2.0       # release to main
git tag -a v1.2.0 -m "Release 1.2.0"              # tag the release
git checkout develop && git merge release/1.2.0    # sync release back to develop
git checkout -b hotfix/critical main               # hotfix from main
git checkout main && git merge hotfix/critical     # fix to main
git checkout develop && git merge hotfix/critical  # fix to develop too
```

Related notes: [003-git-branch](./003-git-branch.md), [004-git-remote-repository](./004-git-remote-repository.md)

### Trunk-Based Development

- **One branch**: `main` (the trunk) — all developers commit here
- Short-lived feature branches are optional (merge within hours, one day max)
- **Feature flags** hide incomplete work — code is deployed but features are toggled off
- Requires mature CI/CD: fast builds, comprehensive automated tests, monitoring
- Avoids long-lived branches entirely — no merge hell, no stale branches
- **Best for**: teams with strong CI/CD, rapid iteration, microservices
- **Limitation**: requires discipline, feature flag infrastructure, and fast test suites

```text
  TRUNK-BASED - flow:
  1. Pull latest main
  2. Make small, incremental change (or short branch, <1 day)
  3. All tests pass locally
  4. Push to main (or merge tiny PR)
  5. CI builds + deploys automatically
  6. Feature flag controls user visibility
```

Related notes: [003-git-branch](./003-git-branch.md), [005-git-pull-request](./005-git-pull-request.md)
- **Team with mature CI/CD, feature flags, rapid deploys** --> Trunk-Based Development

### Strategy comparison

| Aspect | GitHub Flow | Gitflow | Trunk-Based |
|---|---|---|---|
| Complexity | Low | High | Low |
| Long-lived branches | `main` only | `main` + `develop` | `main` only |
| Best for | CD, small teams | Scheduled releases | Mature CI/CD teams |
| Release model | Every merge | Release branches | Continuous |
| Hotfix process | Branch from main, PR | `hotfix/*` branch | Fix on trunk directly |
| Feature isolation | Feature branches | Feature branches | Feature flags |
| Merge conflicts | Low (short branches) | Medium-High | Low (tiny changes) |
| Learning curve | Minimal | Moderate | Low (but needs infra) |

Related notes: [003-git-branch](./003-git-branch.md), [004-git-remote-repository](./004-git-remote-repository.md), [005-git-pull-request](./005-git-pull-request.md)

### Choosing the right strategy
Related notes: [003-git-branch](./003-git-branch.md), [004-git-remote-repository](./004-git-remote-repository.md)
- **Team size 5-20, scheduled releases** --> Gitflow
- You can **evolve**: start with GitHub Flow, adopt Gitflow as releases formalize, move to trunk-based as CI/CD matures
- Hybrid approaches are valid — e.g., GitHub Flow + release tags without full Gitflow
- The best strategy is the one your entire team actually follows consistently

---

# Troubleshooting Guide

```text
Develop and main are out of sync?
  |
  +-> Missed merging release/hotfix back to develop
  |     --> git checkout develop && git merge main
  |
  +-> Conflicts during merge? --> resolve manually, then commit

Feature branch is stale?
  |
  +-> Rebase onto latest base: git rebase develop (Gitflow) or git rebase main (GitHub Flow)
  |
  +-> Too many conflicts? --> merge base into feature branch instead

Hotfix needed but using GitHub Flow?
  |
  +-> Same process: branch from main, fix, PR, merge, deploy
  |
  +-> No special branch naming needed

Which strategy am I using?
  |
  +-> Have a develop branch? --> likely Gitflow
  +-> Only main + feature branches? --> GitHub Flow
  +-> Everyone pushes to main directly? --> Trunk-Based
```
