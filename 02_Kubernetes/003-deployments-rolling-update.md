# Deployments and Rolling Updates

- A Deployment manages ReplicaSets declaratively; each pod template change creates a new ReplicaSet and triggers a rolling update.
- Rolling updates gradually replace old pods with new ones, controlled by maxSurge and maxUnavailable parameters.
- Rollback reverts to a previous ReplicaSet revision; history depth is governed by revisionHistoryLimit (default 10).

# Architecture

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

# Mental Model

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

Example:

```bash
kubectl set image deployment/myapp web=nginx:1.25    # triggers rolling update
kubectl rollout status deployment/myapp              # watch progress
kubectl rollout undo deployment/myapp                # rollback if needed
```

# Core Building Blocks

### Deployment and ReplicaSet

- **Deployment** manages **ReplicaSet(s)** and declarative updates; ReplicaSet ensures N pods with a given pod template.
- Each change to pod template creates a new ReplicaSet; Deployment scales down old ReplicaSet and scales up new one (rolling).
- `kubectl get rs`: See ReplicaSets; each has a revision (hash in name or via annotation).
- Each pod template change creates a new ReplicaSet; the Deployment orchestrates the transition.

### Rolling Update (Default)

- **Strategy**: `RollingUpdate`; new pods created, old pods terminated gradually.
- `maxSurge`: How many extra pods above desired count (default 25%); can be number.
- `maxUnavailable`: How many pods can be unavailable during update (default 25%); can be 0 for zero-downtime.
- `minReadySeconds`: Pod must be ready for this many seconds before considered available; slows rollout if set.
- Default strategy is `RollingUpdate` with 25% `maxSurge` and 25% `maxUnavailable`.
- `maxUnavailable: 0` ensures zero-downtime during rollouts (requires at least `maxSurge: 1`).
- `minReadySeconds` adds a delay before a new pod is counted as available — useful for catching early crashes.

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

### Pause and Resume

- `kubectl rollout pause deployment/myapp`: Pause rollout; you can make multiple changes then resume.
- `kubectl rollout resume deployment/myapp`: Resume; single rollout with all changes.
- Useful when applying several fixes without triggering multiple rollouts.
- Pausing a deployment lets you batch multiple spec changes into a single rollout.

### Rollback

- `kubectl rollout undo deployment/myapp`: Roll back to previous revision.
- `kubectl rollout undo deployment/myapp --to-revision=2`: Roll back to specific revision.
- `kubectl rollout history deployment/myapp`: List revisions; `--revision=N` for details.
- Rollback creates a new revision (re-applying old template); history is retained (within revisionHistoryLimit).
- `kubectl rollout undo` creates a new revision pointing to the old pod template, not a true revert.

### Status and Progress

- `kubectl rollout status deployment/myapp`: Block until rollout completes or fails.
- `kubectl rollout status deployment/myapp --timeout=5m`: Timeout.
- `kubectl get deployment myapp`: Observe `DESIRED`, `CURRENT`, `UP-TO-DATE`, `READY`; `AVAILABLE` in describe.

### Revision History Limit

- `revisionHistoryLimit` (default 10): How many old ReplicaSets to keep; older ones are deleted.
- Affects how far back you can rollback.
- `revisionHistoryLimit` defaults to 10; setting it to 0 disables rollback.

### Scaling and Proportional Scaling

- `kubectl scale deployment myapp --replicas=5`: Change desired replicas; Deployment/ReplicaSet reconcile.
- During rolling update, total pods can temporarily be `desired + maxSurge` (or `desired - maxUnavailable`); controller keeps within strategy.

### Best Practices

- Use **readiness probes** so traffic only goes to pods that are ready; avoids 502s during rollout.
- Set `maxUnavailable: 0` and `maxSurge: 1` (or similar) for zero-downtime when you have multiple replicas.
- Pin `image` to tag or digest; avoid `latest` in production so rollback is predictable.
- Check `rollout status` in CI before considering deploy successful.

Related notes: [002-pods-labels](./002-pods-labels.md), [004-services-ingress](./004-services-ingress.md), [009-hpa-pod-disruption](./009-hpa-pod-disruption.md)

---

# Troubleshooting Guide

### Rollout stuck — new pods not becoming Ready
1. Check new pod status: `kubectl get pods` — look for Pending, CrashLoopBackOff, ImagePullBackOff.
2. Check events: `kubectl describe deployment <name>` and `kubectl describe pod <new-pod>`.
3. Common: bad image tag, missing config, failing readiness probe.
4. Rollback: `kubectl rollout undo deployment/<name>`.

### Rolling update causes downtime
1. Check `maxUnavailable`: if too high, too many old pods killed before new ones ready.
2. Set `maxUnavailable: 0` and `maxSurge: 1` for zero-downtime.
3. Ensure readiness probe is configured — without it, traffic goes to unready pods.

### Cannot rollback — "no rollout history"
1. Check `revisionHistoryLimit`: if 0, old ReplicaSets are deleted.
2. List history: `kubectl rollout history deployment/<name>`.
3. If needed, manually re-apply old manifest from Git.
