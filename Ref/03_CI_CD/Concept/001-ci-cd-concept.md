# CI/CD Concepts

- CI/CD is a set of practices that automate the building, testing, and delivery of software from code commit to production deployment.
- CI merges and validates code frequently; CD ensures code is always deployable (Delivery) or auto-deployed (Deployment).
- The pipeline is the automated workflow that connects these stages — defined as code, triggered by events, and gated by quality checks.

# Architecture

```text
Developer Workstation              Version Control              CI/CD Platform
+-------------------+             +----------------+           +---------------------------+
| Write code        |  git push   | Repository     | trigger   | Pipeline Engine           |
| Run local tests   +------------>| (main, feature +---------->| (GHA, Jenkins, GitLab CI) |
| Commit changes    |             |  branches)     |           +---------------------------+
+-------------------+             +----------------+                    |
                                        ^                               |
                                        |                    +----------+----------+
                                   merge/PR                  |          |          |
                                        |                    v          v          v
                                  +-----------+         +-------+ +--------+ +--------+
                                  | Code      |         | Build | | Test   | | Deploy |
                                  | Review    |         +-------+ +--------+ +--------+
                                  +-----------+              |         |          |
                                                             v         v          v
                                                        +---------+ +------+ +----------+
                                                        |Artifact | |Report| |Staging/  |
                                                        |Registry | |      | |Production|
                                                        +---------+ +------+ +----------+
```

# Mental Model

```text
Code change lifecycle:

  [1] Developer commits and pushes code
      |
      v
  [2] Event triggers pipeline (push, PR, schedule, manual)
      |
      v
  [3] CI phase: build artifact + run tests + static analysis
      |
      +---> FAIL: notify developer, block merge
      |
      v (PASS)
  [4] Code review + merge to main branch
      |
      v
  [5] CD phase: deploy to staging (automatic)
      |
      v
  [6] Run integration/e2e tests against staging
      |
      +---> FAIL: block promotion, notify team
      |
      v (PASS)
  [7] Deploy to production (manual approval or automatic)
      |
      v
  [8] Monitor, rollback if needed
```

Example — a typical commit flow:

```bash
# Developer pushes feature branch
git push origin feature/add-auth

# Pipeline triggers automatically:
#   1. checkout code
#   2. install dependencies (cached)
#   3. run linter
#   4. run unit tests
#   5. build Docker image
#   6. push image to registry
#   7. deploy to staging (on merge to main)
```

# Core Building Blocks

### Continuous Integration (CI)

- Practice of merging code to a shared branch frequently (at least daily).
- Every merge triggers an automated build and test cycle.
- Goal: detect integration issues early, keep the main branch stable.
- Key behaviors:
  - Developers pull main frequently and push small changes.
  - Automated tests run on every push/PR.
  - Broken builds are fixed immediately (top priority).
- Without CI: long-lived branches, painful merges, late bug discovery.
- CI = merge often + automated build/test on every change.
- Broken build = highest priority fix; never leave main broken.

Related notes: [002-pipeline-stages](./002-pipeline-stages.md), [006-testing-strategies](./006-testing-strategies.md)

### Continuous Delivery

- Extension of CI: code is always in a deployable state after passing the pipeline.
- Production deployment is a manual decision (button click, approval gate).
- Every commit that passes CI/CD pipeline could be released — but a human decides when.
- Requires: comprehensive automated tests, artifact versioning, environment parity.
- Common in regulated environments where releases need sign-off.
- Continuous Delivery = always deployable, manual release decision.

Related notes: [005-deployment-strategies](./005-deployment-strategies.md), [008-environment-management](./008-environment-management.md)

### Continuous Deployment

- Every change that passes all pipeline stages is automatically deployed to production.
- No manual gate between merge and production — full automation.
- Requires: high test confidence, feature flags, monitoring, automated rollback.
- Common in SaaS/web applications with fast iteration cycles.
- Risk mitigation: canary deployments, feature flags, automated health checks.
- Continuous Deployment = auto-deploy to prod on every passing pipeline.

Related notes: [005-deployment-strategies](./005-deployment-strategies.md), [010-metrics-and-dora](./010-metrics-and-dora.md)

### Pipeline

- Automated sequence of stages defined as code (YAML, Groovy, etc.).
- Triggered by events: push, PR, tag, schedule, manual dispatch.
- Fail-fast: if a stage fails, subsequent stages skip (unless configured otherwise).
- Pipelines are versioned in the repository alongside application code.
- Common platforms: GitHub Actions, GitLab CI, Jenkins, CircleCI, Azure Pipelines.
- Pipeline = automated stages defined as code, triggered by events.
- Fail fast = quick checks first, cancel on failure.
- Pipeline as code = workflow files versioned in the same repository.

Related notes: [002-pipeline-stages](./002-pipeline-stages.md), [004-pipeline-design-patterns](./004-pipeline-design-patterns.md)

### Build

- Transform source code into a deployable artifact (binary, Docker image, package).
- Caching dependencies and build layers reduces build time significantly.
- Build should be reproducible: same input produces same output.
- Output is stored in an artifact registry (Docker registry, npm, S3).
- Build once, deploy many = same artifact through all environments.

Related notes: [007-artifact-management](./007-artifact-management.md)

### Test

- Automated validation at multiple levels: unit, integration, e2e, security.
- Tests are the quality gates that determine if code can proceed.
- Fast tests run first (lint, unit); slow tests run later or in parallel.
- Test results and coverage reports feed back to the developer.

Related notes: [006-testing-strategies](./006-testing-strategies.md)

### Deploy

- Push artifacts to target environments (staging, production).
- Strategies vary: rolling, blue-green, canary — each with different risk profiles.
- Deployment should be automated, repeatable, and reversible.
- Credentials managed via secret stores, never hardcoded.

Related notes: [005-deployment-strategies](./005-deployment-strategies.md), [008-environment-management](./008-environment-management.md)
