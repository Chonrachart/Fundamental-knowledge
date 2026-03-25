# Node Management: Taints, Affinity, and Drain

- Taints and tolerations control which pods can be scheduled on which nodes; taints repel, tolerations allow.
- Node affinity and pod affinity/anti-affinity provide fine-grained scheduling rules based on labels.
- Cordon and drain safely remove a node from service for maintenance without losing workloads.

# Architecture

```text
New Pod arrives at Scheduler
    │
    ▼
1. Filter (hard constraints):
   ├── nodeSelector labels match?
   ├── node affinity required rules match?
   ├── taints tolerated?
   ├── enough CPU/memory?
   └── node cordoned? → reject
    │
    ▼
2. Score (soft preferences):
   ├── preferred node affinity   (+weight)
   ├── pod anti-affinity spread  (+weight)
   └── resource balance          (+weight)
    │
    ▼
3. Bind to highest-scoring node
    │
    ▼
kubelet starts pod on chosen node
```

# Mental Model

```text
Scheduler decides where to place a pod:

1. Filter nodes:
   nodeSelector     → must have these labels
   node affinity    → must/prefer these label rules
   taints           → reject pods without matching toleration
   resource fit     → enough CPU/memory

2. Score remaining nodes:
   preferred affinity  → higher score
   pod anti-affinity   → spread across nodes
   resource balance    → even distribution

3. Bind pod to highest-scoring node
```

Example:
```bash
# Taint a node (no new pods unless they tolerate it)
kubectl taint nodes node1 dedicated=gpu:NoSchedule

# Cordon (no new pods, existing stay)
kubectl cordon node2

# Drain (evict pods, then cordon)
kubectl drain node2 --ignore-daemonsets --delete-emptydir-data
```

# Core Building Blocks

### Taints and Tolerations

- **Taint** on a node: `key=value:effect`; effects: `NoSchedule`, `PreferNoSchedule`, `NoExecute`.
- **Toleration** on a pod: matches a taint to allow scheduling on that node.
- `NoExecute` evicts existing pods that don't tolerate the taint.

```bash
# Add taint
kubectl taint nodes node1 dedicated=gpu:NoSchedule

# Remove taint
kubectl taint nodes node1 dedicated=gpu:NoSchedule-
```

```yaml
# Pod toleration
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "gpu"
    effect: "NoSchedule"
```

| Effect | New pods without toleration | Existing pods without toleration |
|--------|---------------------------|--------------------------------|
| NoSchedule | Not scheduled | Stay |
| PreferNoSchedule | Avoid if possible | Stay |
| NoExecute | Not scheduled | Evicted |

### nodeSelector

- Simplest scheduling constraint: pod only runs on nodes with matching labels.
- Node labels: `kubectl label nodes node1 disktype=ssd`.

```yaml
spec:
  nodeSelector:
    disktype: ssd
```

### Node Affinity

- More expressive than nodeSelector; supports `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt`.
- **requiredDuringSchedulingIgnoredDuringExecution**: Hard rule (must match).
- **preferredDuringSchedulingIgnoredDuringExecution**: Soft rule (prefer but don't block).

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: topology.kubernetes.io/zone
            operator: In
            values: ["us-east-1a", "us-east-1b"]
```

### Pod Affinity and Anti-Affinity

- **podAffinity**: Schedule near pods with matching labels (same node/zone).
- **podAntiAffinity**: Schedule away from pods with matching labels (spread across nodes/zones).
- `topologyKey`: Defines "near" — `kubernetes.io/hostname` (same node), `topology.kubernetes.io/zone` (same zone).

```yaml
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: web
        topologyKey: kubernetes.io/hostname
```

### Cordon, Uncordon, and Drain

```bash
# Cordon: mark node unschedulable (existing pods stay)
kubectl cordon node1

# Uncordon: mark node schedulable again
kubectl uncordon node1

# Drain: evict pods then cordon
kubectl drain node1 --ignore-daemonsets --delete-emptydir-data

# Drain with grace period
kubectl drain node1 --ignore-daemonsets --grace-period=60
```

- `--ignore-daemonsets`: Required (DaemonSet pods can't be evicted).
- `--delete-emptydir-data`: Required if pods use emptyDir volumes.
- Drain respects PDB (PodDisruptionBudget) — won't evict if it would violate PDB.

Related notes: [002-pods-labels](./002-pods-labels.md), [009-hpa-pod-disruption](./009-hpa-pod-disruption.md)

- `IgnoredDuringExecution` means affinity rules are checked at schedule time but not enforced after.
- Toleration with `operator: Exists` and empty key matches any taint — use with caution.
---

# Troubleshooting Guide

### Pod not scheduling — "no nodes match"
1. Check taints: `kubectl describe node <name> | grep Taint`.
2. Check pod tolerations: `kubectl get pod <name> -o yaml | grep -A5 tolerations`.
3. Check nodeSelector / affinity: does any node have the required labels?
4. Check resources: `kubectl describe node <name>` — is there enough CPU/memory?

### Drain stuck — pods not evicting
1. Check PDB: `kubectl get pdb -A` — drain won't violate PDB.
2. Pod with no controller (bare pod): drain skips it; use `--force` to delete.
3. DaemonSet pods: use `--ignore-daemonsets`.
4. Local storage: use `--delete-emptydir-data`.

### Node taint not repelling pods
1. Check taint syntax: `kubectl describe node <name> | grep Taint`.
2. Check pod tolerations: a toleration with `operator: Exists` and no key matches ALL taints.
3. `PreferNoSchedule` is a soft rule — pods may still land there if no better node exists.
