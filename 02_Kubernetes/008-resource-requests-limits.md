# Resource Requests and Limits

- Requests tell the scheduler how much CPU/memory to reserve; limits cap what a container can actually use.
- CPU limit causes throttling; memory limit causes OOMKill -- exceeding memory is fatal, exceeding CPU is not.
- QoS class (Guaranteed, Burstable, BestEffort) is derived from requests/limits and determines eviction order under pressure.

# Mental Model

```text
Scenario: Pod with requests=64Mi, limits=128Mi on a node with 1Gi free

1. Scheduler checks: node has 1Gi allocatable → 64Mi request fits → pod scheduled
2. Pod starts, uses 60Mi → fine (under request, under limit)
3. Load spike → usage grows to 100Mi → still fine (above request, under limit)
4. Memory leak → usage hits 128Mi → kernel OOM-kills the container
5. kubelet restarts container → CrashLoopBackOff if it keeps hitting limit

CPU behaves differently:
  request=100m, limit=200m
  Usage hits 200m → container is throttled (slowed), NOT killed
```

# Core Building Blocks

### Requests and Limits Syntax

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"
    cpu: "200m"
```

- Both are per-container; pod total = sum of all containers in the pod.
- CPU: 1 = 1 vCPU/core; 100m = 0.1 CPU.
- Memory: Mi, Gi (binary); M, G (decimal) -- prefer Mi/Gi.

### Why Set Requests

- Without requests, scheduler does not reserve resources; many pods can be placed on same node and contend.
- Requests ensure "guaranteed" share for scheduling; actual usage can go above requests up to limits (if set).
- Always set requests in production so cluster capacity is predictable.

### Why Set Limits

- Limits prevent a single container from using all node CPU/memory.
- Memory limit is hard -- exceeding leads to OOMKill.
- CPU limit causes throttling (cpu quota); no kill. Some teams omit CPU limit to avoid throttling but still set memory limit.
- Limits should be >= requests (if both set); requests can be set without limits (then no cap, but scheduler still uses requests).

### QoS (Quality of Service) Classes

- **Guaranteed**: every container has requests and limits set and they are equal (for both CPU and memory). Last to be evicted under memory pressure.
- **Burstable**: at least one container has requests or limits; requests < limits or only one set. Evicted after Guaranteed.
- **BestEffort**: no requests or limits. First to be evicted when node is under pressure.
- Eviction order (when node has memory pressure): BestEffort -> Burstable (by usage above requests) -> Guaranteed last.

### OOMKilled

- When node runs out of memory, kubelet evicts pods (by QoS and usage); if a container exceeds its memory limit, the kernel OOM-kills that container (container exits with OOMKilled reason).
- Check `kubectl describe pod` (Last State, Reason: OOMKilled); increase limit or fix memory leak.

### Resource Quota (Namespace)

- ResourceQuota limits total resources in a namespace: sum of requests/limits across all pods (and optionally PVC, counts of objects).
- Prevents one namespace from consuming entire cluster; requests and limits must be set on pods when quota has requests/limits.

### LimitRange (Namespace)

- LimitRange sets default and allowed min/max for requests and limits in a namespace.
- **default**: applied when container omits requests/limits; defaultRequest / default for CPU/memory.
- **min/max**: reject pod if any container is below min or above max.
- Useful to enforce "every container must have requests" or cap max per container.

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: cpu-mem-limit
spec:
  limits:
  - default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "64Mi"
    max:
      cpu: "2"
      memory: "2Gi"
    min:
      cpu: "50m"
      memory: "32Mi"
    type: Container
```

Related notes: [002-pods-labels](./002-pods-labels.md), [009-hpa-pod-disruption](./009-hpa-pod-disruption.md)

---

# Troubleshooting Guide

### Pod OOMKilled
1. Check: `kubectl describe pod <name>` -- Last State: OOMKilled.
2. Increase memory limit or fix memory leak in app.
3. Check QoS class: BestEffort pods are evicted first under node pressure.

### Pod rejected by ResourceQuota
1. Error: "exceeded quota" when creating pod.
2. Check quota: `kubectl describe resourcequota -n <ns>`.
3. Either increase quota or reduce resource requests on pods.

### CPU throttling causing slow response
1. Check if CPU limit is set too low: `kubectl describe pod <name>`.
2. Consider removing CPU limit (keep requests) to avoid throttling.
3. Monitor with: `kubectl top pod <name>` (requires metrics-server).

# Quick Facts (Revision)

- Requests are for the scheduler (reserve capacity); limits are for the runtime (cap usage).
- CPU over-limit = throttling (slow); memory over-limit = OOMKill (fatal).
- QoS Guaranteed requires requests == limits for both CPU and memory on every container.
- BestEffort pods (no requests, no limits) are evicted first under node memory pressure.
- LimitRange sets defaults so pods without explicit requests/limits still get them.
- ResourceQuota caps the total resource consumption for an entire namespace.
- Always set memory limits in production; CPU limits are debatable (throttling vs starvation trade-off).
- `kubectl top pod` requires metrics-server to be running in the cluster.
