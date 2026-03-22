# CI/CD Metrics and DORA

- DORA (DevOps Research and Assessment) defines four key metrics that measure software delivery performance: deployment frequency, lead time, MTTR, and change failure rate.
- Pipeline metrics (build duration, test pass rate, flaky test rate) complement DORA by measuring the health of the CI/CD system itself.
- Measuring and tracking these metrics enables data-driven improvement: identify bottlenecks, set targets, and validate that changes improve delivery.

# Architecture

```text
Metrics Collection from CI/CD Pipeline:

Source Code        Pipeline              Deployment           Production
+---------+       +---------+           +-----------+        +-----------+
| Commit  |------>| Build   |---------->| Deploy    |------->| Monitor   |
| (time)  |       | (time)  |           | (time)    |        | (health)  |
+---------+       +---------+           +-----------+        +-----------+
    |                  |                      |                    |
    v                  v                      v                    v
+--------+        +----------+          +-----------+        +-----------+
| Lead   |        | Build    |          | Deploy    |        | Change    |
| Time   |        | Duration |          | Frequency |        | Failure   |
| Start  |        | Metric   |          | Metric    |        | Rate      |
+--------+        +----------+          +-----------+        +-----------+
                       |                      |                    |
                       v                      v                    v
               +------------------------------------------------+
               |              Metrics Dashboard                  |
               |                                                 |
               | DORA Metrics:                                   |
               |   - Deployment Frequency    (how often)         |
               |   - Lead Time for Changes   (how fast)          |
               |   - Change Failure Rate     (how reliable)      |
               |   - MTTR                    (how resilient)     |
               |                                                 |
               | Pipeline Metrics:                               |
               |   - Build duration          - Queue time        |
               |   - Test pass rate          - Flaky test rate   |
               |   - Cache hit rate          - Runner utilization|
               +------------------------------------------------+
```

# Mental Model

```text
Using DORA metrics to improve delivery:

  [1] MEASURE current state
      |   - Deploy frequency: X per week
      |   - Lead time: Y hours from commit to prod
      |   - Change failure rate: Z% of deploys cause incidents
      |   - MTTR: W hours to recover from incidents
      |
      v
  [2] IDENTIFY bottlenecks
      |   - Long lead time? --> Slow tests? Manual approval delays? Large PRs?
      |   - Low deploy frequency? --> Long release cycles? Fear of deploying?
      |   - High failure rate? --> Insufficient testing? Missing staging?
      |   - High MTTR? --> No automated rollback? Poor observability?
      |
      v
  [3] SET targets (based on DORA performance levels)
      |   - Elite: multiple deploys/day, <1hr lead time, <5% failure, <1hr MTTR
      |   - High: weekly-daily, 1day-1week, 0-15%, <1day
      |
      v
  [4] IMPROVE
      |   - Automate manual steps
      |   - Reduce batch size (smaller PRs)
      |   - Improve test coverage and speed
      |   - Add automated rollback
      |
      v
  [5] RE-MEASURE and iterate
      - Track trends over time (weekly/monthly)
      - Celebrate improvements
      - Investigate regressions
```

# Core Building Blocks

### Deployment Frequency

- How often code is deployed to production.
- Measures: team's ability to ship changes and confidence in the pipeline.
- DORA benchmarks:
  - **Elite**: multiple deploys per day.
  - **High**: between once per day and once per week.
  - **Medium**: between once per week and once per month.
  - **Low**: less than once per month.
- Improving: smaller PRs, automated testing, continuous deployment, feature flags.
- Anti-pattern: batching many changes into infrequent releases (increases risk).

Related notes: [001-ci-cd-concept](./001-ci-cd-concept.md), [005-deployment-strategies](./005-deployment-strategies.md)

### Lead Time for Changes

- Time from code commit to code running in production.
- Includes: CI pipeline time + code review time + deployment time + approval time.
- DORA benchmarks:
  - **Elite**: less than one hour.
  - **High**: between one day and one week.
  - **Medium**: between one week and one month.
  - **Low**: more than one month.
- Components to optimize:
  - Pipeline speed (caching, parallelism, fast tests).
  - Review turnaround (small PRs, clear descriptions, async review).
  - Deployment automation (no manual steps).
- Smaller PRs improve lead time, review time, and change failure rate.

Related notes: [003-best-practices](./003-best-practices.md), [004-pipeline-design-patterns](./004-pipeline-design-patterns.md)

### Mean Time to Recovery (MTTR)

- Time from production incident detection to resolution.
- Measures: team's ability to respond to and recover from failures.
- DORA benchmarks:
  - **Elite**: less than one hour.
  - **High**: less than one day.
  - **Medium**: between one day and one week.
  - **Low**: more than one week.
- Improving:
  - Automated rollback (health check triggers, `Argo Rollouts`).
  - Good observability (metrics, logs, traces — fast diagnosis).
  - Runbooks and incident response procedures.
  - Feature flags as kill switches.

Related notes: [005-deployment-strategies](./005-deployment-strategies.md)

### Change Failure Rate

- Percentage of deployments that cause a production incident or require remediation.
- Measures: quality of changes being deployed.
- DORA benchmarks:
  - **Elite**: 0-5%.
  - **High**: 0-15%.
  - **Medium**: 16-30%.
  - **Low**: 46-60%.
