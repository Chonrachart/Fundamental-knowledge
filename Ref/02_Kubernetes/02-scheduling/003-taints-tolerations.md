# Taints and Tolerations

# Overview

- **Why it exists** — Nodes sometimes need to repel most pods: dedicated GPU nodes, nodes under memory pressure, or the control-plane node that should not run workloads. Taints let node operators mark a node as "off-limits" without modifying every pod that should stay away.
- **What it is** — A **taint** is a mark on a node with a key, an optional value, and an effect. A **toleration** on a pod is a declaration that the pod can tolerate (survive) a specific taint. Only pods with matching tolerations are permitted to schedule onto (or stay on) a tainted node.
- **One-liner** — Taints repel pods from nodes; tolerations on pods grant permission to land on tainted nodes.

# Architecture

```text
Node: node-gpu
  Taint: hardware=gpu:NoSchedule

Pod A (no tolerations)  ──X──► node-gpu   (rejected — no matching toleration)
Pod B (no tolerations)  ──X──► node-gpu   (rejected)
Pod C  tolerations:
         key: hardware
         value: gpu
         effect: NoSchedule    ──► node-gpu   (allowed)
```

# Mental Model

Think of a taint as a "no trespassing" sign on a node, and a toleration as a VIP pass on a pod. The sign says "go away unless you have this pass." The pass does not force the pod onto that node — it just removes the restriction. To actually force a pod onto a specific node you need node affinity (or `nodeName`).

Combined pattern: **taint + toleration + node affinity = dedicated nodes** (repel everyone else AND attract the right pods).

# Core Building Blocks

### Taint syntax

- **Why it exists** — Provides a structured, machine-parseable format for expressing what kind of repulsion a node imposes.
- **What it is** — A taint has three parts: `key=value:effect`. The value is optional (`key:effect` is valid). The key and value follow the same naming rules as label keys/values. The effect controls what happens to pods that do not tolerate the taint.
- **One-liner** — Taint format is `key=value:effect`; value is optional; effect determines severity.

```bash
# Add a taint
kubectl taint nodes node1 dedicated=gpu:NoSchedule

# Add a taint without a value
kubectl taint nodes node1 hardware:NoSchedule

# Remove a taint (append - suffix)
kubectl taint nodes node1 dedicated=gpu:NoSchedule-

# View taints on a node
kubectl describe node node1 | grep -A3 Taints
```

### Three effects

- **Why it exists** — Different situations require different levels of enforcement: prevent new scheduling, prefer to avoid, or actively evict existing pods.
- **What it is** — The effect field takes one of three values that control how strictly the taint is enforced.
- **One-liner** — NoSchedule is hard block; PreferNoSchedule is soft block; NoExecute also evicts running pods.

| Effect | New pods without toleration | Running pods without toleration |
|--------|-----------------------------|---------------------------------|
| `NoSchedule` | Not scheduled onto this node | Stay running (not evicted) |
| `PreferNoSchedule` | Scheduler avoids this node; may still land if no alternative | Stay running |
| `NoExecute` | Not scheduled | Evicted (unless toleration includes `tolerationSeconds`) |

### Toleration YAML

- **Why it exists** — Pods need a way to opt in to tainted nodes without being modified by the node operator.
- **What it is** — A list of toleration entries in `spec.tolerations`. Each entry must match a taint's key, operator, value, and effect. `operator: Equal` (default) requires a matching value. `operator: Exists` matches any taint with that key regardless of value. An empty key with `operator: Exists` matches ALL taints on any node — use with care.
- **One-liner** — `spec.tolerations` is the pod's list of taints it can survive; `operator: Exists` is the wildcard form.

```yaml
spec:
  tolerations:
  # Match taint dedicated=gpu:NoSchedule exactly
  - key: "dedicated"
    operator: "Equal"
    value: "gpu"
    effect: "NoSchedule"

  # Match any taint with key=hardware, any value
  - key: "hardware"
    operator: "Exists"
    effect: "NoSchedule"

  # NoExecute toleration with a time limit (pod evicted after 300s)
  - key: "node.kubernetes.io/not-ready"
    operator: "Exists"
    effect: "NoExecute"
    tolerationSeconds: 300

  # Match ALL taints on any node (dangerous — effectively no taint filtering)
  - operator: "Exists"
```

### NoExecute and tolerationSeconds

- **Why it exists** — When a node becomes unhealthy (e.g. memory pressure, disk pressure, unreachable), Kubernetes automatically adds `NoExecute` taints to the node. Pods can declare how long they tolerate this condition before being evicted.
- **What it is** — `tolerationSeconds` only applies to `NoExecute` tolerations. It tells the node controller: "evict this pod after N seconds if the taint is still present." Without `tolerationSeconds`, the pod tolerates the `NoExecute` taint indefinitely.
- **One-liner** — `tolerationSeconds` with `NoExecute` lets pods ride out transient node issues for a grace period before eviction.

```yaml
tolerations:
- key: "node.kubernetes.io/unreachable"
  operator: "Exists"
  effect: "NoExecute"
  tolerationSeconds: 60    # evict after 60 seconds of unreachability
```

### Built-in system taints (applied automatically by Kubernetes)

| Taint | When added | Purpose |
|-------|-----------|---------|
| `node.kubernetes.io/not-ready:NoExecute` | Node condition NotReady | Evict pods from failing node |
| `node.kubernetes.io/unreachable:NoExecute` | Node unreachable | Evict pods from unreachable node |
| `node.kubernetes.io/memory-pressure:NoSchedule` | Node memory low | Stop new pods; existing stay |
| `node.kubernetes.io/disk-pressure:NoSchedule` | Node disk low | Stop new pods |
| `node.kubernetes.io/unschedulable:NoSchedule` | Node cordoned | Stop new pods (cordon adds this) |
| `node-role.kubernetes.io/control-plane:NoSchedule` | Control-plane node | Protect master from workloads |

### Common use cases

| Use Case | Taint | Purpose |
|----------|-------|---------|
| GPU nodes | `hardware=gpu:NoSchedule` | Only GPU workloads land here |
| Control-plane protection | `node-role.kubernetes.io/control-plane:NoSchedule` | Prevent user workloads on master |
| Dedicated team node | `team=payments:NoSchedule` | Isolate node for one team |
| Node eviction on pressure | `node.kubernetes.io/memory-pressure:NoExecute` | Kubernetes-managed; evict pods |
| Spot/preemptible nodes | `cloud.google.com/gke-spot:NoSchedule` | Only spot-tolerant workloads |
