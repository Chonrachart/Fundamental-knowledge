# Deployment Strategies

- Deployment strategies define how new code versions replace old ones in production — balancing speed, risk, and complexity.
- Each strategy trades off between deployment speed, rollback time, resource cost, and user impact.
- Choosing the right strategy depends on: application architecture, traffic volume, risk tolerance, and infrastructure capabilities.

# Architecture

```text
Deployment Strategy Comparison:

RECREATE (downtime)
  v1 [|||||||] --stop--> [       ] --start--> v2 [|||||||]
                          downtime

ROLLING UPDATE (gradual, zero-downtime)
  v1 [|||||||]    v1 [|||||] v2 [||]    v1 [|||] v2 [||||]    v2 [|||||||]
  100% v1         70% v1 / 30% v2       40% v1 / 60% v2       100% v2

BLUE-GREEN (instant switch)
  Blue  (v1) [|||||||] <-- traffic
  Green (v2) [|||||||]     (idle, testing)
  --- switch ---
  Blue  (v1) [|||||||]     (idle, standby)
  Green (v2) [|||||||] <-- traffic

CANARY (small percentage first)
  v1 [||||||||||] <-- 95% traffic
  v2 [|]          <-- 5% traffic (canary)
  --- monitor, expand ---
  v1 [|||||]      <-- 50% traffic
  v2 [|||||]      <-- 50% traffic
  --- fully rolled out ---
  v2 [||||||||||] <-- 100% traffic

A/B TESTING (user-attribute routing)
  v1 [|||||||] <-- users in group A
  v2 [|||||||] <-- users in group B
  (measure business metrics, choose winner)
```

# Mental Model

```text
Choosing a deployment strategy:

  [1] Can you afford downtime?
      |
      +--YES--> Recreate (simplest, cheapest)
      |
      +--NO---> Zero-downtime required
                |
                v
  [2] Do you need instant rollback?
      |
      +--YES--> Blue-Green (switch back in seconds)
      |
      +--NO---> Gradual is acceptable
                |
                v
  [3] Do you want to test with real traffic first?
      |
      +--YES--> Canary (route small % to new version)
      |
      +--NO---> Rolling Update (gradual replacement)
      |
      v
  [4] Do you need to measure business impact?
      |
      +--YES--> A/B Testing (route by user attributes)
      |
      v
  [5] Do you want to decouple deploy from release?
      |
      +--YES--> Feature Flags (deploy code, toggle features)
```

# Core Building Blocks

### Recreate

- Stop all instances of v1, then start all instances of v2.
- Simplest strategy; requires downtime during the switch.
- Best for: non-production environments, batch jobs, stateful apps that can't run mixed versions.
- Drawback: users experience downtime; no gradual rollout.
- In Kubernetes: `strategy.type: Recreate` in Deployment spec.
- Recreate: simplest, has downtime; use for non-critical or dev environments.

```yaml
# Kubernetes Deployment
spec:
  strategy:
    type: Recreate
```

Related notes: [002-pipeline-stages](./002-pipeline-stages.md)

### Rolling Update

- Gradually replace old instances with new ones, a few at a time.
- Zero-downtime: some instances serve v1 while others switch to v2.
- Default strategy in Kubernetes (`RollingUpdate`).
- Control speed with `maxSurge` (how many extra pods) and `maxUnavailable` (how many can be down).
- Rollback: reverse the rolling update (but takes time, not instant).
- Requires: backward-compatible changes (v1 and v2 coexist briefly).
- Rolling update: zero-downtime, gradual; Kubernetes default; requires backward compatibility.

```yaml
# Kubernetes Deployment
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1           # 1 extra pod during update
      maxUnavailable: 0     # no downtime
```

Related notes: [008-environment-management](./008-environment-management.md)

### Blue-Green Deployment

- Two identical environments: Blue (current) and Green (new).
- Deploy v2 to Green; test it; switch traffic from Blue to Green.
- Rollback: switch traffic back to Blue (instant, seconds).
- Cost: requires 2x infrastructure during deployment.
- Implementation: DNS switch, load balancer update, or Kubernetes Service selector change.
- Blue-Green: instant switch and rollback; costs 2x infrastructure.

```text
Steps:
  1. Blue serves production traffic (v1)
  2. Deploy v2 to Green environment
  3. Run smoke tests against Green
  4. Switch load balancer / DNS to Green
  5. Green is now production (v2)
  6. Blue remains on standby for rollback
  7. After confidence period, tear down Blue or reuse for next deployment
```

Related notes: [005-deployment-strategies](./005-deployment-strategies.md)

### Canary Deployment

