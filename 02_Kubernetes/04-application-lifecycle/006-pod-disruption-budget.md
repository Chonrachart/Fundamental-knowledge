# Pod Disruption Budget

### Overview
- **Why it exists** — Node drains, cluster upgrades, and autoscaler scale-downs can evict pods simultaneously; without a PDB, all replicas of a Deployment could be evicted at once, causing a complete outage.
- **What it is** — A namespace-scoped policy object that tells Kubernetes the minimum number of pods (or maximum number of unavailable pods) that must be maintained during voluntary disruptions.
- **One-liner** — Guarantee minimum availability during planned maintenance by limiting how many pods can be evicted at once.

### Architecture (ASCII)

```text
3-replica Deployment with PDB minAvailable=2

Normal state:
  [Pod-1 Running] [Pod-2 Running] [Pod-3 Running]
                                    ↑ available = 3, minAvailable = 2 → OK to evict 1

kubectl drain node-A:
  Eviction #1: Pod-1 evicted → available = 2 → still >= 2 → ALLOWED
  Eviction #2: Pod-2 eviction attempt → available would = 1 → BLOCKED
                                         wait until Pod-1 replacement is Running
  Pod-1 replacement becomes Ready → available = 3 again → eviction #2 ALLOWED

End state: all pods evicted safely with at least 2 running at all times
```

### Mental Model

```text
PDB answers: "How many of my pods can be disrupted simultaneously?"

minAvailable: N  → at least N pods must be Running at all times
maxUnavailable: N → at most N pods can be down at any given moment

Both accept:
  - Absolute number: 2
  - Percentage:      "50%"  (rounded down for minAvailable, up for maxUnavailable)

Use ONE or the other — not both in the same PDB.
```

### Core Building Blocks

### Voluntary vs Involuntary Disruptions

**Why the distinction matters** — PDB only influences the voluntary path; involuntary disruptions bypass it entirely, so PDB is not a substitute for replication and proper backup strategies.

| Type | Examples | PDB applies? |
|---|---|---|
| **Voluntary** | `kubectl drain`, cluster autoscaler scale-down, rolling node OS upgrade, eviction via API | Yes — PDB blocks or slows eviction |
| **Involuntary** | Node hardware failure, kernel panic, out-of-memory node kill, network partition | No — pods are simply lost |

### minAvailable vs maxUnavailable

| Field | Meaning | Example (3 replicas) |
|---|---|---|
| `minAvailable: 2` | At least 2 pods must be Running | 1 can be evicted at a time |
| `minAvailable: "67%"` | At least 67% of pods must be Running | ceil(3*0.67)=2 → 1 can be evicted |
| `maxUnavailable: 1` | At most 1 pod can be down | 2 must always be Running |
| `maxUnavailable: "33%"` | At most 33% can be down | floor(3*0.33)=0 → 1 can be evicted |

Rule of thumb:
- Use `minAvailable` when you know the minimum safe count
- Use `maxUnavailable` when you want to express the maximum tolerable disruption as a fraction

### PDB YAML

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: myapp-pdb
  namespace: production
spec:
  minAvailable: 2           # use minAvailable OR maxUnavailable, not both
  selector:
    matchLabels:
      app: myapp
```

Alternative using `maxUnavailable`:

```yaml
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: myapp
```

Using a percentage (useful when replica count changes frequently):

```yaml
spec:
  minAvailable: "50%"
  selector:
    matchLabels:
      app: myapp
```

### Interaction with kubectl drain

`kubectl drain` calls the Kubernetes eviction API for each pod. The eviction API checks any matching PDB before proceeding:

```bash
kubectl drain node-1 --ignore-daemonsets --delete-emptydir-data
```

- If evicting a pod would violate the PDB, the eviction is **rejected** (HTTP 429)
- `kubectl drain` retries until the PDB allows it (e.g., a replacement pod becomes Ready)
- `kubectl drain --force` skips PDB checks — use only as a last resort (risk of outage)

```bash
kubectl get pdb                         # list all PDBs in current namespace
kubectl get pdb -n <namespace>          # list in specific namespace
kubectl describe pdb myapp-pdb          # detailed status including disruptions allowed
```

Sample `kubectl describe pdb` output:
```text
Name:           myapp-pdb
Namespace:      production
Min available:  2
Selector:       app=myapp
Status:
    Allowed disruptions:  1
    Current:              3
    Desired:              2
    Total:                3
```

`Allowed disruptions: 1` means one pod can currently be evicted without violating the budget.

### Best Practices

- Set a PDB on every production Deployment that has more than one replica
- Keep `minAvailable` at least 1 less than the total desired replicas so drains can proceed (a PDB of `minAvailable == replicas` blocks all evictions)
- Combine PDB with HPA: HPA can scale up during a drain so the PDB is satisfied faster
- Use percentages for Deployments whose replica count changes with HPA

### Troubleshooting

### kubectl drain blocked — "Cannot evict pod as it would violate the pod's disruption budget"
1. Check current disruption budget: `kubectl get pdb -n <namespace>` — look at `ALLOWED DISRUPTIONS`
2. If `Allowed disruptions: 0`, the Deployment may be below its desired count already
3. Temporarily scale up the Deployment so additional pods become Ready and the budget allows eviction
4. As a last resort: `kubectl drain --force` (skips PDB — potential brief outage)

### PDB selector matches no pods — always "0 allowed disruptions"
1. Verify selector labels: `kubectl get pods --show-labels` and compare to PDB `matchLabels`
2. Confirm PDB is in the same namespace as the pods
3. A PDB that matches 0 pods shows `Disruptions Allowed: 0` which blocks all drains on those nodes

### PDB not preventing evictions during node failure
1. Node failures are **involuntary disruptions** — PDB does not apply
2. Ensure sufficient replicas across multiple nodes / availability zones to survive node loss
3. Use pod anti-affinity rules to spread pods across nodes so a single node failure does not take down all replicas
