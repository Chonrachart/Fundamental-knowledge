# GitHub Actions Overview

- CI/CD platform built into GitHub; workflows defined as YAML files under `.github/workflows/`.
- Triggers include push, pull_request, schedule, workflow_dispatch, and more.
- Workflows contain jobs that run on runners (GitHub-hosted or self-hosted); jobs contain steps.

# Architecture

```text
GitHub Repository
  └── .github/workflows/
        └── ci.yml  (Workflow)
              │
              ├── on: push/PR/schedule    (Trigger)
              │
              └── jobs:
                    ├── build:             (Job — runs on a runner)
                    │     ├── Step 1: actions/checkout@v4
                    │     ├── Step 2: run: npm install
                    │     └── Step 3: run: npm test
                    │
                    └── deploy:            (Job — needs: [build])
                          └── Step 1: ...
```

# Core Building Blocks

### Workflow

- Top-level unit; one YAML file per workflow.
- Contains jobs; jobs run on runners (GitHub-hosted or self-hosted).
- Workflow files live in `.github/workflows/` and must have `.yml` or `.yaml` extension.

```yaml
name: CI
on:
  push:
    branches: [main]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - run: npm install && npm test
```

### Job

- Set of steps; runs on one runner; steps run in order.
- Jobs in same workflow can run in parallel or depend on each other (`needs`).
- Each job runs on its own runner; steps within a job share the runner filesystem.
- Jobs run in parallel by default; use `needs:` to create dependencies.

### Step

- Single task: run a script or use an action (`uses`).
- `run`: shell command. `uses`: reusable action (e.g. `actions/checkout@v4`).
- `uses:` references a reusable action; `run:` executes a shell command.

### Trigger

- `on`: defines when workflow runs (push, pull_request, schedule, etc.).
- Filters: branches, paths, tags.
- Workflow triggers are defined under `on:` and support branch/path/tag filters.

### Common Patterns

- Checkout repo: `actions/checkout@v4`
- Cache: `actions/cache` for npm, pip, etc.
- Build and push Docker: `docker/build-push-action`, login with `docker/login-action`.
- Secrets: `secrets.GITHUB_TOKEN`, repo secrets in Settings.
- `actions/checkout@v4` is required in almost every workflow to clone the repo.
- `secrets.GITHUB_TOKEN` is auto-injected per run; scoped to the current repo.

Related notes: [002-workflow-syntax](./002-workflow-syntax.md), [004-secrets-cache](./004-secrets-cache.md), [005-real-world-examples](./005-real-world-examples.md)

---

# Troubleshooting Guide

### Workflow file not detected
1. Verify file is in `.github/workflows/` directory (exact path).
2. Check YAML syntax: `yamllint` or GitHub Actions linter.
3. File must have `.yml` or `.yaml` extension.

### Steps run but produce no output
1. Check `run:` command — ensure it prints to stdout.
2. Check `if:` condition on the step — it may be skipped silently.
3. Use `echo "::debug::message"` for debug output in logs.

### Action `uses:` fails with "not found"
1. Check action name and version: `owner/repo@version` (e.g. `actions/checkout@v4`).
2. Private actions: must be in the same repo or accessible; use `actions/checkout` first.
3. Check if action was deprecated or renamed.