- Improving:
  - Better test coverage (especially integration and e2e).
  - Staging environment that mirrors production.
  - Canary deployments to catch issues with real traffic.
  - Code review quality and PR size limits.

Related notes: [006-testing-strategies](./006-testing-strategies.md), [008-environment-management](./008-environment-management.md)

### Pipeline Metrics

- **Build duration**: total time for the CI pipeline; track trends (should not grow over time).
- **Test pass rate**: percentage of pipeline runs where all tests pass; target >98%.
- **Flaky test rate**: percentage of tests that flip pass/fail without code changes; target <1%.
- **Queue time**: time jobs wait for a runner; indicates runner capacity issues.
- **Cache hit rate**: percentage of cache hits; low rate means wasted build time.
- **Runner utilization**: are runners overloaded or underutilized?
- Track these as dashboard metrics with alerts on degradation.
- Pipeline metrics: build duration, test pass rate, flaky test rate, queue time.

Related notes: [003-best-practices](./003-best-practices.md)

### Developer Experience Metrics

- **Cycle time**: time from first commit to PR merge; measures dev velocity.
- **Review time**: time from PR opened to first review and to merge.
- **Onboarding time**: how long for a new developer to ship their first change.
- **Cognitive load**: how many tools/steps required to ship a change.
- **Developer satisfaction**: survey-based; correlates with delivery performance.
- These are harder to measure but directly impact DORA metrics.

Related notes: [003-best-practices](./003-best-practices.md)

### Measuring Pipeline Health

- Dashboard: display DORA metrics + pipeline metrics in Grafana or similar.
- Data sources: CI/CD platform APIs (GitHub Actions, GitLab CI), deployment logs, incident tracking.
- Trends: track weekly/monthly averages; flag regressions.
- Alerts: notify when build duration increases >20%, test pass rate drops, queue time spikes.
- Tools: `Sleuth`, `LinearB`, `Haystack`, `Faros AI`, custom Grafana dashboards.
- Track trends and alert on regressions in pipeline health.

Related notes: [003-best-practices](./003-best-practices.md)

### Continuous Improvement

- Use DORA metrics to identify the biggest bottleneck.
- Focus on one metric at a time; avoid optimizing everything simultaneously.
- Retrospectives: review metrics monthly, discuss what improved and what regressed.
- Automation ROI: calculate time saved by automating manual pipeline steps.
- Bottleneck analysis:
  - Slow lead time? --> Pipeline speed or review turnaround.
  - High failure rate? --> Test gaps or environment parity.
  - Low deploy frequency? --> Large batch sizes or manual gates.
  - High MTTR? --> Observability or rollback automation.
- Measure weekly/monthly; focus on one bottleneck at a time.
- Continuous improvement: measure, identify bottleneck, improve, re-measure.

Related notes: [001-ci-cd-concept](./001-ci-cd-concept.md)

### DORA Performance Levels

```text
+------------------+------------------+------------------+------------------+
| Metric           | Elite            | High             | Medium           |
+------------------+------------------+------------------+------------------+
| Deploy Frequency | Multiple/day     | Daily - Weekly   | Weekly - Monthly |
| Lead Time        | < 1 hour         | 1 day - 1 week   | 1 week - 1 month|
| Change Fail Rate | 0-5%             | 0-15%            | 16-30%           |
| MTTR             | < 1 hour         | < 1 day          | 1 day - 1 week  |
+------------------+------------------+------------------+------------------+
```

- Elite performers deploy more often AND have lower failure rates (speed and stability are not trade-offs).
- Moving up one level at a time is realistic; jumping from low to elite is not.
- Teams that invest in CI/CD practices consistently improve over time.
- DORA four key metrics: deployment frequency, lead time, change failure rate, MTTR.
- Elite performers: multiple deploys/day, <1hr lead time, <5% failure rate, <1hr MTTR.
- Speed and stability are NOT trade-offs — elite teams excel at both.

Related notes: [001-ci-cd-concept](./001-ci-cd-concept.md)

---

# Troubleshooting Guide

### Lead time is too long

1. Profile the pipeline: which stage takes the most time?
2. Check review turnaround: are PRs waiting days for review?
3. Check approval gates: are manual approvals delaying deployments?
4. Check batch size: are PRs too large (>400 lines)?
5. Solutions: faster tests, auto-merge for small changes, async review culture.

### Deployment frequency is low

1. Check if fear of deploying is the blocker (low confidence in tests/rollback).
2. Check if release process is manual (batching changes for scheduled releases).
3. Check if large PRs create bottlenecks (review takes too long).
4. Solutions: improve test coverage, add automated rollback, deploy smaller changes.

### Change failure rate is high

1. Analyze failed deployments: are they test gaps, config issues, or data issues?
2. Check staging coverage: does staging catch these issues?
3. Check test coverage on the areas that frequently fail.
4. Solutions: canary deployments, better staging parity, mandatory integration tests.

### MTTR is too high

1. Check observability: can the team quickly identify what went wrong?
2. Check rollback process: is it automated or manual?
3. Check incident response: are runbooks documented and practiced?
4. Solutions: automated rollback triggers, better alerting, feature flag kill switches.
