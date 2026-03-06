workflow
job
step
trigger
runner

---

# GitHub Actions

- CI/CD built into GitHub; workflows in YAML under `.github/workflows/`.
- Triggers: push, pull_request, schedule, workflow_dispatch, etc.

# Workflow

- Top-level unit; one YAML file per workflow.
- Contains jobs; jobs run on runners (GitHub-hosted or self-hosted).

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

# Job

- Set of steps; runs on one runner; steps run in order.
- Jobs in same workflow can run in parallel or depend on each other (`needs`).

# Step

- Single task: run a script or use an action (`uses`).
- `run`: shell command. `uses`: reusable action (e.g. `actions/checkout@v4`).

# Trigger

- `on`: defines when workflow runs (push, pull_request, schedule, etc.).
- Filters: branches, paths, tags.

# Common Patterns

- Checkout repo: `actions/checkout@v4`
- Cache: `actions/cache` for npm, pip, etc.
- Build and push Docker: `docker/build-push-action`, login with `docker/login-action`.
- Secrets: `secrets.GITHUB_TOKEN`, repo secrets in Settings.
