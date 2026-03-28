# Rolling Updates and Rollback

## Overview
**Why it exists** — Deploying new versions without downtime requires gradually replacing old pods with new ones; rolling back instantly when something goes wrong requires keeping the previous state readily available.
**What it is** — A Deployment update strategy that incrementally swaps old pods for new ones, controlled by `maxSurge` and `maxUnavailable`, backed by preserved old ReplicaSets for rollback.
**One-liner** — Zero-downtime deploys with instant rollback via Deployment-managed ReplicaSet revisions.

## Architecture (ASCII)

```text
Deployment (desired state: image, replicas, strategy)
    │
    ├── ReplicaSet v2 (current)   replicas: 3
    │       ├── Pod-a  (Running)
    │       ├── Pod-b  (Running)
    │       └── Pod-c  (Running)
    │
    └── ReplicaSet v1 (previous)  replicas: 0  (kept for rollback)

Rolling Update (maxSurge:1, maxUnavailable:0):
  v1: ███  v2: _       ← start
  v1: ███  v2: █       ← surge: +1 new pod
  v1: ██   v2: █       ← old pod terminated
  v1: ██   v2: ██      ← surge again
  v1: █    v2: ██      ← old pod terminated
  v1: █    v2: ███     ← surge again
  v1: _    v2: ███     ← complete
```

## Mental Model

```text
kubectl apply (new image tag)
        │
        ▼
Deployment creates new ReplicaSet (revision N+1)
        │
        ▼
New ReplicaSet scales up by maxSurge
        │
        ▼
Old ReplicaSet scales down by maxUnavailable
        │
        ▼
Repeat until new ReplicaSet has all desired pods
and old ReplicaSet has 0
        │
        ▼
Rollout complete — old ReplicaSet kept (scaled to 0)
for rollback within revisionHistoryLimit
```

Rollback reuses the old ReplicaSet by scaling it back up. It creates a **new revision** pointing at the old pod template rather than reverting history.

## Core Building Blocks

### RollingUpdate vs Recreate Strategy

| Strategy | Behavior | Downtime? | Use case |
|---|---|---|---|
| `RollingUpdate` (default) | Gradually replace pods; old and new run in parallel | No | Production apps requiring availability |
| `Recreate` | Terminate all old pods first, then start new ones | Yes | Apps that cannot run two versions simultaneously |

### maxSurge and maxUnavailable

**Why they exist** — They let you tune the speed/safety tradeoff: more surge = faster rollout but higher resource cost; less unavailable = safer but slower.
**What they are** — `maxSurge` is the maximum number of extra pods above desired count; `maxUnavailable` is the maximum number of pods that can be unavailable during the update. Both accept absolute numbers or percentages.
**One-liner** — `maxSurge` controls how many new pods to add; `maxUnavailable` controls how many old pods to remove before replacements are ready.

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1          # up to desired+1 pods total during rollout
      maxUnavailable: 0    # zero-downtime: never reduce below desired count
```

- Default: `maxSurge: 25%`, `maxUnavailable: 25%`
- `maxUnavailable: 0` requires at least `maxSurge: 1`
- `minReadySeconds`: pod must stay Ready for this many seconds before counted as available; useful to catch early crashes

### kubectl rollout status

**Why it exists** — Lets CI/CD pipelines block until a rollout finishes, catching failures before marking a deploy as successful.

```bash
kubectl rollout status deployment/myapp              # block until complete
kubectl rollout status deployment/myapp --timeout=5m # with timeout
kubectl get deployment myapp                         # see READY, UP-TO-DATE columns
```

### kubectl rollout history

**Why it exists** — Provides an audit trail of changes and exposes revision numbers needed for targeted rollback.

```bash
kubectl rollout history deployment/myapp             # list all revisions
kubectl rollout history deployment/myapp --revision=2 # detail for revision 2
```

- `revisionHistoryLimit` (default 10): number of old ReplicaSets retained; set to 0 to disable rollback
- Each `kubectl apply` with a changed pod template increments the revision counter

### kubectl rollout undo

**Why it exists** — One-command rollback when a deploy goes bad; avoids manually re-applying old manifests.

```bash
kubectl rollout undo deployment/myapp                # roll back to previous revision
kubectl rollout undo deployment/myapp --to-revision=2 # roll back to specific revision
```

- Rollback re-applies the old pod template as a **new** revision (N+2), not a true revert
- The old ReplicaSet is simply scaled back up; the previously-scaled-down pods are replaced with new ones from the old template

### kubectl rollout pause / resume

**Why it exists** — Lets you batch multiple spec changes into a single rollout rather than triggering one rollout per change.

```bash
kubectl rollout pause deployment/myapp     # freeze; apply multiple changes
kubectl set image deployment/myapp web=nginx:1.25
kubectl set env deployment/myapp LOG_LEVEL=debug
kubectl rollout resume deployment/myapp   # single rollout applies all changes
```

### How Rollback Works

1. `kubectl rollout undo` finds the target revision's ReplicaSet
2. Deployment scales that ReplicaSet back up (using the same rolling strategy)
3. Current ReplicaSet scales down to 0
4. Old ReplicaSet becomes the new "current" at revision N+1

```bash
kubectl set image deployment/myapp web=nginx:1.25    # triggers rolling update
kubectl rollout status deployment/myapp              # watch progress
kubectl rollout undo deployment/myapp                # rollback if needed
```

## Troubleshooting

### Rollout stuck — new pods not becoming Ready
1. Check pod status: `kubectl get pods` — look for `Pending`, `CrashLoopBackOff`, `ImagePullBackOff`
2. Check events: `kubectl describe deployment <name>` and `kubectl describe pod <new-pod>`
3. Common causes: bad image tag, missing ConfigMap/Secret, failing readiness probe
4. Rollback immediately: `kubectl rollout undo deployment/<name>`

### Rolling update causes downtime
1. Check `maxUnavailable` — if too high, too many old pods are killed before new ones are ready
2. Set `maxUnavailable: 0` and `maxSurge: 1` for zero-downtime deployments
3. Ensure a readiness probe is configured — without it Kubernetes sends traffic to unready pods

### Cannot rollback — "no rollout history"
1. Check `revisionHistoryLimit` — if set to 0, old ReplicaSets are deleted immediately
2. List available history: `kubectl rollout history deployment/<name>`
3. If history is gone, re-apply the old manifest from source control
