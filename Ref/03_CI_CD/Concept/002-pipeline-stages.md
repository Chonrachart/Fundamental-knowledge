# Pipeline Stages

- A pipeline is composed of stages (logical groups) that execute in order: checkout, build, test, deploy — each stage contains one or more jobs with steps.
- Stages are connected by dependencies and gates; artifacts pass data between stages; failures block downstream stages.
- Good stage design balances speed (parallelism) with safety (sequential gates before production).

# Architecture

```text
Pipeline Execution Flow:

+----------+     +-----------+     +------------------+     +------------------+     +-----------+
| Checkout |---->|   Build   |---->|      Test        |---->|   Security Scan  |---->|  Deploy   |
| (source) |     | (compile, |     | (unit, int, e2e) |     | (SAST, SCA,      |     | (staging, |
|          |     |  package) |     |                  |     |  license check)  |     |  prod)    |
+----------+     +-----+-----+     +--------+---------+     +--------+---------+     +-----+-----+
                       |                    |                         |                      |
                       v                    v                         v                      v
                 +-----------+       +------------+           +------------+          +------------+
                 | Artifact  |       | Test       |           | Scan       |          | Deploy     |
                 | (image,   |       | Report     |           | Report     |          | Status     |
                 |  binary)  |       | (coverage) |           | (findings) |          | (health)   |
                 +-----------+       +------------+           +------------+          +------------+

Gates between stages:
  [Build] --gate: build success--> [Test]
  [Test]  --gate: tests pass + coverage threshold--> [Security]
  [Security] --gate: no critical findings--> [Deploy Staging]
  [Deploy Staging] --gate: smoke tests pass + manual approval--> [Deploy Prod]
```

# Mental Model

```text
Stage execution within a pipeline:

  [1] Trigger event (push, PR, tag, schedule)
      |
      v
  [2] CHECKOUT: clone repo, resolve ref (branch/tag/SHA)
      |
      v
  [3] BUILD: install deps, compile, create artifact
      |         |
      |         +--> Upload artifact to registry or workflow storage
      v
  [4] TEST: download artifact, run test suites
      |         |
      |         +--> Publish results (coverage, JUnit XML)
      |
      +---> FAIL: stop pipeline, notify, block merge
      |
      v (PASS)
  [5] SECURITY SCAN: SAST on code, SCA on dependencies
      |
      +---> CRITICAL FINDING: stop pipeline
      |
      v (CLEAN)
  [6] DEPLOY STAGING: push artifact to staging env
      |
      v
  [7] SMOKE TESTS: validate staging deployment
      |
      +---> FAIL: stop, do not promote
      |
      v (PASS)
  [8] APPROVAL GATE: manual review (optional)
      |
      v
  [9] DEPLOY PRODUCTION: promote same artifact to prod
      |
      v
  [10] POST-DEPLOY: health check, notify, tag release
```

Example — GitHub Actions job dependency:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run build
      - uses: actions/upload-artifact@v4
        with:
          name: dist
          path: dist/

  test:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: dist
      - run: npm test

  deploy-staging:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - run: ./deploy.sh staging

  deploy-prod:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production    # requires approval
    steps:
      - run: ./deploy.sh production
```

# Core Building Blocks

### Checkout

- First stage: fetch repository source code into the runner workspace.
- Options: full clone, shallow clone (`fetch-depth: 1`), sparse checkout.
- Specify ref (branch, tag, commit SHA) when building specific versions.
- Shallow clone speeds up checkout significantly for large repos.
- In GitHub Actions: `actions/checkout@v4` handles auth, submodules, LFS.
- Standard stage order: checkout, build, test, scan, deploy.
- Shallow clone (`fetch-depth: 1`) speeds up checkout for large repos.

Related notes: [001-ci-cd-concept](./001-ci-cd-concept.md)

### Build

- Transform source into deployable artifacts: compile code, bundle assets, build container images.
- Caching strategies:
  - Dependency cache: key on lockfile hash (`package-lock.json`, `go.sum`).
  - Docker layer cache: reuse unchanged layers, `cache-from` previous builds.
  - Build tool cache: `.gradle`, `.m2`, `__pycache__`.
- Artifact output: upload to workflow storage (`upload-artifact`) or push to registry.
- Build should be deterministic: same source + same deps = same artifact.
- Build once, deploy the same artifact to every environment.

Related notes: [007-artifact-management](./007-artifact-management.md)

### Test — Unit

- Fastest tests; run on every commit; test individual functions/classes in isolation.
- Target: 80%+ code coverage for critical paths.
- Mock external dependencies (database, APIs) for speed and isolation.
- Fail the pipeline immediately if unit tests fail.
- Unit tests first (fast, cheap), e2e last (slow, expensive).

Related notes: [006-testing-strategies](./006-testing-strategies.md)

### Test — Integration

- Test interactions between components: app + database, app + external API.
- Slower than unit tests; may require service containers (`PostgreSQL`, `Redis`).
- In CI: use Docker Compose or service containers to spin up dependencies.
- Run after unit tests pass to avoid wasting resources.

Related notes: [006-testing-strategies](./006-testing-strategies.md)

### Test — End-to-End (E2E)

- Full user flow tests against a deployed environment (or local stack).
- Slowest and most brittle; run less frequently (on merge, nightly, pre-release).
- Tools: `Cypress`, `Playwright`, `Selenium`.
- Keep e2e suite small and focused on critical paths.

Related notes: [006-testing-strategies](./006-testing-strategies.md)

### Deploy

- Push artifacts to target environment; update running services.
- Staging deploy: automatic on merge to main; production: gated.
- Methods: `kubectl apply`, `helm upgrade`, `docker compose up`, `rsync`, cloud CLI.
- Always use the same artifact built in the build stage — never rebuild for production.
- Secrets injected at deploy time from secret store (not baked into image).

Related notes: [005-deployment-strategies](./005-deployment-strategies.md), [008-environment-management](./008-environment-management.md)

### Artifacts

- Build outputs passed between stages or stored for external consumption.
- Workflow artifacts: temporary storage within a pipeline run (GHA `upload-artifact`/`download-artifact`).
- Registry artifacts: permanent storage (Docker images in GHCR/ECR, npm packages).
- Tag artifacts with git SHA or semantic version for traceability.
- Retention policies: clean up old workflow artifacts; keep tagged releases.
- Artifacts pass data between stages; use consistent naming.

Related notes: [007-artifact-management](./007-artifact-management.md)

### Quality Gates

- Checkpoints that block pipeline progression if conditions are not met.
- Types:
  - **Merge gate**: CI must pass before PR can merge (branch protection rules).
  - **Coverage gate**: block if test coverage drops below threshold.
  - **Security gate**: block if critical or high-severity findings detected.
  - **Deploy gate**: manual approval required for production deployment.
- Configure in pipeline (job conditions) and repository settings (branch protection).
- Quality gates block progression on failure — configure in pipeline and repo settings.
- Manual approval gates protect production from unreviewed changes.

Related notes: [003-best-practices](./003-best-practices.md), [009-ci-cd-security](./009-ci-cd-security.md)

### Notifications

- Pipeline status communicated to relevant channels after key stages.
- Channels: Slack, email, GitHub status checks, webhook.
- Notify on: failure (always), success (optional), manual approval needed.
- Include: pipeline link, commit info, failure details, responsible author.
- Avoid notification fatigue: only notify on state change (success after failure).
- Notifications on failure are essential; on success are optional.

Related notes: [003-best-practices](./003-best-practices.md)
