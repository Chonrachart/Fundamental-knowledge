# GitOps

- GitOps is an operational model where Git is the single source of truth for declarative infrastructure and application state — changes are made via Git commits, and an operator reconciles the live system to match the desired state.
- Unlike traditional push-based CI/CD (pipeline pushes to cluster), GitOps uses a pull-based model (operator in the cluster pulls desired state from Git).
- Key property: self-healing — if someone manually changes the cluster, the GitOps operator detects drift and reverts to the Git-defined state.

# Architecture

```text
GitOps Architecture (Pull-Based Model):

Traditional CI/CD (Push):
  Developer --> Git --> CI Pipeline --> kubectl apply --> Cluster
  (pipeline has cluster credentials)

GitOps (Pull):
  Developer --> Git --> [Git Repo is Source of Truth]
                              |
                              | (watches for changes)
                              v
                    +-------------------+
                    | GitOps Operator   |
                    | (ArgoCD / FluxCD) |
                    | (runs IN cluster) |
                    +-------------------+
                              |
                              | reconcile (desired vs actual)
                              v
                    +-------------------+
                    | Kubernetes        |
                    | Cluster           |
                    | (actual state)    |
                    +-------------------+

Detailed ArgoCD Architecture:
+------------------+     +------------------+     +------------------+
| Git Repository   |     | ArgoCD Server    |     | Kubernetes       |
|                  |     |                  |     | Cluster          |
| /apps/           |     | +------------+  |     |                  |
|   app-a/         |<----| | Repo Server|  |     | namespace: app-a |
|     deployment.yml     | +------------+  |     |   deployment     |
|     service.yml  |     |       |         |     |   service        |
|   app-b/         |     | +-----v------+  |     |                  |
|     kustomize/   |     | | App        |  |     | namespace: app-b |
|     helm/        |     | | Controller |--+---->|   deployment     |
|                  |     | +------------+  |     |   service        |
+------------------+     |       |         |     |                  |
                         | +-----v------+  |     |                  |
                         | | Health     |  |     |                  |
                         | | Check      |  |     |                  |
                         | +------------+  |     |                  |
                         +------------------+     +------------------+
```

# Mental Model

```text
GitOps reconciliation loop:

  [1] Developer commits manifest change to Git
      |   (e.g., update image tag in deployment.yaml)
      |
      v
  [2] GitOps operator detects change (poll or webhook)
      |
      v
  [3] Operator compares desired state (Git) vs actual state (cluster)
      |
      +---> MATCH: no action needed (in sync)
      |
      +---> DIFF: drift detected
            |
            v
  [4] Operator applies changes to cluster (reconcile)
      |
      v
  [5] Health check: are new resources healthy?
      |
      +---> HEALTHY: sync complete, status = Synced + Healthy
      |
      +---> DEGRADED: rollback or alert (depends on config)
      |
      v
  [6] Continuous: repeat every sync interval (default 3 min in ArgoCD)

Manual drift example:
  Someone runs: kubectl scale deployment/myapp --replicas=5
  GitOps operator detects: Git says replicas=3, cluster has 5
  Action: revert to replicas=3 (if auto-sync enabled)
```

Related notes: [../Argo_CD/002-argocd-applications](../Argo_CD/002-argocd-applications.md) for ArgoCD Application CRD details

# Core Building Blocks

### GitOps Principles

- **Declarative**: the entire system is described declaratively (YAML manifests, Helm charts, Kustomize).
- **Versioned and immutable**: desired state is stored in Git; every change is a commit with history.
- **Pulled automatically**: an agent in the cluster pulls desired state from Git (no external push).
- **Continuously reconciled**: software agents ensure actual state matches desired state; drift is corrected.
- Benefits over push-based CI/CD:
  - No cluster credentials in CI pipeline.
  - Audit trail: every change is a Git commit.
  - Self-healing: manual changes are reverted.
  - Rollback: `git revert` the commit.
- GitOps: Git is the single source of truth; operator reconciles cluster to match.
- Rollback = `git revert` the commit; operator syncs automatically.

Related notes: [001-ci-cd-concept](./001-ci-cd-concept.md)

### Push vs Pull Model

```text
Push model (traditional CI/CD):
  CI Pipeline ---kubectl apply---> Cluster
  - Pipeline needs cluster credentials (security risk)
  - No drift detection
  - Deployment state not in Git

Pull model (GitOps):
  Git Repo <---watches--- GitOps Operator (in cluster) ---applies---> Cluster
  - No cluster credentials outside the cluster
  - Automatic drift detection and correction
  - Git is the single source of truth
```

