# Node Affinity

### Overview

**Why it exists** — `nodeSelector` is too blunt for many real-world requirements: "schedule on nodes in zone us-east-1a OR us-east-1b, preferring nodes with SSD storage." Node affinity provides expressive, multi-operator rules that attract pods to nodes based on node labels, while still allowing soft (preferred) rules that do not block scheduling.
**What it is** — Node affinity is a set of rules in `spec.affinity.nodeAffinity` that the scheduler evaluates when placing a pod. Rules can be hard (required) or soft (preferred), and use rich operators (In, NotIn, Exists, DoesNotExist, Gt, Lt) against node labels.
**One-liner** — Node affinity attracts pods to nodes that match label expressions — more expressive than nodeSelector, with hard and soft rule types.

### Architecture (ASCII diagram)

```text
Scheduler pipeline for a pod with node affinity:

All nodes in cluster
        │
        ▼
  Filter phase (hard rules)
  requiredDuringScheduling...
  ├── node must match ALL nodeSelectorTerms entries
  └── nodes that fail are eliminated
        │
        ▼
  Score phase (soft rules)
  preferredDuringScheduling...
  ├── each matching preference adds weight to node score
  └── higher-weighted nodes are preferred but not required
        │
        ▼
  Bind to highest-scoring node that passed the filter
```

### Mental Model

Think of node affinity in two layers:
- **required** = hard filter (if no node matches, pod stays Pending)
- **preferred** = hint to the scorer (pod lands somewhere even if no node matches the preference)

A common pattern is: use `required` to enforce zone or hardware constraints, and `preferred` to express "SSD storage would be nice but don't block on it."

Contrast with taints/tolerations: taints **push** pods away from nodes (node's choice). Node affinity **pulls** pods toward nodes (pod's choice). For dedicated nodes, you often need both: taint to repel unwanted pods AND affinity to attract desired pods.

### Core Building Blocks

### nodeSelector (simpler alternative)

**Why it exists** — The simplest scheduling constraint; no YAML nesting required. Fine for basic cases.
**What it is** — A map of key-value pairs in `spec.nodeSelector`. The pod only schedules on nodes that have ALL the listed labels with exact matching values. No operators, no OR, no preferences. Functionally equivalent to a single required node affinity with `In` operators.
**One-liner** — `nodeSelector` is a flat key=value map for simple node targeting — no operators or preferences.

```yaml
spec:
  nodeSelector:
    disktype: ssd
    kubernetes.io/arch: amd64
```

```bash
# Label a node first
kubectl label nodes node1 disktype=ssd
kubectl label nodes node1 kubernetes.io/arch=amd64
```

### requiredDuringSchedulingIgnoredDuringExecution

**Why it exists** — Some constraints are non-negotiable: a GPU workload cannot run on a CPU-only node; a compliance-sensitive workload must stay in a specific region.
**What it is** — The hard form of node affinity. The pod will not be scheduled if no node satisfies the rule. The "IgnoredDuringExecution" part means if a node's labels change after a pod is already running, the pod is NOT evicted — the rule is only checked at schedule time. Multiple `nodeSelectorTerms` entries are ORed; multiple `matchExpressions` within a term are ANDed.
**One-liner** — `required...` is the hard filter: pod stays Pending if no matching node exists; only evaluated at schedule time.

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:                          # AND within a term
          - key: topology.kubernetes.io/zone
            operator: In
            values: ["us-east-1a", "us-east-1b"]    # OR within values
          - key: kubernetes.io/arch
            operator: In
            values: ["amd64"]
        - matchExpressions:                          # OR between terms
          - key: disktype
            operator: In
            values: ["nvme"]
```

### preferredDuringSchedulingIgnoredDuringExecution

**Why it exists** — Not all scheduling preferences should block a pod from running. "Prefer zone A but schedule anywhere" is a common production pattern.
**What it is** — The soft form of node affinity. Each entry has a `weight` (1-100) and a preference expression. The scheduler adds the weight to the score of nodes that match. The pod always schedules even if no node matches the preference. Multiple preferences accumulate — a node matching more preferences scores higher.
**One-liner** — `preferred...` adds weight to matching nodes' scores — pod always schedules, even with zero matches.

```yaml
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 80                    # higher weight = stronger preference
        preference:
          matchExpressions:
          - key: disktype
            operator: In
            values: ["ssd"]
      - weight: 20
        preference:
          matchExpressions:
          - key: topology.kubernetes.io/zone
            operator: In
            values: ["us-east-1a"]
```

### Required vs Preferred comparison

| Aspect | requiredDuringScheduling... | preferredDuringScheduling... |
|--------|----------------------------|------------------------------|
| Effect | Hard filter — pod stays Pending if no match | Soft hint — always schedules |
| No match behavior | Pod unschedulable | Pod schedules on any node |
| Phase | Filter | Score |
| Multi-term logic | Terms are ORed; expressions within a term are ANDed | Each preference adds weight independently |
| Use for | Hard constraints (zone, hardware) | Soft preferences (SSD, proximity) |

### Operator types

| Operator | Meaning | Example |
|----------|---------|---------|
| `In` | Label value is in the list | `zone In [us-east-1a, us-east-1b]` |
| `NotIn` | Label value is NOT in the list | `env NotIn [dev, test]` |
| `Exists` | Key exists (any value) | `disktype Exists` |
| `DoesNotExist` | Key does NOT exist | `deprecated DoesNotExist` |
| `Gt` | Label value (integer) is greater than | `cpuCount Gt 4` |
| `Lt` | Label value (integer) is less than | `latency Lt 10` |

### Combined example: required + preferred

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/os
            operator: In
            values: ["linux"]
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: disktype
            operator: In
            values: ["ssd"]
```

### Taints + Tolerations vs Node Affinity

These two mechanisms solve complementary problems and are often used together.

| Aspect | Taints + Tolerations | Node Affinity |
|--------|---------------------|---------------|
| Direction | Node pushes pods away (node's choice) | Pod is attracted to nodes (pod's choice) |
| Default behavior | Pod excluded unless it tolerates taint | Pod can schedule anywhere unless rule blocks |
| Hard/Soft | Effect: NoSchedule (hard), PreferNoSchedule (soft), NoExecute (evict) | required (hard), preferred (soft) |
| Can guarantee placement? | No — toleration allows but doesn't force | required+nodeName needed for that |
| Typical use | Dedicate nodes, protect control-plane, handle node pressure | Zone/arch constraints, hardware preferences |
| Combined use | Taint to repel all others + affinity to attract desired pods | Same — both needed for dedicated nodes |

### Troubleshooting

### Pod stuck in Pending — "0/3 nodes are available: ... node(s) didn't match Pod's node affinity"
1. Check the node affinity rules: `kubectl get pod <name> -o yaml | grep -A20 nodeAffinity`.
2. Check node labels: `kubectl get nodes --show-labels`.
3. If using `required`, no node currently has the required labels — either label a node or relax to `preferred`.
4. Check for typos: label keys and values are case-sensitive.

### Pod scheduled on wrong node despite affinity
1. `preferred` affinity is a hint, not a guarantee — if the preferred node is full, the pod lands elsewhere.
2. Use `required` if placement is non-negotiable.
3. Check node scores: `kubectl get events --field-selector reason=Scheduled` for placement details.

### Node labels changed but pods still running there
1. This is by design — "IgnoredDuringExecution" means running pods are not re-evaluated.
2. A future type (`requiredDuringSchedulingRequiredDuringExecution`) would evict on label change, but it is not yet GA.
3. To force re-scheduling: delete pods so they reschedule under the new rules.
