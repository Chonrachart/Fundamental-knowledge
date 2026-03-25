# ArgoCD Sync Strategies

- Sync is the process of applying desired state (from Git) to the cluster — it can be manual (on-demand) or automated (on every Git change).
- Sync hooks and waves provide fine-grained control over the order and lifecycle of resource creation during a sync operation.
- Sync windows restrict when syncs can occur, enabling maintenance windows and change freeze policies.

# Architecture

```text
Sync Lifecycle:

  Git Change Detected
        |
        v
  +------------------+
  | PRE-SYNC HOOKS   |  (e.g., database migration Job, notification)
  | (wave: -1, 0)    |
  +--------+---------+
           |
           v
  +------------------+
  | SYNC             |  Apply resources in wave order
  | Wave -2: Namespace|  (lower waves first, then higher)
  | Wave -1: ConfigMap|
  | Wave  0: Deployment|
  | Wave  1: Ingress  |
  +--------+---------+
           |
           v
  +------------------+
  | POST-SYNC HOOKS  |  (e.g., smoke test Job, Slack notification)
  | (wave: 0, 1)     |
  +--------+---------+
           |
           v
  +------------------+
  | SYNC SUCCESS     |  (or SYNC FAILED)
  | Health check     |
  +------------------+

Sync Policy Options:
+----------------------+--------------------------------------------------+
| Option               | Effect                                           |
+----------------------+--------------------------------------------------+
| automated            | Sync when Git changes (no manual trigger needed) |
| selfHeal             | Revert manual cluster changes to match Git       |
| prune                | Delete resources removed from Git                |
| PruneLast            | Prune after all other resources are synced       |
| ApplyOutOfSyncOnly   | Only apply resources that have changed           |
| CreateNamespace      | Create destination namespace if it doesn't exist |
| ServerSideApply      | Use server-side apply instead of client-side     |
| Replace              | Use kubectl replace instead of apply             |
| retry                | Retry failed syncs with backoff                  |
+----------------------+--------------------------------------------------+
```

# Mental Model

```text
Choosing a sync strategy:

  [1] Should ArgoCD sync automatically when Git changes?
      |
      +--YES--> syncPolicy.automated: true
      |         |
      |         +-- Should it revert manual cluster changes?
      |         |   +--YES--> selfHeal: true (recommended for prod)
      |         |
      |         +-- Should it delete resources removed from Git?
      |             +--YES--> prune: true (recommended)
      |
      +--NO---> Manual sync via UI or CLI
      |
      v
  [2] Do resources need to be applied in a specific order?
      |
      +--YES--> Use sync waves (annotations: argocd.argoproj.io/sync-wave)
      |
      v
  [3] Do you need pre/post-sync actions (migrations, tests)?
      |
      +--YES--> Use sync hooks (PreSync, PostSync annotations)
      |
      v
  [4] Should syncs be restricted to certain time windows?
      |
      +--YES--> Configure sync windows (allow/deny schedules)
      |
      v
  [5] Are syncs failing intermittently?
      |
      +--YES--> Add retry with backoff
```

# Core Building Blocks

### Manual vs Automated Sync

- **Manual sync**: user triggers sync via UI, CLI, or API.
  - Best for: production environments where every deployment needs explicit approval.
  - Command: `argocd app sync myapp`.
- **Automated sync**: ArgoCD syncs automatically when Git changes are detected.
  - Detection: polling every 3 min (default) or via webhook.
  - Best for: staging/dev environments where fast iteration is needed.
  - Requires `syncPolicy.automated` in Application spec.
- Auto-sync: ArgoCD applies Git changes automatically; manual: user triggers sync.

```yaml
# Manual sync (no syncPolicy.automated)
spec:
  syncPolicy: {}

# Automated sync
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Related notes: [001-argocd-overview](./001-argocd-overview.md)

### Self-Heal

- Automatically reverts manual changes made to cluster resources.
- If someone runs `kubectl edit` or `kubectl scale`, ArgoCD detects drift and resets to Git state.
- Check interval: every 5 seconds (default) for self-heal detection.
- Enable: `syncPolicy.automated.selfHeal: true`.
- Important: must be combined with `automated` — self-heal only works with auto-sync.
- Exception: use `ignoreDifferences` to exclude fields managed by other controllers (e.g., HPA replicas).
- Self-heal: reverts manual cluster changes back to Git state.
- ignoreDifferences: exclude fields managed by other controllers from sync comparison.

Related notes: [001-argocd-overview](./001-argocd-overview.md)

### Prune

- Delete cluster resources that no longer exist in Git.
- Without prune: removing a manifest from Git leaves the resource orphaned in the cluster.
- With prune: ArgoCD deletes the resource when the manifest is removed from Git.
- `PruneLast`: prune after all other resources are synced (prevents deleting before replacement is ready).
- **Danger**: accidentally removing a file from Git with prune enabled deletes it from the cluster.
- Safety: ArgoCD shows what will be pruned before sync; review in UI or `argocd app diff`.
- Prune: deletes resources removed from Git; PruneLast prunes after sync completes.

Related notes: [002-argocd-applications](./002-argocd-applications.md)

### Sync Waves

- Control the order in which resources are applied during a sync.
- Annotate resources with `argocd.argoproj.io/sync-wave: "N"`.
- Lower wave numbers are applied first; resources in the same wave are applied together.
- Default wave: 0. Negative waves run before default; positive after.
- ArgoCD waits for resources in a wave to be healthy before proceeding to the next wave.
- Sync waves: control resource ordering with wave annotations (-N first, +N last).

```yaml
# Wave -1: Create namespace and config first
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  annotations:
    argocd.argoproj.io/sync-wave: "-1"

