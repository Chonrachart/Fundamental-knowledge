requests
limits
QoS
OOM
scheduler
resource quota
limit range

---

# requests and limits

- **requests**: What the **scheduler** uses; node must have at least this much allocatable (CPU/memory) to schedule the pod.
- **limits**: Maximum the container can use; **CPU** is throttled if exceeded; **memory** can lead to **OOMKill** if exceeded.
- Both are per-container; pod total = sum of all containers in the pod.
- **CPU**: 1 = 1 vCPU/core; **100m** = 0.1 CPU; **memory**: Mi, Gi (binary); M, G (decimal) — prefer Mi/Gi.

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"
    cpu: "200m"
```

# Why Set requests

- Without **requests**, scheduler does not reserve resources; many pods can be placed on same node and contend.
- **requests** ensure “guaranteed” share for scheduling; actual usage can go above requests up to **limits** (if set).
- Always set **requests** in production so cluster capacity is predictable; set **limits** to cap burst and avoid one pod starving others.

# Why Set limits

- **limits** prevent a single container from using all node CPU/memory; **memory limit** is hard — exceeding leads to OOMKill.
- **CPU limit** causes throttling (cpu quota); no kill. Some teams omit CPU limit to avoid throttling but still set memory limit.
- **limits** should be >= **requests** (if both set); **requests** can be set without limits (then no cap, but scheduler still uses requests).

# QoS (Quality of Service) Classes

- **Guaranteed**: Every container has requests and limits set and they are equal (for both CPU and memory). Last to be evicted under memory pressure.
- **Burstable**: At least one container has requests or limits; requests &lt; limits or only one set. Evicted after Guaranteed.
- **BestEffort**: No requests or limits. First to be evicted when node is under pressure.
- Eviction order (when node has memory pressure): BestEffort → Burstable (by usage above requests) → Guaranteed last.

# OOMKilled

- When node runs out of memory, kubelet evicts pods (by QoS and usage); if a **container** exceeds its **memory limit**, the kernel can OOM-kill that container (container exits with OOMKilled reason).
- Check **kubectl describe pod** (Last State, Reason: OOMKilled); increase limit or fix memory leak.

# Resource Quota (Namespace)

- **ResourceQuota** limits total resources in a namespace: sum of requests/limits across all pods (and optionally PVC, counts of objects).
- Prevents one namespace from consuming entire cluster; requests and limits must be set on pods when quota has requests/limits.

# LimitRange (Namespace)

- **LimitRange** sets default and allowed min/max for requests and limits in a namespace.
- **default**: Applied when container omits requests/limits; **defaultRequest** / **default** for CPU/memory.
- **min/max**: Reject pod if any container is below min or above max.
- Useful to enforce “every container must have requests” or cap max per container.

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

# Summary

- **requests**: Used by scheduler; reserve capacity; set for all production pods.
- **limits**: Cap usage; memory limit avoids unbounded use and OOM on node; CPU limit throttles.
- **QoS** is derived from requests/limits; affects eviction order.
- Use **ResourceQuota** and **LimitRange** to govern namespace usage and defaults.
