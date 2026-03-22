# CI/CD Best Practices

- Best practices optimize pipelines for speed (fast feedback), safety (security gates), and sustainability (maintainable config).
- The goal is a pipeline that developers trust: fast enough to not skip, secure enough to catch issues, simple enough to debug.
- Key principle: treat pipeline configuration as production code — version, review, test, and refactor it.

# Architecture

```text
Best Practice Layers in a CI/CD Pipeline:

+------------------------------------------------------------------+
|                        DEVELOPER EXPERIENCE                       |
|  Fast feedback | Clear errors | Self-service | Local reproduction |
+------------------------------------------------------------------+
        |                    |                    |
        v                    v                    v
+----------------+  +------------------+  +------------------+
| SPEED          |  | SECURITY         |  | MAINTAINABILITY  |
|                |  |                  |  |                  |
| - Caching      |  | - Secret mgmt   |  | - DRY config     |
| - Parallelism  |  | - Least priv     |  | - Reusable wf    |
| - Fail fast    |  | - Dep scanning   |  | - Clear naming   |
| - Incremental  |  | - Image signing  |  | - Documentation  |
| - Shallow clone|  | - Pin versions   |  | - Small focused  |
+----------------+  +------------------+  +------------------+
        |                    |                    |
        v                    v                    v
+------------------------------------------------------------------+
|                     QUALITY GATES                                 |
|  Tests pass | Coverage threshold | No critical findings | Review  |
+------------------------------------------------------------------+
        |
        v
+------------------------------------------------------------------+
|                     OBSERVABILITY                                 |
|  Pipeline metrics | Build duration trends | Flaky test tracking   |
+------------------------------------------------------------------+
```

# Mental Model

```text
Optimizing a pipeline — decision flow:

  [1] Is the pipeline slow (>10 min)?
      |
      +--YES--> Cache dependencies? Parallelize jobs? Shallow clone?
      |          Split tests by speed tier?
      v
  [2] Are tests flaky (intermittent failures)?
      |
      +--YES--> Quarantine flaky tests. Fix root cause. Retry is a bandaid.
      |
      v
  [3] Are secrets secure?
      |
      +--NO---> Move to platform secret store. Rotate. Scope to environment.
      |
      v
  [4] Is config duplicated across workflows?
      |
      +--YES--> Extract reusable workflows or composite actions.
      |
      v
  [5] Can developers reproduce failures locally?
      |
      +--NO---> Add clear error messages. Support local running (act, docker).
      |
      v
  [6] Are pipeline changes reviewed?
      |
      +--NO---> Require PR review for workflow file changes. Add CI for CI.
```

Example — caching in GitHub Actions:

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: 20
    cache: 'npm'    # auto-caches ~/.npm based on package-lock.json

# Or explicit cache:
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: npm-${{ hashFiles('package-lock.json') }}
    restore-keys: npm-
```

# Core Building Blocks

### Fast Feedback

- Pipeline should complete in under 10 minutes for the CI phase.
- Run fastest checks first: lint (seconds), unit tests (minutes), then slower stages.
- Use parallelism: independent jobs run simultaneously (lint + unit + build).
- Cancel redundant runs: when a new push arrives, cancel the old pipeline run.
- Incremental testing: only run tests affected by changed files (when tooling supports it).
- Shallow clone: `fetch-depth: 1` skips history; full clone only when needed (changelog, blame).
- Target CI pipeline time: under 10 minutes for developer feedback.

```yaml
# Cancel redundant runs in GitHub Actions
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Related notes: [004-pipeline-design-patterns](./004-pipeline-design-patterns.md), [010-metrics-and-dora](./010-metrics-and-dora.md)

### Security in Pipelines

- Never log or expose secrets; use platform secret stores (GitHub Secrets, Vault).
- Pin actions and images by SHA digest, not mutable tags (`actions/checkout@<sha>`).
- Scan dependencies for vulnerabilities (`Dependabot`, `Snyk`, `Trivy`).
- Apply least privilege: scoped tokens, minimal permissions, OIDC for cloud access.
- SAST/DAST in pipeline; gate on critical/high severity findings.
- Require code review for workflow file changes (prevent malicious pipeline modification).
- Pin actions and images by SHA, not mutable tags.

Related notes: [009-ci-cd-security](./009-ci-cd-security.md)

### Maintainability

