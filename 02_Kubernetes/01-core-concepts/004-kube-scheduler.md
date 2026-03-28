# kube-scheduler

## Overview

**Why it exists** — When a pod is created, it has no node assigned. Something must decide which node is the best fit given resource availability, constraints, and policies.
**What it is** — A control plane component that watches for pods with no `nodeName` set, filters nodes that meet the pod's requirements, scores the remaining nodes, and writes the winning `nodeName` back to the pod via the API server. It does not start the pod — kubelet does that once `nodeName` is set.
**One-liner** — The scheduler finds the best node for each unplaced pod and assigns it.

## Architecture

```text
                    ┌─────────────────────────────────┐
                    │          API Server              │
                    └───────┬──────────────┬───────────┘
                            │              │
                     watch  │              │ write nodeName
                     (pods  │              │
                     with no│              │
                     nodeName)             │
                            ▼              │
                    ┌───────────────┐      │
                    │  Scheduler    │──────┘
                    │               │
                    │  1. Filter    │  Remove nodes that don't qualify
                    │  2. Score     │  Rank remaining nodes
                    │  3. Bind      │  Write nodeName to pod
                    └───────────────┘

Scheduling cycle for one pod:
  All nodes ──[Filter]──► Feasible nodes ──[Score]──► Ranked nodes ──► Best node
```

## Mental Model

```text
Pod created (no nodeName):
        │
        ▼
Scheduler picks it up from API server watch
        │
        ▼
Filter phase — discard nodes that cannot run the pod:
  - Not enough CPU/memory (requests vs allocatable)
  - NodeSelector doesn't match
  - Required toleration missing for node taint
  - Pod affinity/anti-affinity rules violated
  - Port conflicts
        │
        ▼
Score phase — rank remaining nodes (0-100 per plugin):
  - Least-requested (spread load)
  - Node affinity preference
  - Image locality (node already has image = faster start)
  - Topology spread constraints
        │
        ▼
Bind — scheduler writes nodeName to pod via API server
        │
        ▼
kubelet on chosen node sees the pod → starts containers
```

## Core Building Blocks

### Filter Plugins (Predicates)

**Why it exists** — Not every node can run every pod; impossible placements must be eliminated first.
**What it is** — A set of checks run against each node. A node passes only if ALL filters pass. Common filters:
- `NodeResourcesFit`: node has enough allocatable CPU and memory for pod's requests
- `NodeSelector`: pod's `nodeSelector` labels match node labels
- `TaintToleration`: pod has tolerations for all node taints
- `PodAffinity`: inter-pod affinity/anti-affinity rules are satisfied
- `NodeAffinity`: pod's `nodeAffinity` rules match node labels
**One-liner** — Filters shrink the candidate set to only nodes that can physically host the pod.

### Score Plugins (Priorities)

**Why it exists** — Among feasible nodes, the scheduler should choose the most appropriate one (e.g. balance load, prefer locality).
**What it is** — Each scoring plugin gives each feasible node a score 0-100. Scores are weighted and summed. The node with the highest total score wins. Example plugins:
- `LeastAllocated`: prefer nodes with more free resources (spread load)
- `NodeAffinity`: bonus for nodes that match preferred affinity rules
- `ImageLocality`: bonus if node already has the container image cached
**One-liner** — Scores rank feasible nodes so the scheduler picks the best one, not just any valid one.

### Node Affinity and NodeSelector

**Why it exists** — Some pods should run on specific hardware (GPU nodes, SSD nodes, specific regions).
**What it is** — Two mechanisms to constrain pod placement by node labels:
- `nodeSelector`: simple map of required label key-values (filter only)
- `nodeAffinity`: more expressive rules with required (filter) and preferred (score) sections

```yaml
spec:
  nodeSelector:
    disktype: ssd

  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: topology.kubernetes.io/zone
            operator: In
            values: [us-east-1a, us-east-1b]
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
          - key: disktype
            operator: In
            values: [ssd]
```

### Taints and Tolerations (Scheduling Impact)

**Why it exists** — Some nodes should repel most pods unless the pod explicitly opts in (e.g. dedicated GPU nodes, control-plane nodes).
**What it is** — A node taint marks it as unsuitable for general pods. A pod toleration is the pod's opt-in. The scheduler's `TaintToleration` filter rejects nodes whose taints the pod doesn't tolerate.
**One-liner** — Taints repel pods; tolerations are the pods' permission to land on tainted nodes.

```bash
# Add taint to node
kubectl taint nodes node1 gpu=true:NoSchedule

# Pod that tolerates it
# spec.tolerations:
# - key: "gpu"
#   operator: "Equal"
#   value: "true"
#   effect: "NoSchedule"
```

### Checking Scheduling Decisions

```bash
# See scheduling events for a pod
kubectl describe pod <name>
# Look at the "Events" section at the bottom:
# Normal   Scheduled  <time>  default-scheduler  Successfully assigned default/<pod> to node2

# See which node a pod landed on
kubectl get pod <name> -o wide

# See pending pods (scheduler hasn't placed them yet)
kubectl get pods --field-selector=status.phase=Pending

# See scheduler logs (control plane)
kubectl logs -n kube-system -l component=kube-scheduler
```

## Troubleshooting

### Pod stays in Pending — 0/N nodes are available

1. `kubectl describe pod <name>` — Events section shows the exact filter reason.
2. Common messages:
   - `Insufficient cpu` / `Insufficient memory` — no node has enough capacity for pod's requests
   - `node(s) didn't match Pod's node affinity/selector` — nodeSelector or nodeAffinity mismatch
   - `node(s) had untolerated taint` — pod missing toleration for tainted node
3. Check node capacity: `kubectl describe nodes | grep -A5 "Allocated resources"`.
4. Check node labels: `kubectl get nodes --show-labels`.

### Pod placed on unexpected node

1. Review pod's `nodeSelector`, `nodeAffinity`, and `tolerations`.
2. Check if topology spread constraints or pod anti-affinity are configured.
3. Use `kubectl get pod -o wide` to confirm placement, then `kubectl describe node <node>` to see its labels and taints.

### Scheduler not running

1. `kubectl get pods -n kube-system -l component=kube-scheduler` — check it's Running.
2. Check scheduler config: `cat /etc/kubernetes/manifests/kube-scheduler.yaml` on control plane.
3. All new pods stay Pending indefinitely when scheduler is down; existing pods continue running.
