CI
CD
pipeline
build
test
deploy

---

# CI (Continuous Integration)

- Merge code frequently; run automated build and tests on every change.
- Reduces merge conflicts and finds bugs early.
- Typical: commit → trigger pipeline → build → unit/integration tests → report.

# CD (Continuous Delivery / Deployment)

- **Continuous Delivery**: Code is always deployable; release to production is a manual decision.
- **Continuous Deployment**: Every passing pipeline can deploy to production automatically.

# Pipeline

- Automated workflow: stages run in order (e.g. build → test → deploy).
- Fail fast: if one stage fails, later stages often skip.
- Defined as code (YAML, Jenkinsfile, etc.).

# Build

- Compile, package, or build artifacts (e.g. Docker image, binary).
- Caching and layers speed up repeated runs.

# Test

- Unit tests, integration tests, e2e; run in pipeline before deploy.
- Quality gates can block merge or deploy.

# Deploy

- Push artifacts to environment (staging, production).
- Strategies: rolling, blue-green, canary (tool-dependent).