---
# Wave 0: Deploy application (default)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  # sync-wave: "0" is default, annotation not needed

---
# Wave 1: Create Ingress after deployment is ready
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

```text
Sync wave execution order:
  Wave -2: Namespace, RBAC
  Wave -1: ConfigMaps, Secrets
  Wave  0: Deployments, Services (default)
  Wave  1: Ingress, NetworkPolicy
  Wave  2: Monitoring, alerts
```

Related notes: [004-argocd-advanced-patterns](./004-argocd-advanced-patterns.md)

### Sync Hooks

- Run Jobs or other resources at specific points in the sync lifecycle.
- Hook types:
  - **PreSync**: run before sync (e.g., database migration).
  - **Sync**: run during sync (same as normal resources).
  - **PostSync**: run after sync succeeds (e.g., smoke test, notification).
  - **SyncFail**: run if sync fails (e.g., rollback trigger, alert).
  - **PostDelete**: run when Application is deleted (cleanup).
- Hook delete policies:
  - `HookSucceeded`: delete hook resource after it succeeds.
  - `HookFailed`: delete hook resource after it fails.
  - `BeforeHookCreation`: delete previous hook before creating new one.
- Sync hooks: PreSync (migrations), PostSync (tests), SyncFail (alerts).

```yaml
# PreSync hook: database migration
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: myapp:latest
          command: ["./migrate.sh"]
      restartPolicy: Never

---
# PostSync hook: smoke test
apiVersion: batch/v1
kind: Job
metadata:
  name: smoke-test
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
        - name: test
          image: curlimages/curl
          command: ["curl", "-f", "http://myapp/health"]
      restartPolicy: Never
```

Related notes: [004-argocd-advanced-patterns](./004-argocd-advanced-patterns.md)

### Sync Windows

- Restrict when syncs are allowed (or denied) — like maintenance windows.
- Types:
  - **Allow**: syncs only during this window.
  - **Deny**: no syncs during this window (change freeze).
- Scope: by application, namespace, or cluster.
- Schedule: cron format.

```yaml
# In AppProject spec
spec:
  syncWindows:
    # Allow syncs only during business hours
    - kind: allow
      schedule: '0 9 * * 1-5'    # Mon-Fri 9am
      duration: 8h                # 9am-5pm
      applications: ['*']
      namespaces: ['prod-*']

    # Deny syncs during weekend
    - kind: deny
      schedule: '0 0 * * 0,6'    # Sat-Sun midnight
      duration: 48h
      applications: ['*']

    # Manual override: allow specific app even during deny window
    - kind: allow
      schedule: '* * * * *'
      duration: 1h
      applications: ['hotfix-*']
      manualSync: true
```
- Sync windows: cron-based allow/deny windows for change management.

Related notes: [005-argocd-admin-operations](./005-argocd-admin-operations.md)

### Retry Policy

- Automatically retry failed syncs with exponential backoff.
- Useful for transient failures (API server overload, temporary network issues).

```yaml
spec:
  syncPolicy:
    retry:
      limit: 5              # max retry attempts
      backoff:
        duration: 5s         # initial backoff
        factor: 2            # multiplier
        maxDuration: 3m      # max wait between retries
```

- Retry sequence: 5s, 10s, 20s, 40s, 80s (capped at 3m).
- Do not rely on retry for persistent failures — investigate root cause.
- Retry: exponential backoff for transient failures; don't mask persistent issues.

Related notes: [001-argocd-overview](./001-argocd-overview.md)

### Sync Options

- Fine-tune sync behavior per application or per resource.

```yaml
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true        # create ns if missing
      - PruneLast=true              # prune after sync complete
      - ApplyOutOfSyncOnly=true     # skip in-sync resources
      - ServerSideApply=true        # use server-side apply
      - PrunePropagationPolicy=foreground  # wait for dependents
      - Validate=false              # skip validation (use cautiously)
      - RespectIgnoreDifferences=true  # don't sync ignored fields
```

- Per-resource annotation: `argocd.argoproj.io/sync-options: Prune=false` (prevent pruning specific resource).

Related notes: [002-argocd-applications](./002-argocd-applications.md)

---

# Troubleshooting Guide

### Sync fails with "resource already exists"

1. Resource was created outside ArgoCD (manually or by another tool).
2. Solution: import existing resource by adding `argocd.argoproj.io/managed-by: argocd` annotation.
3. Or use `Replace=true` sync option to overwrite.
4. Or delete the existing resource and let ArgoCD recreate it.
5. Check if another Application manages the same resource (conflict).

### PreSync hook Job never completes

1. Check Job pod logs: `kubectl logs job/db-migrate -n myapp`.
2. Check if the Job image can be pulled (ImagePullBackOff).
3. Check resource limits: Job may be OOMKilled.
4. Check `restartPolicy`: should be `Never` or `OnFailure` for hooks.
5. Set `activeDeadlineSeconds` on the Job to prevent infinite hangs.
6. Check `hook-delete-policy`: `BeforeHookCreation` ensures old hooks are cleaned up.

### Self-heal keeps reverting desired changes

1. Check if the change was made via Git (self-heal only reverts non-Git changes).
2. If another controller manages the field (HPA, cert-manager): add to `ignoreDifferences`.
3. Check sync interval: frequent self-heal checks may conflict with gradual changes.
4. Temporarily disable self-heal for debugging: remove from syncPolicy.
5. Use `argocd app diff myapp` to see exactly what ArgoCD considers out-of-sync.

---

Related notes (Concept):
- [../Concept/011-gitops](../Concept/011-gitops.md) — GitOps reconciliation loop, drift detection
- [../Concept/005-deployment-strategies](../Concept/005-deployment-strategies.md) — Deployment strategies that sync supports
