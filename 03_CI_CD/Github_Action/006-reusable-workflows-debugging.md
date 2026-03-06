reusable workflow
call workflow
composite action
debugging
log
act
troubleshoot

---

# Reusable Workflows

- **Call** a workflow from another workflow; the **caller** triggers; **callee** runs in caller's repo (or allowed repos).
- **workflow_call** in `on:`; **inputs** and **secrets** can be passed; **outputs** from jobs can be returned.
- Use for shared "build and test" or "deploy" logic; one workflow file defines steps, many workflows call it.
- **Permissions**: Callee can inherit or define; **secrets** must be passed explicitly (no automatic inheritance).

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

# Composite Actions

- **Action** in same repo: **uses: ./.github/actions/my-action**; directory has **action.yml** with **inputs**, **runs** (steps or composite).
- **Composite** action: **runs: using: composite**; **steps:** list; reuse a sequence of steps without a full workflow.
- Good for "setup Node + cache + install" or "configure AWS CLI" used in multiple jobs.

# Debugging — Enable Debug Logging

- **ACTIONS_STEP_DEBUG**: Set repo secret or org variable to **true**; enables step debug logs.
- **ACTIONS_RUNNER_DEBUG**: Runner debug logs; verbose.
- **GITHUB_ACTIONS**: **true** in workflow; use in scripts to detect CI (e.g. skip interactive).

# Logging and echo

- **echo** in run step is visible in log; **don't** echo secrets (they may be masked).
- **$GITHUB_OUTPUT** and **$GITHUB_ENV** for passing values; use **>>** to append; multiline: **delimiter** in output.
- **Add path**: **echo "path" >> $GITHUB_PATH** so subsequent steps see the path.

# act — Run Locally

- **act** (tool): Run workflows locally using Docker; **act -l** list jobs; **act -j build** run one job.
- Useful to test workflow without pushing; not 100% identical to GitHub (different runner env).
- **act -s GITHUB_TOKEN=xxx** pass secrets; **act -P ubuntu-latest=...** custom image.

# Common Failures and Fixes

- **Permission denied**: Add **permissions:** to job or workflow (e.g. contents: read, packages: write).
- **Secret not found**: Ensure secret exists in repo/org; name matches (case-sensitive); use **if: secrets.MY != ''** to skip when optional.
- **Job skipped**: Check **if** condition; **needs** (upstream job failed or was skipped).
- **Cache not found**: Key must match; first run has no cache; check **path** and **key** in actions/cache.
- **Wrong ref/context**: On pull_request, **github.ref** is refs/pull/N/merge; use **github.head_ref** or **github.base_ref** as needed.