- Push is simpler to set up; pull is more secure and self-healing.
- Many teams use hybrid: CI builds and pushes images, GitOps operator deploys manifests.
- Pull model: operator in cluster pulls from Git; no cluster creds in CI.

Related notes: [004-pipeline-design-patterns](./004-pipeline-design-patterns.md)

### ArgoCD

- Most popular GitOps operator for Kubernetes.
- Architecture:
  - **API Server**: web UI, CLI, API for managing applications.
  - **Repo Server**: clones Git repos, renders manifests (Helm, Kustomize, plain YAML).
  - **Application Controller**: watches applications, compares desired vs actual, syncs.
  - **Application CRD**: defines what to deploy, from where, to which cluster.
- Sync policies:
  - **Manual sync**: user clicks sync in UI or CLI.
  - **Auto-sync**: automatically apply when Git changes.
  - **Self-heal**: revert manual cluster changes to match Git.
  - **Prune**: delete resources removed from Git.
- Health checks: built-in health assessment for Kubernetes resources (Deployment, Service, etc.).
- ArgoCD: most popular, web UI, Application CRD, auto-sync + self-heal.

```bash
# ArgoCD CLI operations
argocd app create myapp --repo https://github.com/org/manifests.git \
  --path apps/myapp --dest-server https://kubernetes.default.svc \
  --dest-namespace myapp

argocd app sync myapp          # trigger sync
argocd app get myapp           # check status
argocd app diff myapp          # see pending changes
argocd app history myapp       # deployment history
```

Related notes: [005-deployment-strategies](./005-deployment-strategies.md)

### FluxCD

- CNCF-graduated GitOps operator; lightweight, composable architecture.
- Components:
  - **Source Controller**: watches Git repos, Helm repos, S3 buckets.
  - **Kustomize Controller**: applies Kustomize overlays.
  - **Helm Controller**: manages Helm releases.
  - **Notification Controller**: sends/receives notifications (Slack, GitHub, webhooks).
- CRDs:
  - `GitRepository`: defines Git source and sync interval.
  - `Kustomization`: defines what to apply from the source.
  - `HelmRelease`: defines Helm chart deployment.
- Differences from ArgoCD:
  - No built-in web UI (use Weave GitOps dashboard or Flux UI).
  - More composable (each controller is independent).
  - Better Helm integration (native HelmRelease CRD).
- FluxCD: CNCF graduated, composable controllers, native Helm/SOPS support.

```yaml
# FluxCD GitRepository + Kustomization
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: myapp
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/org/manifests.git
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: myapp
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: myapp
  path: ./apps/myapp
  prune: true
```

Related notes: [005-deployment-strategies](./005-deployment-strategies.md)

### Drift Detection and Reconciliation

- **Drift**: actual cluster state differs from desired state in Git.
- Causes: manual `kubectl` changes, external controllers, operator conflicts.
- Detection: GitOps operator periodically compares Git manifests with cluster resources.
- Response options:
  - **Auto-heal**: automatically revert to Git state (recommended for production).
  - **Alert only**: notify team but don't revert (useful during migration).
  - **Ignore**: exclude specific fields from drift detection (e.g., HPA-managed replicas).
- ArgoCD: `selfHeal: true` in sync policy.
- FluxCD: `prune: true` and force apply.
- Self-healing: manual cluster changes are automatically reverted.

Related notes: [003-best-practices](./003-best-practices.md)

### Repository Structure

- **App-of-Apps pattern**: one ArgoCD Application manages other Application manifests.
  - Root app points to a directory of Application YAMLs.
  - Adding a new service = adding a new Application YAML + manifests.
- **Monorepo**: all environment manifests in one repo.
  - Structure: `apps/<app-name>/overlays/<env>/` (`Kustomize`).
  - Pros: single place for all config; easy to see full state.
  - Cons: large repos; access control is harder.
- **Multi-repo**: separate repos per application or per environment.
  - Pros: independent access control; smaller repos.
  - Cons: harder to see full state; more repos to manage.
- **Environment separation**: directories (recommended) vs branches.
  - Directories: `envs/staging/`, `envs/production/` — easier to diff and promote.
  - Branches: `staging` branch, `production` branch — harder to compare, merge conflicts.

```text
Recommended structure (monorepo with Kustomize):
manifests/
  apps/
    app-a/
      base/
        deployment.yaml
        service.yaml
        kustomization.yaml
      overlays/
        staging/
          kustomization.yaml    # patches for staging
        production/
          kustomization.yaml    # patches for production
    app-b/
      ...
  argocd/
    app-a.yaml                  # ArgoCD Application CRD
    app-b.yaml
```

Related notes: [008-environment-management](./008-environment-management.md)

### Secrets in GitOps

