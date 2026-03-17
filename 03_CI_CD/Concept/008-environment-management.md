# Environment Management

- Environments are isolated deployment targets (dev, staging, production) where the same application runs with different configurations.
- Environment management ensures parity (staging mirrors prod), safe promotion (build once, deploy through stages), and proper configuration isolation.
- Key principle: infrastructure-as-code defines environments; configuration is injected at deploy time, never baked into artifacts.

# Architecture

```text
Environment Topology and Promotion Flow:

Developer         CI/CD Pipeline         Environments
+-----------+    +---------------+    +----------------+
| Feature   |--->| Build +       |--->| Dev / Preview  |
| Branch    |    | Unit Tests    |    | (ephemeral,    |
+-----------+    +-------+-------+    |  per-PR)       |
                         |            +-------+--------+
                         |                    |
+-----------+    +-------+-------+    +-------+--------+
| main      |--->| Build + Test  |--->| Staging        |
| Branch    |    | + Scan        |    | (persistent,   |
+-----------+    +-------+-------+    |  mirrors prod) |
                         |            +-------+--------+
                         |                    |
+-----------+    +-------+-------+    +-------+--------+
| Release   |--->| Promote       |--->| Production     |
| Tag       |    | (same artifact)|   | (approval gate,|
+-----------+    +---------------+    |  monitored)    |
                                      +----------------+

Configuration per environment:
+----------+------------------+------------------+------------------+
|          | Dev/Preview      | Staging          | Production       |
+----------+------------------+------------------+------------------+
| Database | local/ephemeral  | shared test DB   | prod cluster     |
| Secrets  | test values      | staging vault    | prod vault       |
| Scaling  | 1 replica        | 2 replicas       | auto-scale       |
| Domain   | pr-123.dev.app   | staging.app.com  | app.com          |
| Debug    | verbose logging  | standard logging | minimal logging  |
+----------+------------------+------------------+------------------+
```

# Mental Model

```text
Environment strategy decision flow:

  [1] How many environments do you need?
      |
      +-- Minimum: staging + production
      +-- Common: dev + staging + production
      +-- Full: dev + QA + staging + performance + production
      |
      v
  [2] Should environments be persistent or ephemeral?
      |
      +-- Persistent: staging, production (always running)
      +-- Ephemeral: per-PR preview environments (auto-created, auto-destroyed)
      |
      v
  [3] How do you manage configuration per environment?
      |
      +-- Environment variables (injected at deploy time)
      +-- Config files (per-env in repo or config store)
      +-- Secret store (Vault, AWS Secrets Manager, GitHub Secrets)
      |
      v
  [4] How do you promote between environments?
      |
      +-- Same artifact (image tag) deployed to each env
      +-- Different config injected per env
      +-- Approval gate before production
      |
      v
  [5] How do you handle database schema changes?
      |
      +-- Forward-only migrations
      +-- Backward-compatible changes
      +-- Expand-and-contract for breaking changes
```

Example — GitHub Actions environment with approval:

```yaml
jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - run: ./deploy.sh staging ${{ github.sha }}

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://app.com
    steps:
      - run: ./deploy.sh production ${{ github.sha }}
```

# Core Building Blocks

### Environment Types

- **Development (dev)**: developer-local or shared dev server; fast iteration, debug-friendly.
- **QA / Test**: dedicated testing environment; may run automated or manual test suites.
- **Staging**: mirrors production as closely as possible; final validation before prod.
- **Performance / Load**: production-like scale for performance testing; often ephemeral.
- **Production**: live environment serving real users; highest stability and security requirements.
- Rule: minimize the number of persistent environments to reduce maintenance overhead.

Related notes: [001-ci-cd-concept](./001-ci-cd-concept.md)

### Environment Parity

- Staging should match production in: OS, runtime version, service versions, network topology.
- Use infrastructure-as-code (Terraform, Helm) to define both environments from the same templates.
- Differences to accept: scale (fewer replicas in staging), data (synthetic vs real), domains.
- Common parity failures:
  - Different database version in staging vs prod.
  - Missing network policies in staging.
  - Different secret configuration or IAM roles.
- Test in staging what you deploy to prod — same artifact, same deploy process.

Related notes: [003-best-practices](./003-best-practices.md)

### Configuration Management

- Configuration = environment-specific settings (database URLs, API keys, feature flags, log levels).
- Methods:
  - **Environment variables**: injected at runtime; most common for containers.
  - **Config maps / config files**: mounted into containers or read at startup.
  - **Secret stores**: Vault, AWS Secrets Manager, Azure Key Vault — for sensitive values.
  - **ConfigMap + Secrets in Kubernetes**: native config injection.
- Rules:
  - Never bake config into the artifact (image, binary).
  - Store defaults in code; override per environment.
  - Secrets are always separate from general config.

