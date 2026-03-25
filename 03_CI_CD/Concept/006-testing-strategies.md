# Testing Strategies in CI/CD

- Testing strategy defines which tests run, when, and how in the CI/CD pipeline — from fast unit tests on every commit to slow e2e tests before release.
- The test pyramid guides investment: many fast unit tests at the base, fewer integration tests in the middle, and minimal e2e tests at the top.
- Shift-left principle: move testing earlier in the development cycle to catch defects when they are cheapest to fix.

# Architecture

```text
Test Pyramid and Pipeline Mapping:

                    /\
                   /  \         E2E Tests (few, slow, expensive)
                  / E2E\        - Run: before release, nightly, or on merge to main
                 /______\       - Time: 10-30 min
                /        \
               /Integration\    Integration Tests (moderate count)
              /   Tests     \   - Run: on PR, after unit tests pass
             /______________\   - Time: 3-10 min
            /                \
           /   Unit Tests     \  Unit Tests (many, fast, cheap)
          /                    \ - Run: on every push/commit
         /______________________\- Time: 30s-3 min

Pipeline stage mapping:
+--------+   +--------+   +-------------+   +---------+   +--------+
| Lint / |-->| Unit   |-->| Integration |-->| Security|-->| E2E    |
| Static |   | Tests  |   | Tests       |   | Scan    |   | Tests  |
| (10s)  |   | (1-3m) |   | (3-10m)     |   | (2-5m)  |   | (10-30m)|
+--------+   +--------+   +-------------+   +---------+   +--------+
  FAST <-----------------------------------------> SLOW
  EVERY COMMIT <----------------------------> PRE-RELEASE
```

# Mental Model

```text
Designing a test strategy for a service:

  [1] What are the critical paths? (login, payment, data integrity)
      |
      v
  [2] Unit tests: cover business logic, edge cases, error handling
      |   Target: 80%+ coverage on critical paths
      |
      v
  [3] Integration tests: cover service boundaries
      |   Database queries, API contracts, message queue consumers
      |
      v
  [4] E2E tests: cover critical user journeys only
      |   Login flow, checkout flow, signup flow
      |   Keep suite small (10-20 scenarios max)
      |
      v
  [5] Security scans: SAST on code, SCA on dependencies
      |   Run in parallel with tests
      |
      v
  [6] Where to run each test type:
      |
      +-- Unit: every push/commit (fast, cheap)
      +-- Integration: every PR (moderate cost)
      +-- E2E: on merge to main or nightly (expensive)
      +-- SAST/SCA: every PR (automated)
      +-- DAST: weekly or pre-release (requires running app)
```

Example — test stages in GitHub Actions:

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm run lint

  unit-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm test -- --coverage
      - uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/

  integration-test:
    needs: unit-test
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: test
        ports: ['5432:5432']
    steps:
      - uses: actions/checkout@v4
      - run: npm run test:integration

  e2e-test:
    needs: integration-test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm run test:e2e
