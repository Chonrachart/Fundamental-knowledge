expression
context
github
env
secrets
job
matrix
outputs
format
hashFiles

---

# Expressions in GitHub Actions

- **${{ }}** — expression syntax; use in **value** of YAML (on, env, if, steps.run, etc.).
- **if** conditions use expressions; **env** and **run** can use **${{ }}** for dynamic values.
- **Contexts** provide data: **github**, **env**, **secrets**, **job**, **steps**, **matrix**, **vars**, etc.

# github Context

- **github.repository** — owner/repo (e.g. octocat/hello-world).
- **github.ref** — ref that triggered (e.g. refs/heads/main, refs/tags/v1.0).
- **github.sha** — commit SHA; **github.event_name** — push, pull_request, etc.
- **github.actor** — user who triggered; **github.run_id**, **github.run_number** — run identifiers.
- **github.base_ref** — base branch (for pull_request); **github.head_ref** — head branch.
- **github.event** — full event payload (e.g. github.event.pull_request.title).

```yaml
- run: echo "Branch ${{ github.ref }}"
- run: echo "SHA ${{ github.sha }}"
```

# env Context

- **env** — environment variables; **env.MY_VAR** in steps; set at **workflow**, **job**, or **step** level.
- **run**: **echo $MY_VAR** (shell expands); or **echo ${{ env.MY_VAR }}** (Actions expands first).
- Job B can use **needs.job_a.outputs.out_var** if job A sets **outputs**.

# secrets Context

- **secrets.GITHUB_TOKEN** — automatic token; **secrets.MY_SECRET** — repo or org secret.
- **Never** echo or log secrets; they are masked in logs when possible.
- **If** expression can check **secrets.MY_SECRET != ''** but don’t expose value.

# job and steps Context

- **job.status** — success, failure, cancelled; **job.container** — container id if job has container.
- **steps.<step_id>.outcomes** — success, failure, cancelled, skipped; **steps.<step_id>.outputs.** — outputs from that step.
- **steps.<step_id>.conclusion** — same as outcome for completed steps; use in **if** for next step: **if: steps.build.outcome == 'success'**.

# outputs — Step and Job

- **Step outputs**: Step with **id:** can set **outputs.name: value**; value often from **run: echo "value" >> $GITHUB_OUTPUT** (multiline: delimiter).
- **Job outputs**: **outputs.out_name: ${{ steps.step_id.outputs.name }}**; other jobs: **needs.this_job.outputs.out_name**.
- Use to pass version, path, or flag between steps or jobs.

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.meta.outputs.version }}
    steps:
    - id: meta
      run: echo "version=1.0.0" >> $GITHUB_OUTPUT
  deploy:
    needs: build
    steps:
    - run: echo ${{ needs.build.outputs.version }}
```

# matrix Context

- **matrix.node** — current value in matrix (e.g. 18 or 20); **matrix** is the full object.
- Use in **run** or **env**: **node-version: ${{ matrix.node }}**; **if** can filter: **if: matrix.os == 'ubuntu-latest'**.

# hashFiles

- **hashFiles('path/glob')** — hash of file contents; use for **cache key** so cache invalidates when files change.
- **hashFiles('**/package-lock.json')** — hash of all lockfiles; **hashFiles('**/*.go')** — all Go files.
- Result is deterministic; same files → same key.

# format() and fromJSON

- **format('Hello {0}', github.actor)** — string format; **fromJSON('{"a":1}')** — parse JSON; use **toJSON** for output.
- Useful for dynamic matrix or env from one output.
