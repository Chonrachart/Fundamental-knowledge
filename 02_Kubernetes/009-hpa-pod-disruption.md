# HPA and Pod Disruption Budget

- HPA (Horizontal Pod Autoscaler) scales replicas based on CPU, memory, or custom metrics to match demand automatically.
- PDB (Pod Disruption Budget) limits how many pods can be voluntarily evicted at once during drains and upgrades.
- HPA handles scaling for load; PDB handles safety during maintenance -- they complement each other.

# Architecture

```text
                    ┌───────────────┐
                    │ metrics-server│ (or Prometheus adapter)
                    └───────┬───────┘
                            │ CPU/memory/custom metrics
                            ▼
┌──────────────────────────────────────────────┐
│  HPA Controller (runs in controller-manager) │
│                                              │
│  every 15s:                                  │
│    current = avg metric across pods          │
│    desired = current * (currentVal/targetVal)│
│    clamp to [minReplicas, maxReplicas]       │
│    stabilize (scaleDown window: 300s)        │
└──────────────────┬───────────────────────────┘
                   │ patch replicas
                   ▼
            ┌──────────────┐
            │  Deployment  │ ──► ReplicaSet ──► Pods
            └──────────────┘
```

# Mental Model

```text
Scenario: Deployment with HPA (min=2, max=10, target CPU=70%) and PDB (minAvailable=2)

Normal load:
  HPA sees avg CPU = 30% → keeps 2 replicas (min)

Traffic spike:
  HPA sees avg CPU = 85% → scales to 3, then 4... up to 10
  Formula: desired = current * (currentMetric / targetMetric)
           desired = 2 * (85/70) = 2.4 → rounds up to 3

Node drain during upgrade:
  3 pods running, PDB minAvailable=2
  Drain evicts 1 pod → 2 remain (PDB satisfied) → eviction proceeds
  Drain tries 2nd pod → only 1 would remain → blocked until replacement is Ready
```

# Core Building Blocks

### HPA Spec

- **scaleTargetRef**: the Deployment/ReplicaSet/StatefulSet to scale.
- **minReplicas**, **maxReplicas**: HPA adjusts current replicas within this range.
- **metrics**: resource (cpu, memory), pods (custom per-pod), object (metric from another object), external (outside cluster).
- **target**: e.g. type: Utilization, averageUtilization: 70 (CPU); or type: Value for custom metric.
- **behavior** (optional): scaleUp / scaleDown -- stabilization window, policies (pods per minute cap).
- HPA `behavior.scaleDown.stabilizationWindowSeconds` (default 300s) prevents flapping after load drops.
- HPA and manual `kubectl scale` conflict; avoid setting replicas manually when HPA is active.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### HPA Metrics Requirements

- Resource metrics come from `metrics-server` (or adapter); pods need requests set so utilization = usage/request.
- Memory utilization: same idea; scaling on memory can be slower (GC, cache); often combine CPU + memory or use custom metrics.
- Custom metrics require an adapter (e.g. Prometheus adapter); pods metric (e.g. requests per second per pod) or object metric.
- HPA requires `metrics-server` for CPU/memory metrics; custom metrics need a separate adapter (e.g. Prometheus adapter).
- Pods must have resource requests set for HPA utilization-based scaling to work (utilization = usage / request).

### Pod Disruption Budget (PDB) Spec

- PDB limits voluntary disruptions so that at least `minAvailable` (number or percentage) or at most `maxUnavailable` pods of a selector are down at once.
- Voluntary = eviction by API (drain, cluster autoscaler scale-down); NOT involuntary (node failure, OOM).
- `minAvailable: 1` or `maxUnavailable: 1` for a Deployment with 3 replicas: drain/upgrade won't take down all at once; scheduler respects PDB when evicting.
- PDB only protects against voluntary disruptions (drain, API eviction); node crashes bypass PDB entirely.
- Use `minAvailable` OR `maxUnavailable` in a PDB, not both.
- Set PDB on every production Deployment to survive rolling node upgrades safely.

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: myapp-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: myapp
```

### Eviction and Drain

- `kubectl drain node`: cordon node and evict pods; respects PDB (evicts in order so PDB not violated); `--ignore-daemonsets`, `--force` (skip PDB, use with care).
- Voluntary eviction: API calls; involuntary: `kubelet` (OOM, disk pressure) or node lost; PDB does not protect against involuntary.
- Use PDB for critical apps so that during node drain (upgrade, scale-in) you don't lose all replicas.
- `kubectl drain --force` skips PDB checks -- use only as last resort.

Related notes: [003-deployments-rolling-update](./003-deployments-rolling-update.md), [008-resource-requests-limits](./008-resource-requests-limits.md)

---

# Troubleshooting Guide

### HPA not scaling
1. Check `metrics-server` is running: `kubectl get pods -n kube-system | grep metrics`.
2. Check HPA status: `kubectl describe hpa <name>` -- look at Conditions and current metrics.
3. Pods must have `requests` set for CPU/memory -- HPA calculates utilization as usage/request.
4. Check `kubectl top pods` returns data.

### HPA flapping (scaling up and down repeatedly)
1. Increase `stabilizationWindowSeconds` in behavior: prevents rapid scale-down.
2. Set scale-down policy: e.g. max 1 pod per 60s.
3. Check if metric is noisy -- consider using custom metric with smoothing.

### kubectl drain blocked by PDB
1. PDB prevents eviction to maintain minAvailable.
2. Check: `kubectl get pdb` -- verify current vs required.
3. Temporarily scale up the Deployment so drain can proceed, or use `--force` (skips PDB -- data loss risk).
