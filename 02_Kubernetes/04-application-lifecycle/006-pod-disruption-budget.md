# Pod Disruption Budget

# Overview
- **Why it exists** — Node drains, cluster upgrades, and autoscaler scale-downs can evict pods simultaneously; without a PDB, all replicas of a Deployment could be evicted at once, causing a complete outage.
- **What it is** — A namespace-scoped policy object that tells Kubernetes the minimum number of pods (or maximum number of unavailable pods) that must be maintained during voluntary disruptions.
- **One-liner** — Guarantee minimum availability during planned maintenance by limiting how many pods can be evicted at once.

# Architecture

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

# Mental Model

```text
PDB answers: "How many of my pods can be disrupted simultaneously?"

minAvailable: N  → at least N pods must be Running at all times
maxUnavailable: N → at most N pods can be down at any given moment

Both accept:
  - Absolute number: 2
  - Percentage:      "50%"  (rounded down for minAvailable, up for maxUnavailable)

Use ONE or the other — not both in the same PDB.
```

# Core Building Blocks

### Voluntary vs Involuntary Disruptions

- **Why it exists** — PDB only influences the voluntary path; involuntary disruptions bypass it entirely, so understanding the distinction prevents false confidence that a PDB protects against all failure modes.
- **What it is** — A classification of pod removal events into voluntary (operator- or controller-initiated, checked against PDB) and involuntary (hardware/kernel failures, not checked against PDB).
- **One-liner** — PDB guards against planned evictions only; node failures bypass it entirely.

**Why the distinction matters** — PDB only influences the voluntary path; involuntary disruptions bypass it entirely, so PDB is not a substitute for replication and proper backup strategies.

| Type | Examples | PDB applies? |
|---|---|---|
| **Voluntary** | `kubectl drain`, cluster autoscaler scale-down, rolling node OS upgrade, eviction via API | Yes — PDB blocks or slows eviction |
| **Involuntary** | Node hardware failure, kernel panic, out-of-memory node kill, network partition | No — pods are simply lost |

### minAvailable vs maxUnavailable

- **Why it exists** — Two complementary ways to express the same availability constraint let you phrase it in whichever direction is more natural for your mental model of the workload.
- **What it is** — The two mutually exclusive PDB fields: `minAvailable` sets the floor of running pods; `maxUnavailable` sets the ceiling of down pods. Both accept absolute integers or percentage strings.
- **One-liner** — Use `minAvailable` to state the safe floor, or `maxUnavailable` to state the tolerable disruption ceiling — never both.

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

- **Why it exists** — A concrete manifest shows the minimal required fields and all three valid constraint expressions (`minAvailable` integer, `maxUnavailable` integer, `minAvailable` percentage) in one place.
- **What it is** — Example `PodDisruptionBudget` manifests using `policy/v1` with a label selector targeting a Deployment's pods.
- **One-liner** — Minimal PDB manifests covering the three common constraint forms.

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

- **Why it exists** — `kubectl drain` is the most common trigger of voluntary disruptions; understanding exactly how it calls the eviction API and respects PDB ensures operators know what to expect during node maintenance.
- **What it is** — The sequence by which `kubectl drain` calls the eviction API per pod, how the API enforces the PDB (HTTP 429 on violation), and how drain retries until the budget allows each eviction.
- **One-liner** — `kubectl drain` retries evictions until the PDB allows them; `--force` bypasses the budget entirely.

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

- **Why it exists** — Common configuration mistakes (setting `minAvailable == replicas`, forgetting percentages with HPA, skipping PDB for single-replica workloads) cause drains to block indefinitely or provide no protection; these guidelines prevent them.
- **What it is** — A set of actionable recommendations for configuring PDBs correctly in production across common scenarios.
- **One-liner** — Guidelines to ensure PDBs protect availability without inadvertently blocking all maintenance operations.

- Set a PDB on every production Deployment that has more than one replica
- Keep `minAvailable` at least 1 less than the total desired replicas so drains can proceed (a PDB of `minAvailable == replicas` blocks all evictions)
- Combine PDB with HPA: HPA can scale up during a drain so the PDB is satisfied faster
- Use percentages for Deployments whose replica count changes with HPA