- Challenge: secrets cannot be stored in plain text in Git.
- Solutions:
  - **`Sealed Secrets`**: encrypt secrets with a cluster-side key; only the cluster can decrypt.
    - `kubeseal` CLI encrypts; `SealedSecret` controller decrypts in-cluster.
  - **`SOPS`** (Mozilla): encrypt secret values in YAML files; decrypt at apply time.
    - Supports `AWS KMS`, `GCP KMS`, `Azure Key Vault`, `age`, `PGP`.
    - FluxCD has native SOPS integration.
  - **External Secrets Operator (`ESO`)**: sync secrets from external stores (`Vault`, `AWS Secrets Manager`) into Kubernetes Secrets.
    - `ExternalSecret` CRD defines what to fetch and where to store.
    - Secrets never stored in Git; only references in Git.
- Recommendation: ESO for production (secrets in vault, not in Git); Sealed Secrets for simpler setups.
- Secrets in GitOps: use Sealed Secrets, SOPS, or External Secrets Operator.

```yaml
# External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: myapp-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: myapp-secrets
  data:
    - secretKey: DB_PASSWORD
      remoteRef:
        key: myapp/production
        property: db_password
```

Related notes: [009-ci-cd-security](./009-ci-cd-security.md), [003-best-practices](./003-best-practices.md)

### Progressive Delivery with GitOps

- Combine GitOps with advanced deployment strategies (canary, blue-green).
- **Argo Rollouts**: Kubernetes controller for progressive delivery.
  - Replaces Deployment with Rollout CRD.
  - Supports canary (traffic splitting), blue-green, analysis runs.
  - Integrates with Istio, NGINX, ALB for traffic management.
- **Flagger**: progressive delivery for FluxCD (and other platforms).
  - Automated canary analysis with metrics (Prometheus, Datadog).
  - Automatic promotion or rollback based on metrics thresholds.
- Both are managed via Git manifests — GitOps controls the rollout strategy.
- Progressive delivery: `Argo Rollouts` (canary/blue-green) managed via Git.

Related notes: [../Argo_CD/004-argocd-advanced-patterns](../Argo_CD/004-argocd-advanced-patterns.md) for Argo Rollouts canary/blue-green YAML details, [005-deployment-strategies](./005-deployment-strategies.md), [010-metrics-and-dora](./010-metrics-and-dora.md)

---

# Troubleshooting Guide

### ArgoCD application stuck in "OutOfSync"

1. Check diff: `argocd app diff myapp` — what does ArgoCD think is different?
2. Common cause: fields added by Kubernetes (annotations, defaults) that don't match Git.
3. Solution: add resource exclusions or ignore differences for auto-generated fields.
4. Check if a mutating webhook is modifying resources after apply.
5. Check if Helm values produce non-deterministic output (random, timestamp).

### Drift keeps recurring despite self-heal

1. Identify the source: another controller or operator modifying the same resource.
2. Common: HPA conflicts with GitOps-managed replica count.
3. Solution: exclude `spec.replicas` from sync if HPA manages it.
4. Check for CronJobs or scripts that modify cluster state.
5. Use ArgoCD resource hooks or ignore differences for specific fields.

### Sealed Secret cannot be decrypted

1. Check if the `SealedSecret` was encrypted with the correct cluster's public key.
2. If the sealing key was rotated, re-encrypt with the new key.
3. Check namespace: `SealedSecrets` are namespace-scoped by default.
4. Verify the sealed-secrets controller is running: `kubectl get pods -n kube-system`.
5. Check controller logs for decryption errors.

### GitOps sync is slow

1. Check sync interval: default is 3 minutes in ArgoCD; reduce if needed.
2. Use webhooks for instant sync on Git push (faster than polling).
3. Check repo server performance: large repos or complex Helm charts slow rendering.
4. Check cluster API server load: many resources to sync can be slow.
5. Split large applications into smaller ones for parallel sync.

---

Related notes (Argo_CD):
- [../Argo_CD/001-argocd-overview](../Argo_CD/001-argocd-overview.md) — ArgoCD architecture, components, installation
- [../Argo_CD/002-argocd-applications](../Argo_CD/002-argocd-applications.md) — Application CRD, app-of-apps, ApplicationSet
- [../Argo_CD/003-argocd-sync-strategies](../Argo_CD/003-argocd-sync-strategies.md) — Sync policies, hooks, waves, windows
- [../Argo_CD/004-argocd-advanced-patterns](../Argo_CD/004-argocd-advanced-patterns.md) — Argo Rollouts, Image Updater, multi-cluster
- [../Argo_CD/005-argocd-admin-operations](../Argo_CD/005-argocd-admin-operations.md) — RBAC, SSO, backup, monitoring