```

# Core Building Blocks

### Test Pyramid

- Shape: many unit tests (base), fewer integration tests (middle), minimal e2e tests (top).
- Rationale: unit tests are fast, cheap, and reliable; e2e tests are slow, expensive, and brittle.
- Anti-pattern: inverted pyramid (many e2e, few unit) — slow pipelines, flaky results.
- Anti-pattern: ice cream cone (heavy manual testing, few automated tests).
- Goal: maximize confidence while minimizing pipeline time.
- Test pyramid: many unit (fast, cheap), fewer integration, minimal e2e (slow, expensive).

Related notes: [003-best-practices](./003-best-practices.md)

### Unit Testing

- Test individual functions, methods, or classes in isolation.
- Mock/stub external dependencies (database, HTTP, filesystem).
- Fast: hundreds of tests in seconds; run on every commit.
- Coverage target: 80%+ on business logic; 100% on critical paths.
- Frameworks: `Jest`, `pytest`, `go test`, `JUnit`, `xUnit`.
- Focus on behavior, not implementation: test inputs/outputs, not internal state.
- Unit tests: every commit; integration: every PR; e2e: on merge or nightly.
- Coverage threshold is a guide, not a guarantee of quality.

Related notes: [002-pipeline-stages](./002-pipeline-stages.md)

### Integration Testing

- Test interactions between components: app + database, app + API, app + message queue.
- Slower than unit tests; requires real or containerized dependencies.
- In CI: use service containers (GHA `services:`) or Docker Compose.
- Test: correct SQL queries, API contract adherence, serialization/deserialization.
- Run after unit tests pass — don't waste resources if unit tests fail.

Related notes: [002-pipeline-stages](./002-pipeline-stages.md)

### End-to-End (E2E) Testing

- Test complete user flows through the full application stack.
- Run against a deployed environment (staging or local full stack).
- Tools: `Playwright`, `Cypress`, `Selenium`.
- Keep the suite small: focus on critical business flows (5-20 scenarios).
- Most brittle test type: sensitive to UI changes, timing, and environment issues.
- Run less frequently: on merge to main, nightly, or pre-release.

Related notes: [002-pipeline-stages](./002-pipeline-stages.md)

### Security Testing (SAST / DAST / SCA)

- **SAST**: analyze source code statically for vulnerabilities; run on every PR.
- **DAST**: test a running application for runtime vulnerabilities; run weekly or pre-release.
- **SCA**: scan dependencies for known CVEs and license issues.
- SAST finds code issues, DAST finds runtime issues, SCA finds dependency issues.

Related notes: [009-ci-cd-security](./009-ci-cd-security.md) for detailed SAST/DAST/SCA coverage, tools, and implementation

### Shift-Left Testing

- Move testing earlier in the development cycle.
- Developers run tests locally before pushing (pre-commit hooks, IDE integration).
- CI runs tests on every push, not just before release.
- Security scanning in PR, not just before deploy.
- Cost of fixing defects increases exponentially as they move right (dev --> staging --> prod).
- Shift-left: test earlier = cheaper fixes; run in PR, not just pre-release.
- Security scanning belongs in the pipeline, not just before release.

```text
Cost of fixing a defect:
  Development:  $1     (developer catches during coding)
  CI/PR:        $10    (caught in automated tests)
  Staging:      $100   (found during QA)
  Production:   $1000  (user-facing incident)
```

Related notes: [003-best-practices](./003-best-practices.md)

### Test Data Management

- Tests need consistent, isolated, reproducible data.
- Strategies:
  - **Fixtures**: static data files loaded before tests.
  - **Factories**: generate test data programmatically (`factory_bot`, `Faker`).
  - **Seeding**: populate database with known state before test suite.
  - **Transaction rollback**: wrap each test in a transaction, rollback after.
- Isolation: each test should not depend on or affect other tests.
- In CI: use fresh database per test run or per test suite.
- Test data must be isolated and reproducible for each test run.

Related notes: [002-pipeline-stages](./002-pipeline-stages.md)

### Flaky Test Management

- Flaky test: passes and fails intermittently without code changes.
- Causes: timing/race conditions, shared state, network dependency, order dependency.
- Impact: developers lose trust in the pipeline; start ignoring failures.
- Management strategy:
  1. Detect: track test pass/fail history; flag flip-floppers.
  2. Quarantine: move to non-blocking suite.
  3. Fix: address root cause (proper waits, isolated state, mocks).
  4. Prevent: review new tests for flakiness patterns.
- Metric: flaky test rate; target: <1% of test suite.
- Flaky tests erode pipeline trust — quarantine, fix, prevent.

Related notes: [003-best-practices](./003-best-practices.md), [010-metrics-and-dora](./010-metrics-and-dora.md)

---

# Troubleshooting Guide

### Unit tests pass locally but fail in CI

1. Check environment differences: OS, tool versions, locale, timezone.
2. Check for hardcoded paths or OS-specific behavior.
3. Check test order dependency: CI may run tests in different order.
4. Check for missing environment variables in CI.
5. Use container-based CI to match local development environment.

### Integration tests timeout

1. Check service container startup: database may not be ready when tests start.
2. Add health check / wait-for-it script before running tests.
3. Check network connectivity between test runner and service container.
4. Increase timeout for slow services (Elasticsearch, large database seeds).
5. Check resource limits on CI runner (CPU, memory).

### E2E tests are flaky

1. Add explicit waits instead of sleep: wait for element, wait for API response.
2. Isolate test data: each test creates its own data, cleans up after.
3. Use retry on network-dependent assertions (with backoff).
4. Screenshot/video on failure for debugging.
5. Consider running on dedicated, stable environment (not shared staging).

### Coverage dropping below threshold

1. Check which new code is uncovered: look at the coverage diff report.
2. Add tests for the uncovered code paths.
3. Review if the threshold is appropriate (80% is common, 100% is rarely practical).
4. Check for untestable code: complex functions may need refactoring for testability.
5. Exclude generated code and configuration from coverage calculation.
