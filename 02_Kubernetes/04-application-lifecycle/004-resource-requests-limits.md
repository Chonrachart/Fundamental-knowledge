# Resource Requests and Limits

# Overview
- **Why it exists** — Without resource constraints, a single noisy-neighbor pod can exhaust a node's CPU or memory and starve or kill every other pod on it; requests and limits provide fair allocation and protection.
- **What it is** — Per-container declarations that tell the scheduler how much CPU/memory to reserve (requests) and cap how much the runtime allows the container to consume (limits).
- **One-liner** — Requests reserve capacity for scheduling; limits cap usage at runtime.

### Architecture (ASCII)

```text
Node Allocatable Resources
┌──────────────────────────────────────────────────┐
│  Total:  4 CPU,  8Gi memory                      │
│  System: 0.5 CPU, 1Gi  (reserved for OS/kubelet) │
│  Allocatable: 3.5 CPU, 7Gi                       │
│                                                   │
│  ┌─ Pod A (Guaranteed) ─┐  ┌─ Pod B (Burstable) ─┐│
│  │ req=500m  lim=500m   │  │ req=200m  lim=1      ││
│  │ req=256Mi lim=256Mi  │  │ req=128Mi lim=512Mi  ││
│  └──────────────────────┘  └──────────────────────┘│
│                                                   │
│  Scheduler sums requests: 700m CPU, 384Mi memory  │
│  Remaining allocatable:   2.8 CPU, 6.6Gi          │
│                                                   │
│  Eviction order (memory pressure):                │
│    1. BestEffort  2. Burstable  3. Guaranteed     │
└──────────────────────────────────────────────────┘
```

# Mental Model

```text
Pod with requests=64Mi, limits=128Mi on a node with 1Gi free

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

- **Why it exists** — Provides the scheduler and kubelet with the numbers they need to place and constrain containers.
- **What it is** — Two optional sub-sections under `resources` in a container spec; both accept CPU (cores or millicores) and memory (bytes with SI suffixes).
- **One-liner** — Declare per-container CPU and memory reservation and cap.

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"      # 100 millicores = 0.1 vCPU
  limits:
    memory: "128Mi"
    cpu: "200m"
```

- CPU: `1` = 1 vCPU/core; `100m` = 0.1 CPU; `500m` = half a core
- Memory: prefer `Mi`/`Gi` (binary); `M`/`G` are decimal — different values
- Both are **per-container**; pod total = sum of all containers in the pod
- Limits must be >= requests when both are set

### CPU Throttle vs Memory OOMKill

| Resource | Over-request behavior | Over-limit behavior | Recovery |
|---|---|---|---|
| CPU | Can burst up to limit freely | Throttled (slowed via CFS quota) | Automatic — no kill |
| Memory | Can burst up to limit freely | Container OOMKilled by kernel | kubelet restarts container |

> **Practical note:** Some teams omit the CPU limit to avoid throttling latency, but always set a memory limit in production because OOMKill is fatal and affects availability.

### QoS Classes

- **Why it exists** — Kubernetes needs an eviction priority when a node runs low on memory; QoS class is the tie-breaker.
- **What it is** — A class automatically assigned to each pod based on how requests and limits are set across all its containers.
- **One-liner** — Determines which pods are evicted first under node memory pressure.

| QoS Class | Condition | Eviction order |
|---|---|---|
| **Guaranteed** | Every container has requests == limits for both CPU and memory | Last (evicted only as last resort) |
| **Burstable** | At least one container has a request or limit; not all equal | Middle |
| **BestEffort** | No requests or limits set on any container | First |

Check a pod's QoS class:
```bash
kubectl get pod <name> -o jsonpath='{.status.qosClass}'
```

### ResourceQuota (Namespace-level caps)

- **Why it exists** — Prevents a single team's namespace from monopolizing cluster resources; enforces capacity governance across teams.
- **What it is** — A namespace-scoped object that caps the total sum of requests and limits across all pods, and optionally limits counts of objects (PVCs, Services, etc.).
- **One-liner** — Namespace-wide ceiling on total resource consumption.

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: team-a
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
```

- When a ResourceQuota with requests/limits is active, **every pod in the namespace must have requests and limits set** (or be covered by a LimitRange default)
- Check usage: `kubectl describe resourcequota -n <namespace>`

### LimitRange (Per-container defaults and bounds)

- **Why it exists** — Without defaults, pods created without explicit requests/limits in a quota-enforced namespace are rejected; LimitRange provides automatic defaults and enforces min/max bounds.
- **What it is** — A namespace-scoped object that sets default requests/limits injected into containers that omit them, and defines allowed min/max ranges.
- **One-liner** — Auto-inject default requests/limits and enforce per-container min/max bounds.

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: cpu-mem-limit
spec:
  limits:
  - type: Container
    default:
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
```

### Observability Commands

```bash
kubectl top pods                          # CPU/memory usage (requires metrics-server)
kubectl top pods --sort-by=memory         # sorted by memory
kubectl top nodes                         # node-level resource usage
kubectl describe resourcequota -n <ns>    # quota used vs hard limits
kubectl describe limitrange -n <ns>       # configured defaults and bounds
kubectl describe pod <name>               # see Requests and Limits in container spec
```

# Troubleshooting

### Pod OOMKilled
1. Confirm: `kubectl describe pod <name>` — Last State shows `Reason: OOMKilled`
2. Increase memory limit or fix the memory leak in the application
3. Check QoS class — `BestEffort` pods are evicted first under node pressure, which may appear similar

### Pod rejected by ResourceQuota — "exceeded quota"
1. Check current usage: `kubectl describe resourcequota -n <namespace>`
2. Either increase the quota (if capacity allows) or reduce requests on the pod
3. Ensure every pod has requests and limits set when a quota is active

### CPU throttling causing slow responses
1. Check if a CPU limit is set too low: `kubectl describe pod <name>`
2. Consider removing the CPU limit (keep the request) to eliminate throttling
3. Monitor actual usage: `kubectl top pod <name>` (requires metrics-server)
