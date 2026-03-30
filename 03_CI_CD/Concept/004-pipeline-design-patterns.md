# Pipeline Design Patterns

- Pipeline design patterns define how jobs are organized, ordered, and connected — from simple sequential chains to complex DAGs with fan-out, fan-in, and matrix strategies.
- The right pattern depends on project size, test speed, deployment targets, and team structure.
- Core principle: model the pipeline as a directed acyclic graph (DAG) where edges represent dependencies and data flow.

# Architecture

```text
Common Pipeline Patterns:

1. SEQUENTIAL (simple, small projects)
   [Build] --> [Test] --> [Deploy]

2. PARALLEL (independent jobs for speed)
   [Lint]  ----+
   [Unit]  ----+--> [Deploy]
   [Build] ----+

3. FAN-OUT (one source, many targets)
               +--> [Test Linux]
   [Build] ----+--> [Test macOS]
               +--> [Test Windows]

4. FAN-IN (many sources, one target)
   [Build Linux]  ---+
   [Build macOS]  ---+--> [Deploy]
   [Build Windows]---+

5. DIAMOND (fan-out then fan-in)
               +--> [Test Unit]  ---+
   [Build] ----+                    +--> [Deploy Staging]
               +--> [Test E2E]  ---+

6. MATRIX (same job, multiple configs)
   [Test] x [Node 18, Node 20] x [Ubuntu, Windows]
   = 4 parallel jobs from one definition
```

# Mental Model

```text
Choosing a pipeline pattern:

  [1] How many independent tasks exist?
      |
      +--ONE--> Sequential pattern (simple)
      |
      +--MANY--> Can they run in parallel?
                  |
                  +--YES--> Parallel or matrix pattern
                  |
                  +--NO (dependencies)--> DAG with needs/depends_on
      |
      v
  [2] Do you need to test on multiple OS/versions?
      |
      +--YES--> Matrix strategy
      |
      v
  [3] Do you build once and deploy to multiple envs?
      |
      +--YES--> Fan-out (build) --> fan-in (deploy gate)
      |
      v
  [4] Is this a monorepo with multiple services?
      |
      +--YES--> Path-filtered pipelines or dynamic matrix
      |
      v
  [5] Is deploy logic shared across repos?
      |
      +--YES--> Reusable/callable workflow
```

Example — fan-in pattern in GitHub Actions:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t myapp:${{ github.sha }} .
      - run: docker push myapp:${{ github.sha }}

  test-unit:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - run: npm test

  test-integration:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - run: npm run test:integration

  deploy-staging:
    needs: [test-unit, test-integration]    # fan-in: both must pass
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - run: ./deploy.sh staging myapp:${{ github.sha }}
```

# Core Building Blocks

### Sequential Pattern

- Jobs run one after another in a chain: A --> B --> C.
- Simple to understand and debug; no parallelism.
- Best for: small projects, few tests, simple build/test/deploy.
- Drawback: total time = sum of all job times; no speed benefit.
- In GHA: use `needs` to create the chain.
- Pipeline = directed acyclic graph (DAG); edges are job dependencies.

Related notes: [002-pipeline-stages](./002-pipeline-stages.md)

### Parallel Pattern

- Independent jobs run simultaneously to reduce total pipeline time.
- In GHA: jobs without `needs` (or with same `needs`) run in parallel.
- Best for: lint + unit tests + security scan can all start from checkout.
- Total time = slowest parallel job (not sum of all).
- Watch for runner limits: too many parallel jobs may queue.
- Parallel jobs: no `needs` = run simultaneously; total time = slowest job.

Related notes: [003-best-practices](./003-best-practices.md)

### Fan-Out / Fan-In

- **Fan-out**: one job triggers multiple downstream jobs.
  - Use case: build once, test on multiple platforms or environments.
- **Fan-in**: multiple jobs must all complete before a downstream job runs.
  - Use case: all platform tests must pass before deploy.
- In GHA: fan-in = one job with `needs: [job-a, job-b, job-c]`.
- Forms a diamond pattern when combined: build --> (test-A, test-B) --> deploy.
- Fan-in: one job with `needs: [A, B, C]` waits for all three.

Related notes: [002-pipeline-stages](./002-pipeline-stages.md)

### Matrix Strategy

- Run the same job with different parameter combinations in parallel.
- Define a matrix of values: OS versions, language versions, configurations.
- GHA generates one job per combination automatically.
- Use `exclude` to skip specific combinations; `include` to add extra cases.
- Best for: cross-platform testing, multi-version compatibility.
- Matrix: same job, multiple parameter combinations, auto-parallelized.

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest]
    node: [18, 20]
  fail-fast: false    # don't cancel others if one fails
```

Related notes: [006-testing-strategies](./006-testing-strategies.md)

### Branch Strategy and Triggers

- **Feature branches**: run CI (build + test) on every push and PR.
- **main/master**: run CI + deploy to staging on merge; protect with branch rules.
- **Release branches/tags**: trigger production deployment pipeline.
- Control with trigger filters:
  - `on.push.branches: [main]` — run on push to main.
  - `on.pull_request.branches: [main]` — run on PR targeting main.
  - `on.push.tags: ['v*']` — run on version tags.
- Use `if: github.ref == 'refs/heads/main'` in jobs for conditional logic.
- Branch strategy: feature = CI only; main = CI + staging; tag = production.

Related notes: [008-environment-management](./008-environment-management.md)

### Environment Promotion

- Build artifact once; promote the same artifact through environments.
- Flow: build --> deploy staging --> test staging --> deploy production.
- Never rebuild for production — same image/binary, different config.
- Tag artifacts with git SHA or semantic version for traceability.
- Promotion may require manual approval (GHA: `environment: production`).
- Build once, promote: same artifact through staging and production.

Related notes: [007-artifact-management](./007-artifact-management.md), [008-environment-management](./008-environment-management.md)

### Reusable Workflows

- Extract common pipeline logic into callable workflows.
- Caller workflow uses `uses: ./.github/workflows/reusable.yml` or cross-repo reference.
- Pass inputs (parameters) and secrets from caller to callee.
- Best for: shared build-test, deploy logic across multiple repos or services.
- Composite actions: reusable step sequences (smaller scope than workflows).
- Reusable workflows: `workflow_call` for shared logic across repos.

```yaml
# Reusable workflow (callee)
on:
  workflow_call:
    inputs:
      environment:
        type: string
        required: true

# Caller workflow
jobs:
  deploy:
    uses: ./.github/workflows/deploy.yml
    with:
      environment: staging
    secrets: inherit
```

Related notes: [003-best-practices](./003-best-practices.md)

### Monorepo Pipelines

- Monorepo: multiple services/packages in one repository.
- Challenge: don't run all pipelines for every change — only affected services.
- Path filtering: trigger workflows based on which files changed.
- Dynamic matrix: generate a list of affected services, run tests for each.

```yaml
on:
  push:
    paths:
      - 'services/api/**'
      - 'libs/shared/**'     # shared lib changes affect api too
```

- Tools: `Nx`, `Turborepo`, `Bazel` for intelligent dependency-aware task running.
- Alternatively: one workflow per service, each with path filters.
- Path filters: trigger only affected service pipelines in monorepos.

Related notes: [003-best-practices](./003-best-practices.md)
