# Workflow Syntax

- The `on:` key defines triggers (push, pull_request, schedule, workflow_dispatch, etc.) with branch/path/tag filters.
- Jobs declare a runner, optional matrix strategy, environment variables, and conditional execution.
- `needs:` creates a DAG between jobs; `concurrency:` prevents duplicate runs on the same branch.

# Architecture

```text
Workflow YAML Structure:

.github/workflows/ci.yml
├── name: CI                    # display name
├── on:                         # triggers
│   ├── push: { branches, paths, tags }
│   ├── pull_request: { branches, paths }
│   ├── schedule: [{ cron }]
│   └── workflow_dispatch: { inputs }
├── permissions:                # GITHUB_TOKEN scope
├── env:                        # workflow-level env vars
├── concurrency:                # prevent duplicate runs
│   ├── group: ${{ github.ref }}
│   └── cancel-in-progress: true
└── jobs:
    ├── build:
    │   ├── runs-on: ubuntu-latest
    │   ├── strategy: { matrix }
    │   ├── env:                # job-level env vars
    │   ├── if:                 # conditional execution
    │   └── steps: [...]
    └── deploy:
        ├── needs: [build]      # DAG dependency
        └── steps: [...]
```

# Mental Model

```text
How GitHub parses and executes a workflow:

  [1] Event fires (push, PR, schedule, dispatch)
      |
      v
  [2] GitHub finds workflows matching `on:` triggers
      |   - Checks branch/path/tag filters
      |   - Schedule only fires on default branch
      |
      v
  [3] Concurrency check
      |   - Same group running? Cancel old or queue new
      |
      v
  [4] Jobs form a DAG via `needs:`
      |   - No `needs:` = parallel execution
      |   - `needs: [a, b]` = wait for both
      |
      v
  [5] Each job: pick runner → expand matrix → run steps
      |   - Matrix generates N job instances
      |   - fail-fast cancels siblings on failure
      |
      v
  [6] Steps run sequentially within a job
      - `if:` evaluated before each step
      - Outputs flow: step → job → downstream job
```

# Core Building Blocks

### on (Triggers)

- **push**: On push to branch; filter by branches, tags, paths.
- **pull_request**: On PR open/sync; filter by branches, paths.
- **workflow_dispatch**: Manual run from Actions tab; optional inputs.
- **schedule**: Cron; e.g. `0 2 * * *` (2 AM daily).
- **repository_dispatch**, **workflow_call**: External or other workflow.

```yaml
on:
  push:
    branches: [main]
    paths-ignore: ['**.md']
  pull_request:
    branches: [main]
  workflow_dispatch:
    inputs:
      env:
        required: true
        default: staging
```
- `on.push.paths-ignore` skips workflows when only matching files change (e.g. docs-only commits).
- `workflow_dispatch` allows manual triggers with typed inputs from the Actions tab.
- Schedule cron triggers only fire on the default branch.

### jobs

- Each job has id; runs on a runner; contains steps.
- **runs-on**: Runner (ubuntu-latest, windows-latest, self-hosted label).
- **env**: Env vars for all steps in job; override per step.
- **if**: Condition to run job (e.g. `if: github.ref == 'refs/heads/main'`).

### strategy and matrix

- **matrix**: Run job with multiple combinations (e.g. node version, OS).
- **strategy.fail-fast**: If true, cancel remaining matrix jobs when one fails.
- **strategy.max-parallel**: Limit concurrent matrix jobs.

```yaml
strategy:
  matrix:
    node: [18, 20]
    os: [ubuntu-latest, windows-latest]
steps:
- uses: actions/setup-node@v4
  with:
    node-version: ${{ matrix.node }}
```
- `strategy.matrix` generates a job instance for each combination of values.
- `strategy.fail-fast: false` lets all matrix jobs finish even if one fails.

### needs

- Job runs only after needed jobs succeed; defines DAG.
- **needs: [build]** — run test only after build; use outputs with `job_id.outputs.output_name`.
- `needs:` creates explicit job ordering; without it, jobs run in parallel.

### Defaults and Concurrency

- **defaults.run**: Default shell, working-directory for all run steps.
- **concurrency**: Cancel in-progress runs for same concurrency group (e.g. branch); avoid duplicate deploys.
- `concurrency.group` should be scoped per branch or per environment to avoid unintended cancellations.
- `defaults.run.shell: bash` normalizes shell behavior across Linux and Windows runners.

Related notes: [001-github-actions-overview](./001-github-actions-overview.md), [003-expressions-contexts](./003-expressions-contexts.md)

---

# Troubleshooting Guide

### Schedule trigger not running
1. Cron only runs on the **default branch** — check workflow is on main/master.
2. GitHub may delay or skip scheduled runs if repo is inactive (no commits for 60 days).
3. Verify cron syntax: use [crontab.guru](https://crontab.guru) to validate.

### Matrix job failing on one OS only
1. Check path separators: `/` on Linux vs `\` on Windows.
2. Check shell differences: `bash` vs `pwsh` on Windows runners.
3. Use `defaults.run.shell: bash` to normalize across OS.

### Concurrency cancels wanted runs
1. Review `concurrency.group` — too broad groups cancel unrelated runs.
2. Set `cancel-in-progress: false` for deploy jobs (avoid interrupted deployments).
3. Use branch-specific groups: `concurrency: group: ${{ github.ref }}`.
