on
jobs
env
matrix
strategy
needs

---

# on (Triggers)

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

# jobs

- Each job has id; runs on a runner; contains steps.
- **runs-on**: Runner (ubuntu-latest, windows-latest, self-hosted label).
- **env**: Env vars for all steps in job; override per step.
- **if**: Condition to run job (e.g. `if: github.ref == 'refs/heads/main'`).

# strategy and matrix

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

# needs

- Job runs only after needed jobs succeed; defines DAG.
- **needs: [build]** — run test only after build; use outputs with `job_id.outputs.output_name`.

# Defaults and Concurrency

- **defaults.run**: Default shell, working-directory for all run steps.
- **concurrency**: Cancel in-progress runs for same concurrency group (e.g. branch); avoid duplicate deploys.
