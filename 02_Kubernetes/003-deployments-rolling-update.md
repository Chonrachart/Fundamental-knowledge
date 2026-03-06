Deployment
ReplicaSet
rolling update
rollback
strategy
revision
history

---

# Deployment and ReplicaSet

- **Deployment** manages **ReplicaSet(s)** and declarative updates; ReplicaSet ensures N pods with a given pod template.
- Each change to pod template creates a new ReplicaSet; Deployment scales down old ReplicaSet and scales up new one (rolling).
- **kubectl get rs**: See ReplicaSets; each has a revision (hash in name or via annotation).

# Rolling Update (Default)

- **Strategy**: RollingUpdate; new pods created, old pods terminated gradually.
- **maxSurge**: How many extra pods above desired count (default 25%); can be number.
- **maxUnavailable**: How many pods can be unavailable during update (default 25%); can be 0 for zero-downtime.
- **minReadySeconds**: Pod must be ready for this many seconds before considered available; slows rollout if set.

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

# Paused and Resume

- **kubectl rollout pause deployment/myapp**: Pause rollout; you can make multiple changes then resume.
- **kubectl rollout resume deployment/myapp**: Resume; single rollout with all changes.
- Useful when applying several fixes without triggering multiple rollouts.

# Rollback

- **kubectl rollout undo deployment/myapp**: Roll back to previous revision.
- **kubectl rollout undo deployment/myapp --to-revision=2**: Roll back to specific revision.
- **kubectl rollout history deployment/myapp**: List revisions; **--revision=N** for details.
- Rollback creates a new revision (re-applying old template); history is retained (within revisionHistoryLimit).

# Status and Progress

- **kubectl rollout status deployment/myapp**: Block until rollout completes or fails.
- **kubectl rollout status deployment/myapp --timeout=5m**: Timeout.
- **kubectl get deployment myapp**: Observe **DESIRED**, **CURRENT**, **UP-TO-DATE**, **READY**; **AVAILABLE** in describe.

# Revision History Limit

- **revisionHistoryLimit** (default 10): How many old ReplicaSets to keep; older ones are deleted.
- Affects how far back you can rollback.

# Scaling and Proportional Scaling

- **kubectl scale deployment myapp --replicas=5**: Change desired replicas; Deployment/ReplicaSet reconcile.
- During rolling update, total pods can temporarily be **desired + maxSurge** (or desired - maxUnavailable); controller keeps within strategy.

# Best Practices

- Use **readiness probes** so traffic only goes to pods that are ready; avoids 502s during rollout.
- Set **maxUnavailable: 0** and **maxSurge: 1** (or similar) for zero-downtime when you have multiple replicas.
- Pin **image** to tag or digest; avoid `latest` in production so rollback is predictable.
- Check **rollout status** in CI before considering deploy successful.
