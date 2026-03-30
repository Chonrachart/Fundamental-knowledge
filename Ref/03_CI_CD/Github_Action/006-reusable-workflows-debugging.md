# Reusable Workflows and Debugging

- Reusable workflows (`workflow_call`) let multiple caller workflows share build/test/deploy logic from a single file.
- Composite actions bundle a sequence of steps into a reusable action defined in `action.yml`.
- Debug logging is enabled via `ACTIONS_STEP_DEBUG` secret; `act` runs workflows locally in Docker.

# Architecture

```text
Caller → Reusable Workflow Invocation:

Caller Workflow (.github/workflows/ci.yml)
  on: push
  jobs:
    call-build:
      uses: ./.github/workflows/build.yml   ──┐
      with: { node_version: '20' }            │
      secrets: inherit                         │
                                               v
Reusable Workflow (.github/workflows/build.yml)
  on: workflow_call
    inputs: { node_version }
    secrets: { token }
    outputs: { version }
  jobs:
    build:
      steps: [checkout, setup-node, npm ci, test]
      outputs: version → returned to caller
                                               │
                                               v
Caller can use: needs.call-build.outputs.version

Composite Action (.github/actions/setup/action.yml)
  runs: using: composite
  steps: [setup-node, cache, npm ci]
  → Inlined into the calling job (same runner)
```

# Mental Model

```text
Debugging flow with step outputs:

  [1] Enable debug: set ACTIONS_STEP_DEBUG secret to "true"
      |
      v
  [2] Re-run workflow → expanded debug lines in each step
      |
      v
  [3] Inspect context: add `run: echo "${{ toJSON(github) }}"`
      |   - Shows all available context values
      |
      v
  [4] Trace outputs: check step `id:` → $GITHUB_OUTPUT writes
      |   - Verify: echo "key=value" >> $GITHUB_OUTPUT
      |   - Check job `outputs:` mapping exists
      |   - Check `needs:` in consuming job
      |
      v
  [5] Local testing: `act -j <job>` to run in Docker
      - Faster iteration than push-and-wait
      - Caveat: not 100% identical to GitHub runners
```

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
