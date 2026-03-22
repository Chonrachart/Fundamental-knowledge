# Reusable Workflows and Debugging

- Reusable workflows (`workflow_call`) let multiple caller workflows share build/test/deploy logic from a single file.
- Composite actions bundle a sequence of steps into a reusable action defined in `action.yml`.
- Debug logging is enabled via `ACTIONS_STEP_DEBUG` secret; `act` runs workflows locally in Docker.

# Core Building Blocks

### Reusable Workflows

- **Call** a workflow from another workflow; the **caller** triggers; **callee** runs in caller's repo (or allowed repos).
- **workflow_call** in `on:`; **inputs** and **secrets** can be passed; **outputs** from jobs can be returned.
- Use for shared "build and test" or "deploy" logic; one workflow file defines steps, many workflows call it.
- **Permissions**: Callee can inherit or define; **secrets** must be passed explicitly (no automatic inheritance).
- Reusable workflows require `on: workflow_call` in the callee; without it, `uses:` will fail.
- `secrets: inherit` passes all caller secrets to the reusable workflow automatically.
- Cross-repo reusable workflows must reference a specific branch/tag: `org/repo/.github/workflows/file.yml@main`.

```yaml
# .github/workflows/build.yml
on:
  workflow_call:
    inputs:
      node_version:
        required: true
        type: string
    secrets:
      token:
        required: false
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node_version }}
    - run: npm ci && npm test
```

```yaml
# caller workflow
on: push
jobs:
  call-build:
    uses: ./.github/workflows/build.yml
    with:
      node_version: '20'
    secrets: inherit
```

### Composite Actions

- Action in same repo: `uses: ./.github/actions/my-action`; directory has `action.yml` with `inputs`, `runs` (steps or composite).
- Composite action: `runs: using: composite`; `steps:` list; reuse a sequence of steps without a full workflow.
- Good for "setup Node + cache + install" or "configure AWS CLI" used in multiple jobs.
- Composite actions use `runs: using: composite` in `action.yml` and define steps inline.

### Debugging — Enable Debug Logging

- **ACTIONS_STEP_DEBUG**: Set repo secret or org variable to **true**; enables step debug logs.
- **ACTIONS_RUNNER_DEBUG**: Runner debug logs; verbose.
- **GITHUB_ACTIONS**: **true** in workflow; use in scripts to detect CI (e.g. skip interactive).

### Logging and echo

- **echo** in run step is visible in log; **don't** echo secrets (they may be masked).
- **$GITHUB_OUTPUT** and **$GITHUB_ENV** for passing values; use **>>** to append; multiline: **delimiter** in output.
- **Add path**: **echo "path" >> $GITHUB_PATH** so subsequent steps see the path.

### act — Run Locally

- `act` (tool): Run workflows locally using Docker; `act -l` list jobs; `act -j build` run one job.
- Useful to test workflow without pushing; not 100% identical to GitHub (different runner env).
- `act -s GITHUB_TOKEN=xxx` pass secrets; `act -P ubuntu-latest=...` custom image.

Related notes: [001-github-actions-overview](./001-github-actions-overview.md), [003-expressions-contexts](./003-expressions-contexts.md)


- Reusable workflows require `on: workflow_call` in the callee; without it, `uses:` will fail.
- `secrets: inherit` passes all caller secrets to the reusable workflow automatically.
- Composite actions use `runs: using: composite` in `action.yml` and define steps inline.
- `ACTIONS_STEP_DEBUG` must be set as a **secret** (not a variable) to enable debug logs.
- `$GITHUB_OUTPUT` replaces the deprecated `::set-output` command for passing step outputs.
- `$GITHUB_ENV` sets environment variables available to all subsequent steps in the job.
- `act` is useful for local testing but does not perfectly replicate GitHub-hosted runner environments.
- Cross-repo reusable workflows must reference a specific branch/tag: `org/repo/.github/workflows/file.yml@main`.
---

# Troubleshooting Guide

### Reusable workflow not found
1. Check path: `uses: ./.github/workflows/build.yml` — must be relative to repo root.
2. Cross-repo: `uses: org/repo/.github/workflows/build.yml@main` — must be public or allowed in org settings.
3. Callee must have `on: workflow_call` — without it, the workflow cannot be called.

### Secrets not available in reusable workflow
1. Secrets must be explicitly passed: `secrets: inherit` or `secrets: token: ${{ secrets.MY_TOKEN }}`.
2. Check callee declares the secret in `on.workflow_call.secrets`.
3. Required secrets: if `required: true`, caller must pass it or workflow fails.

### Debug logs not showing
1. Set **ACTIONS_STEP_DEBUG** secret to `true` (not variable — must be a secret).
2. Re-run the workflow after setting the secret.
3. Debug output appears as extra lines in each step's log — expand "debug" lines.

### act produces different results than GitHub
1. `act` uses different Docker images; some GitHub-hosted runner tools may be missing.
2. Secrets must be passed explicitly: `act -s SECRET_NAME=value`.
3. Some contexts (e.g. `github.event`) may differ; use `.actrc` for defaults.
4. Network-dependent steps may fail in local Docker environment.
