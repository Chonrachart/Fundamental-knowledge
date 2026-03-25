# ArgoCD Overview

- ArgoCD is a declarative GitOps continuous delivery tool for Kubernetes that keeps cluster state in sync with Git-defined desired state.
- It runs inside the cluster, watches Git repositories, and automatically or manually reconciles the actual state to match the desired state.
- Key property: Git is the single source of truth — every deployment is a Git commit; rollback is `git revert`.

# Architecture

```text
ArgoCD System Architecture:

+--------------------+         +------------------------------------------+
| Git Repositories   |         | Kubernetes Cluster                       |
|                    |         |                                          |
| +----------------+ |         | +--------------------------------------+ |
| | App Manifests  | |         | | ArgoCD Namespace                     | |
| | (YAML, Helm,   | |<--------| |                                      | |
| |  Kustomize)    | |  clone  | | +------------------+                 | |
| +----------------+ |         | | | argocd-server    | <-- Web UI/CLI  | |
|                    |         | | | (API + UI)       |     gRPC/HTTPS  | |
| +----------------+ |         | | +--------+---------+                 | |
| | Helm Charts    | |         | |          |                           | |
| | (chart repo)   | |         | | +--------v---------+                 | |
| +----------------+ |         | | | argocd-repo-     |                 | |
+--------------------+         | | | server            |                | |
                               | | | (clone, render)   |                | |
                               | | +--------+---------+                 | |
                               | |          |                           | |
                               | | +--------v---------+                 | |
                               | | | argocd-          |                 | |
                               | | | application-     |                 | |
                               | | | controller       |                 | |
                               | | | (watch, diff,    |                 | |
                               | | |  sync)           |                 | |
                               | | +--------+---------+                 | |
                               | +--------------------------------------+ |
                               |          |                               |
                               |          | apply manifests               |
                               |          v                               |
                               | +--------------------------------------+ |
                               | | Target Namespaces                    | |
                               | | (app-a, app-b, app-c)                | |
                               | | Deployments, Services, ConfigMaps    | |
                               | +--------------------------------------+ |
                               +------------------------------------------+

Component responsibilities:
+-------------------------+------------------------------------------------+
| Component               | Role                                           |
+-------------------------+------------------------------------------------+
| argocd-server           | API server, Web UI, CLI interface, AuthN/AuthZ |
| argocd-repo-server      | Clone repos, render manifests (Helm/Kustomize) |
| argocd-application-ctrl | Watch apps, compare state, trigger sync        |
| argocd-redis            | Cache for repo-server and controller           |
| argocd-dex-server       | SSO/OIDC authentication (optional)             |
| argocd-notifications    | Send notifications (Slack, email, webhook)     |
+-------------------------+------------------------------------------------+
```

# Mental Model

```text
ArgoCD lifecycle for a single Application:

  [1] Admin creates Application CRD (or via UI/CLI)
      |   - source: Git repo URL + path + revision
      |   - destination: cluster + namespace
      |
      v
  [2] Repo Server clones the Git repository
      |   - Renders manifests (plain YAML, Helm template, Kustomize build)
      |   - Caches result for performance
      |
      v
  [3] Application Controller compares desired state (Git) vs actual state (cluster)
      |
      +---> IN SYNC: no changes needed
      |
      +---> OUT OF SYNC: differences detected
            |
            v
  [4] Sync (manual or automatic based on sync policy)
      |   - Pre-sync hooks run (e.g., database migration Job)
      |   - Resources are applied in order (namespaces first, then deployments)
      |   - Post-sync hooks run (e.g., notification, smoke test)
      |
      v
  [5] Health Assessment
      |   - Check resource health (Deployment rolled out? Service has endpoints?)
      |
      +---> HEALTHY: sync complete, app is green
      |
      +---> DEGRADED/PROGRESSING: investigate, may auto-rollback
      |
      v
  [6] Continuous loop: repeat every 3 minutes (default) or on webhook
```

Example — deploy an app with ArgoCD CLI:

```bash
# Install ArgoCD in cluster
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Login to ArgoCD
argocd login argocd.example.com --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

# Create an application
argocd app create myapp \
  --repo https://github.com/org/k8s-manifests.git \
  --path apps/myapp \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace myapp \
  --sync-policy automated \
  --self-heal \
  --auto-prune

# Check status
argocd app get myapp
```

# Core Building Blocks

### Installation Methods

- `kubectl apply`: apply the install manifest directly (simplest, good for testing).
- **Helm chart**: `helm install argocd argo/argo-cd` — more configurable, easier upgrades.
- **ArgoCD managing itself**: bootstrap ArgoCD, then let it manage its own manifests (app-of-apps).
- High availability: use the HA manifest (`install.yaml` → `ha/install.yaml`) for production.
- Namespace: ArgoCD runs in its own namespace (typically `argocd`).
- ArgoCD is a GitOps operator that runs inside the Kubernetes cluster.
- Three main components: server (API/UI), repo-server (clone/render), application-controller (sync).