- Keep workflow files small and focused — one workflow per concern.
- Use reusable workflows for shared logic (build-and-test, deploy).
- Use composite actions for repeated step sequences (setup-node + cache + install).
- Name jobs and steps clearly — `name: Run unit tests` not `name: Step 3`.
- Document required secrets, env vars, and manual steps in a README or comments.
- Version workflow files; test changes in PRs before merging to main.
- Reusable workflows and composite actions keep config DRY.

Related notes: [004-pipeline-design-patterns](./004-pipeline-design-patterns.md)

### Caching Strategy

- Cache package manager directories keyed on lockfile hash.
- Common cache targets:
  - Node: `~/.npm` or `node_modules` keyed on `package-lock.json`.
  - Python: `~/.cache/pip` keyed on `requirements.txt` or `poetry.lock`.
  - Go: `~/go/pkg/mod` keyed on `go.sum`.
  - Docker: layer cache with `cache-from` / `cache-to` in `buildx`.
- Invalidate cache when lockfile or install script changes.
- Set restore-keys for partial cache hits (prefix match).
- Monitor cache hit rate; stale caches waste storage without benefit.
- Cache on lockfile hash; invalidate when dependencies change.

Related notes: [002-pipeline-stages](./002-pipeline-stages.md)

### Secrets Management

- Store in platform secret store (`GitHub Secrets`, `GitLab CI variables`) or external vault.
- Never commit secrets to the repository — use `.gitignore` and pre-commit hooks.
- Scope secrets to environments (staging secrets separate from production).
- Rotate secrets regularly; use short-lived tokens where possible (`OIDC`).
- Mask secrets in logs (most platforms do this automatically for registered secrets).
- Audit secret access: who added, who can read, when last rotated.
- Secrets belong in platform stores, never in code or logs.

Related notes: [009-ci-cd-security](./009-ci-cd-security.md), [008-environment-management](./008-environment-management.md)

### Pipeline as Code

- Define pipelines in version-controlled files (`.github/workflows/*.yml`, `Jenkinsfile`).
- Pipeline changes go through the same review process as application code.
- Test pipeline changes in feature branches before merging.
- Use linters for pipeline config (`actionlint` for GHA, `yamllint` for YAML).
- Keep pipeline logic in the pipeline file; complex logic belongs in scripts.
- Pipeline config is production code — review, lint, and test it.

Related notes: [001-ci-cd-concept](./001-ci-cd-concept.md)

### Idempotent Deployments

- Running a deployment twice with the same input should produce the same result.
- Avoid side effects: don't create duplicate resources, don't append to configs.
- Use declarative tools (Kubernetes manifests, `Terraform`) over imperative scripts.
- Database migrations must be forward-only and safe to re-run (use migration frameworks).
- Tag deployments with version; same version redeployed should be a no-op.
- Idempotent deployments: same input, same result, every time.

Related notes: [005-deployment-strategies](./005-deployment-strategies.md), [011-gitops](./011-gitops.md)

### Flaky Test Management

- Flaky tests erode trust in the pipeline — developers start ignoring failures.
- Detection: track test pass/fail history; flag tests that flip without code changes.
- Quarantine: move flaky tests to a non-blocking suite until fixed.
- Fix patterns: timing issues (add proper waits), shared state (isolate tests), external deps (mock or retry).
- Never "fix" by adding blind retries — retries hide the real problem.
- Metric: track flaky test rate; target zero flaky tests in the blocking suite.
- Flaky tests must be quarantined and fixed, not retried blindly.

Related notes: [006-testing-strategies](./006-testing-strategies.md)

---

# Troubleshooting Guide

### Pipeline takes too long (>15 minutes)

1. Profile each job: check timestamps in the pipeline log.
2. Identify the slowest step — often dependency install or e2e tests.
3. Add caching for dependencies (check cache hit rate in logs).
4. Parallelize independent jobs (lint, unit, build can run simultaneously).
5. Use shallow clone if full git history is not needed.
6. Consider splitting the test suite across multiple parallel runners.

### Flaky tests causing false failures

1. Check test history: does this test fail intermittently without code changes?
2. Common causes: timing/race conditions, shared mutable state, network calls.
3. Quarantine the flaky test (move to non-blocking suite).
4. Fix root cause: add proper waits, isolate state, mock external dependencies.
5. Track flaky test rate as a pipeline health metric.

### Secret leaked in logs

1. Immediately rotate the exposed secret.
2. Check if the secret was properly registered in the platform secret store (auto-masking).
3. Review the step that leaked: avoid `echo $SECRET` or debug logging that prints env vars.
4. Add a pre-commit hook to scan for secrets (`gitleaks`, `detect-secrets`).
5. Audit git history: if secret was committed to code, it exists in all clones.