- Deploy v2 to a small subset of instances; route a small percentage of traffic to it.
- Monitor error rates, latency, and business metrics on the canary.
- If healthy: gradually increase traffic percentage (5% --> 25% --> 50% --> 100%).
- If unhealthy: route all traffic back to v1 (fast rollback).
- Tools: Kubernetes Ingress with traffic splitting, `Argo Rollouts`, `Flagger`, `Istio`.
- Canary: test with real traffic at small scale; expand gradually.

```text
Canary progression:
  Step 1: 5% to v2, 95% to v1   -- monitor for 5 min
  Step 2: 25% to v2, 75% to v1  -- monitor for 10 min
  Step 3: 50% to v2, 50% to v1  -- monitor for 15 min
  Step 4: 100% to v2            -- canary complete
```

Related notes: [010-metrics-and-dora](./010-metrics-and-dora.md), [011-gitops](./011-gitops.md)

### Feature Flags

- Deploy code to production but control feature visibility with runtime toggles.
- Decouple deployment (code ships) from release (feature is enabled).
- Enables: gradual rollout by user %, A/B testing, kill switch for broken features.
- Implementation: feature flag service (`LaunchDarkly`, `Unleash`, `Flagsmith`) or config-based.
- Clean up: remove old flags after full rollout to avoid technical debt.
- Feature flags: decouple deploy from release; must clean up old flags.

```text
Feature flag lifecycle:
  1. Wrap new feature code in flag check
  2. Deploy to production (flag OFF)
  3. Enable flag for internal users (testing)
  4. Enable for 10% of users (canary)
  5. Enable for all users (full release)
  6. Remove flag code (cleanup)
```

Related notes: [003-best-practices](./003-best-practices.md)

### A/B Testing

- Route different user segments to different versions based on attributes (user ID, region, device).
- Measure business metrics (conversion rate, engagement) not just technical metrics.
- Requires: traffic routing infrastructure, analytics, statistical significance testing.
- Not just a deployment strategy — combines deployment with product experimentation.
- Usually implemented at the application or load balancer level.

Related notes: [010-metrics-and-dora](./010-metrics-and-dora.md)

### Rollback Strategies

- Every deployment must have a rollback plan tested before it is needed.
- Rollback methods:
  - **Redeploy previous version**: rebuild/redeploy the last known good artifact.
  - **Blue-Green switch**: instant traffic switch back to old environment.
  - **Canary abort**: route 100% traffic back to stable version.
  - **Feature flag disable**: turn off the broken feature without redeploying.
  - **Kubernetes rollback**: `kubectl rollout undo deployment/myapp`.
- Database rollback considerations:
  - Forward-only migrations: design migrations to be backward-compatible.
  - Never drop columns in the same release that stops using them.
  - Expand-and-contract pattern: add new column, migrate data, remove old column in separate releases.
- Automated rollback triggers:
  - Error rate exceeds threshold.
  - Latency spikes above SLO.
  - Health check failures.
  - `Alertmanager` integration with deployment controller.
- Always have a tested rollback plan before deploying.
- Database migrations must be backward-compatible for zero-downtime strategies.
- Automated rollback triggers: error rate, latency, health check failures.

Related notes: [009-ci-cd-security](./009-ci-cd-security.md), [008-environment-management](./008-environment-management.md)

---

# Troubleshooting Guide

### Rolling update stuck (pods not becoming ready)

1. Check pod status: `kubectl get pods` — look for `CrashLoopBackOff` or `ImagePullBackOff`.
2. Check pod logs: `kubectl logs <pod>` for application errors.
3. Check readiness probe: is the health endpoint responding correctly?
4. Check resource limits: pod may be `OOMKilled` (check `kubectl describe pod`).
5. Rollback: `kubectl rollout undo deployment/<name>`.

### Blue-Green switch causes errors

1. Check if Green environment passed all smoke tests before switching.
2. Verify database compatibility: v2 code must work with current schema.
3. Check for session affinity issues: users mid-session may lose state.
4. DNS propagation delay: some clients may still resolve to Blue.
5. Rollback: switch traffic back to Blue immediately.

### Canary showing elevated errors

1. Check canary metrics: error rate, latency percentiles (p50, p95, p99).
2. Compare canary metrics with baseline (stable version).
3. If error rate > threshold: abort canary, route all traffic to stable.
4. Investigate: check canary pod logs, recent code changes.
5. Fix and re-deploy canary after root cause is resolved.

### Feature flag causing unexpected behavior

1. Verify flag state in the feature flag service dashboard.
2. Check flag evaluation logic: correct user targeting rules?
3. Look for flag dependency issues: flag A depends on flag B being enabled.
4. Test with flag explicitly ON and OFF in staging.
5. Kill switch: disable the flag immediately if causing production issues.
