# Expressions and Contexts

- `${{ }}` is the expression syntax used in YAML values for dynamic data (on, env, if, run, etc.).
- Contexts provide runtime data: `github`, `env`, `secrets`, `job`, `steps`, `matrix`, `vars`.
- Step and job outputs pass values between steps and jobs using `$GITHUB_OUTPUT` and `needs.<job>.outputs`.

# Architecture

```text
Context Object Hierarchy:

${{ <context>.<property> }}

github ─── repository, ref, sha, actor, event_name
│          event (full payload), run_id, run_number
│          base_ref, head_ref (PR only)
│
env ────── workflow-level, job-level, step-level vars
│
secrets ── GITHUB_TOKEN, repo secrets, org secrets, env secrets
│
job ────── status, container
│
steps ──── <step_id>.outcome, <step_id>.outputs.<key>
│
matrix ─── current combination values (e.g. matrix.node)
│
needs ──── <job_id>.result, <job_id>.outputs.<key>
│
vars ───── repository/org-level configuration variables
```

# Mental Model

```text
Expression evaluation flow:

  [1] GitHub reads YAML and finds ${{ ... }} expressions
      |
      v
  [2] Expressions are evaluated BEFORE the shell sees them
      |   - `${{ secrets.TOKEN }}` → masked value injected
      |   - `${{ github.ref }}` → "refs/heads/main"
      |
      v
  [3] Functions evaluated: contains(), startsWith(),
      |   hashFiles(), format(), toJSON(), fromJSON()
      |
      v
  [4] `if:` conditions evaluated as boolean
      |   - Truthy: non-empty string, non-zero number
      |   - Falsy: empty string, 0, null, false
      |
      v
  [5] Step outputs written at runtime via $GITHUB_OUTPUT
      |   - Available to later steps: steps.<id>.outputs.<key>
      |   - Promoted to job output: needs.<job>.outputs.<key>
```

# Core Building Blocks

### github Context

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
- `${{ }}` expressions are evaluated by GitHub Actions before the shell sees them.
- `github.ref` returns the full ref path (e.g. `refs/heads/main`), not just the branch name.
- `github.head_ref` and `github.base_ref` are only available on `pull_request` events.

### env Context

- **env** — environment variables; **env.MY_VAR** in steps; set at **workflow**, **job**, or **step** level.
- **run**: **echo $MY_VAR** (shell expands); or **echo ${{ env.MY_VAR }}** (Actions expands first).
- Job B can use **needs.job_a.outputs.out_var** if job A sets **outputs**.

### secrets Context

- **secrets.GITHUB_TOKEN** — automatic token; **secrets.MY_SECRET** — repo or org secret.
- **Never** echo or log secrets; they are masked in logs when possible.
- **If** expression can check **secrets.MY_SECRET != ''** but don't expose value.

### job and steps Context

- **job.status** — success, failure, cancelled; **job.container** — container id if job has container.
- **steps.<step_id>.outcome** — success, failure, cancelled, skipped; **steps.<step_id>.outputs.** — outputs from that step.
- **steps.<step_id>.conclusion** — same as outcome for completed steps; use in **if** for next step: **if: steps.build.outcome == 'success'**.

### outputs — Step and Job

- **Step outputs**: Step with **id:** can set **outputs.name: value**; value often from **run: echo "value" >> $GITHUB_OUTPUT** (multiline: delimiter).
- **Job outputs**: **outputs.out_name: ${{ steps.step_id.outputs.name }}**; other jobs: **needs.this_job.outputs.out_name**.
- Use to pass version, path, or flag between steps or jobs.
- Step outputs use `echo "key=value" >> $GITHUB_OUTPUT`; the old `::set-output` syntax is deprecated.
- Job outputs require both a step `id:` and a job-level `outputs:` mapping.

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

### matrix Context

- **matrix.node** — current value in matrix (e.g. 18 or 20); **matrix** is the full object.
- Use in **run** or **env**: **node-version: ${{ matrix.node }}**; **if** can filter: **if: matrix.os == 'ubuntu-latest'**.

### hashFiles

- **hashFiles('path/glob')** — hash of file contents; use for **cache key** so cache invalidates when files change.
- **hashFiles('**/package-lock.json')** — hash of all lockfiles; **hashFiles('**/*.go')** — all Go files.
- Result is deterministic; same files produce the same key.
- `hashFiles()` is deterministic — same file contents always produce the same hash.

### format() and fromJSON

- **format('Hello {0}', github.actor)** — string format; **fromJSON('{"a":1}')** — parse JSON; use **toJSON** for output.
- Useful for dynamic matrix or env from one output.
- `toJSON(context)` is the best debugging tool for inspecting available context values.
- `fromJSON()` can dynamically generate matrix values from a previous step's output.

Related notes: [002-workflow-syntax](./002-workflow-syntax.md), [006-reusable-workflows-debugging](./006-reusable-workflows-debugging.md)

---

# Troubleshooting Guide

### Expression evaluates to empty string
1. Check context spelling: `github.ref` not `github.refs` — typos return empty.
2. Check event type: `github.head_ref` is only available on `pull_request` events.
3. Use `toJSON(github)` in a debug step to inspect available context values.

### Output not passed between jobs
1. Ensure source step has `id:` set and writes to `$GITHUB_OUTPUT`.
2. Job must declare `outputs:` mapping step output to job output.
3. Consuming job must have `needs:` referencing the source job.
4. Syntax: `${{ needs.<job_id>.outputs.<output_name> }}`.

### if condition not working as expected
1. Boolean comparison: use `== true` not `== 'true'` for boolean contexts.
2. String comparison is case-sensitive.
3. `github.ref` includes full path: `refs/heads/main` not just `main`.
4. Use `contains()`, `startsWith()`, `endsWith()` for partial matching.