```bash
# Kubernetes ConfigMap and Secret injection
kubectl create configmap app-config --from-literal=LOG_LEVEL=info
kubectl create secret generic app-secrets --from-literal=DB_PASSWORD=secret
# Referenced in Deployment spec via envFrom or env.valueFrom
```

Related notes: [003-best-practices](./003-best-practices.md), [009-ci-cd-security](./009-ci-cd-security.md)

### Promotion Flow

- Build once: create artifact in CI, tag with git SHA.
- Deploy to staging: same artifact, staging config injected.
- Test in staging: automated smoke tests + manual verification.
- Promote to production: same artifact, production config injected.
- Never rebuild for a different environment.
- Promotion can be automatic (after staging tests pass) or gated (manual approval).

```text
Promotion flow:
  Build: myapp:abc123f --> push to registry
  Staging: pull myapp:abc123f + staging config --> deploy --> test
  Production: pull myapp:abc123f + prod config --> deploy (after approval)
```

Related notes: [007-artifact-management](./007-artifact-management.md), [004-pipeline-design-patterns](./004-pipeline-design-patterns.md)

### Ephemeral Environments (Preview Deployments)

- Per-PR environments: automatically created when a PR is opened, destroyed when merged/closed.
- Purpose: test feature branches in a realistic environment before merging.
- Implementation: namespace-per-PR in Kubernetes, or platform-specific (Vercel, Netlify).
- Requirements: automated provisioning, DNS/routing, database seeding, cleanup.
- Cost control: auto-destroy after PR close; TTL for abandoned environments.
- Benefits: faster review cycles, catch environment-specific issues early.

Related notes: [004-pipeline-design-patterns](./004-pipeline-design-patterns.md)

### Environment Protection Rules

- Control who can deploy to an environment and under what conditions.
- GitHub Actions environment protection:
  - **Required reviewers**: specific people must approve before deployment proceeds.
  - **Wait timer**: delay deployment by N minutes (cool-down period).
  - **Deployment branches**: only specific branches can deploy to this environment.
- Kubernetes: RBAC, namespace-level permissions, admission controllers.
- Production protection: require at least one approval, restrict to main branch or tags.

Related notes: [009-ci-cd-security](./009-ci-cd-security.md)

### Database Migrations Across Environments

- Migrations must run in order: dev first, then staging, then production.
- Forward-only: never roll back a migration; instead, create a new migration to undo changes.
- Backward-compatible: v1 code should work with v2 schema (and vice versa during rollout).
- Expand-and-contract pattern for breaking changes:
  1. **Expand**: add new column/table (old code ignores it).
  2. **Migrate**: update code to use new schema, backfill data.
  3. **Contract**: remove old column/table (after all code uses new schema).
- Run migrations as a separate pipeline step before deploying new code.
- Always test migrations against a copy of production data (in staging).

Related notes: [005-deployment-strategies](./005-deployment-strategies.md)

### Multi-Tenancy and Isolation

- Isolate environments using: Kubernetes namespaces, separate clusters, VPCs, or accounts.
- Network policies: prevent staging from accessing production resources.
- IAM/RBAC: environment-scoped permissions (staging deployer cannot touch production).
- Shared services: carefully manage shared databases, message queues, caches between environments.
- Cost optimization: share infrastructure where safe (dev namespaces on one cluster), isolate for production.

Related notes: [009-ci-cd-security](./009-ci-cd-security.md)

---

# Troubleshooting Guide

### Works in staging, fails in production

1. Check environment parity: runtime version, OS, dependencies.
2. Compare configuration: environment variables, secrets, config maps.
3. Check network: firewall rules, DNS resolution, external service access.
4. Check data differences: staging has test data, prod has real edge cases.
5. Check scale: concurrency issues that only appear at production load.

### Ephemeral environment fails to create

1. Check resource quotas: namespace limit, CPU/memory limits on cluster.
2. Check DNS/routing: wildcard DNS record configured for preview domains.
3. Check permissions: CI service account can create namespaces/resources.
4. Check cleanup: orphaned resources from previous failed deployments.
5. Check database provisioning: does the ephemeral env get its own database?

### Database migration fails in staging

1. Check migration order: migrations must be sequential, no gaps.
2. Check schema state: staging database may have manual changes not in migrations.
3. Test migration on a production data copy (data-dependent edge cases).
4. Check migration timeout: large data migrations may exceed deploy timeout.
5. Check lock contention: migration may need exclusive table lock on large tables.

---

# Quick Facts (Revision)

- Minimum environments: staging + production; add dev, QA, performance as needed.
- Environment parity: staging should mirror production infrastructure.
- Configuration injected at deploy time, never baked into artifacts.
- Build once, promote the same artifact through all environments.
- Ephemeral environments: per-PR, auto-created, auto-destroyed.
- Database migrations: forward-only, backward-compatible, expand-and-contract.
- Protection rules: required reviewers, deployment branch restrictions, wait timers.
- Isolate environments: namespaces, network policies, scoped IAM roles.