```bash
# Helm installation
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd -n argocd --create-namespace

# HA installation (production)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/ha/install.yaml
```

Related notes: [002-argocd-applications](./002-argocd-applications.md)

### Application CRD

- The core resource: defines what to deploy, from where, and to which cluster/namespace.
- Fields: `spec.source` (Git repo + path + revision), `spec.destination` (cluster + namespace), `spec.project`, `spec.syncPolicy`.
- One Application = one deployment unit (a directory of manifests).
- Supports plain YAML, Helm, Kustomize, and Jsonnet for manifest rendering.
- Auto-sync + self-heal + prune = fully automated GitOps.

Related notes: [002-argocd-applications](./002-argocd-applications.md) for detailed Application CRD YAML and configuration options

### Sync Status and Health

- **Sync Status**: does the cluster match Git? (`Synced`, `OutOfSync`, `Unknown`).
- **Health Status**: are the deployed resources healthy? (`Healthy`, `Progressing`, `Degraded`, `Missing`, `Suspended`).
- Dashboard shows both statuses together: Synced+Healthy = green, OutOfSync+Degraded = red.

Related notes: [003-argocd-sync-strategies](./003-argocd-sync-strategies.md) for detailed sync/health definitions and strategies

### Web UI

- Visual dashboard showing all applications, their sync/health status.
- Features:
  - Application tree view: shows all resources and their relationships.
  - Live manifest diff: compare Git desired state vs cluster actual state.
  - Sync and rollback buttons.
  - Resource details: logs, events, pod shell.
  - Settings: repos, clusters, projects, accounts.
- Access: port-forward, Ingress, or load balancer to `argocd-server`.

```bash
# Port-forward to access UI locally
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access at https://localhost:8080
```

Related notes: [005-argocd-admin-operations](./005-argocd-admin-operations.md)

### CLI (argocd)

- Command-line interface for managing ArgoCD applications, projects, repos.
- Key commands:

```bash
# Application management
argocd app list                        # list all apps
argocd app get <app>                   # detailed status
argocd app sync <app>                  # trigger sync
argocd app diff <app>                  # show pending changes
argocd app history <app>              # deployment history
argocd app rollback <app> <id>        # rollback to previous revision

# Repository management
argocd repo add <url> --ssh-private-key-path ~/.ssh/id_rsa
argocd repo list

# Cluster management
argocd cluster add <context>          # register external cluster
argocd cluster list

# Project management
argocd proj create <project>
argocd proj list
```
- Rollback = sync to a previous Git revision.

Related notes: [005-argocd-admin-operations](./005-argocd-admin-operations.md)

### Authentication and Authorization

- **Authentication** (who are you):
  - Local admin account (initial setup).
  - SSO via OIDC (Dex, Okta, GitHub, Google).
  - LDAP integration.
- **Authorization** (what can you do):
  - RBAC policies defined in `argocd-rbac-cm` ConfigMap.
  - Roles: `role:readonly`, `role:admin`, custom roles.
  - Policies: `p, role:dev, applications, sync, myproject/*, allow`.
  - Projects provide additional access control boundaries.

```csv
# RBAC policy example (argocd-rbac-cm)
p, role:developer, applications, get, */*, allow
p, role:developer, applications, sync, dev/*, allow
p, role:developer, applications, sync, staging/*, deny
g, team-dev, role:developer
```

Related notes: [005-argocd-admin-operations](./005-argocd-admin-operations.md)

---

# Troubleshooting Guide

### Cannot access ArgoCD UI

1. Check argocd-server pod is running: `kubectl get pods -n argocd`.
2. Check service: `kubectl get svc argocd-server -n argocd`.
3. Port-forward: `kubectl port-forward svc/argocd-server -n argocd 8080:443`.
4. If using Ingress: check Ingress resource, TLS certificate, DNS.
5. Get initial admin password: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`.

### Application shows "Unknown" status

1. Check repo-server logs: `kubectl logs -n argocd deploy/argocd-repo-server`.
2. Verify repo URL is correct and accessible from the cluster.
3. Check SSH key or token for private repos: `argocd repo list`.
4. Check if the path exists in the repository at the specified revision.
5. Verify manifest rendering: Helm values, Kustomize overlay, plain YAML syntax.

### ArgoCD is slow or unresponsive

1. Check resource usage: `kubectl top pods -n argocd`.
2. Check Redis: repo-server and controller use Redis for caching.
3. Reduce sync frequency if too many apps: increase `timeout.reconciliation` in `argocd-cm`.
4. Check repo-server: large repos or complex Helm charts slow rendering.
5. Consider HA deployment for production workloads.

---

Related notes (Concept):
- [../Concept/011-gitops](../Concept/011-gitops.md) — GitOps principles, pull vs push model, drift detection
- [../Concept/005-deployment-strategies](../Concept/005-deployment-strategies.md) — Blue-Green, Canary, Rolling Update strategies
