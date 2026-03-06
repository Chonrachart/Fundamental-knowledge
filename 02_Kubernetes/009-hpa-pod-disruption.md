HPA
Horizontal Pod Autoscaler
PDB
Pod Disruption Budget
metrics
scaling
voluntary disruption
eviction

---

# Horizontal Pod Autoscaler (HPA)

- **HPA** scales a Deployment/ReplicaSet/StatefulSet by **target metric** (e.g. CPU utilization, custom metric).
- **minReplicas**, **maxReplicas**: HPA adjusts current replicas within this range.
- **target**: e.g. **type: Utilization**, **averageUtilization: 70** (CPU); or **type: Value** for custom metric.
- **metrics**: **resource** (cpu, memory), **pods** (custom per-pod), **object** (metric describing another object); **external** (outside cluster).
- **Behavior** (optional): **scaleUp** / **scaleDown** — stabilization window, policies (pods per minute cap).

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

# CPU and Memory for HPA

- **resource** metrics come from **metrics-server** (or adapter); need **requests** set on pods so “utilization” = usage/request.
- **memory** utilization: same idea; scaling on memory can be slower (GC, cache); often combine CPU + memory or use custom metrics.
- **Custom metrics**: Require adapter (e.g. Prometheus adapter); **pods** metric (e.g. requests per second per pod) or **object** metric.

# Pod Disruption Budget (PDB)

- **PDB** limits **voluntary** disruptions so that at least **minAvailable** (number or percentage) or at most **maxUnavailable** pods of a selector are down at once.
- **Voluntary** = eviction by API (drain, cluster autoscaler scale-down); **not** involuntary (node failure, OOM).
- **minAvailable: 1** or **maxUnavailable: 1** for a Deployment with 3 replicas: drain/upgrade won’t take down all at once; scheduler respects PDB when evicting.

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

# Eviction and Drain

- **kubectl drain node**: Cordon node and evict pods; **respects PDB** (evicts in order so PDB not violated); **--ignore-daemonsets**, **--force** (skip PDB, use with care).
- **Voluntary** eviction: API calls; **involuntary**: kubelet (OOM, disk pressure) or node lost; PDB does not protect against involuntary.
- Use PDB for **critical** apps so that during **node drain** (upgrade, scale-in) you don’t lose all replicas.

# Summary

- **HPA**: Scale workload by CPU, memory, or custom metrics; set **requests** for resource-based HPA; tune **behavior** to avoid flapping.
- **PDB**: Protect against voluntary disruption; set **minAvailable** or **maxUnavailable** so upgrades/drains don’t take too many pods at once.
