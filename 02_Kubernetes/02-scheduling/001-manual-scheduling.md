# Manual Scheduling

### Overview

**Why it exists** — Sometimes you need to pin a pod to a specific node without relying on the scheduler — for testing, debugging, or placing a workload on hardware you know it must run on.
**What it is** — Setting `spec.nodeName` in the pod spec tells the kubelet on that node to run the pod directly; the kube-scheduler sees the field is already set and skips the pod entirely.
**One-liner** — Setting `spec.nodeName` bypasses the scheduler and pins a pod directly to a named node.

### Architecture (ASCII diagram)

```text
Normal scheduling path:
  Pod (no nodeName) ──► kube-scheduler ──► scores nodes ──► sets nodeName ──► kubelet starts pod

Manual scheduling path:
  Pod (nodeName: node01) ──────────────────────────────────► kubelet starts pod
                               (scheduler skipped entirely)
```

### Mental Model

Think of `nodeName` as a sticky note you put on the pod before it enters the queue. The scheduler looks at each pod, checks whether `nodeName` is already set, and if so, moves on. The kubelet on the named node polls the API server for pods assigned to it and picks up the pod directly.

If you need to change the node assignment of an already-running pod, you cannot edit `nodeName` in-place. You must delete the pod and recreate it with the new value, or use a Binding object (advanced).

### Core Building Blocks

### nodeName field

**Why it exists** — Provides an escape hatch from the scheduler for cases where you must control placement exactly.
**What it is** — A string field in `spec` that holds the name of the node the pod should run on. When set, the scheduler skips the pod, and the kubelet on the named node picks it up. It is the lowest-level scheduling mechanism — no filtering, no scoring, no resource checks enforced by the scheduler (the kubelet will still enforce local resource limits).
**One-liner** — The `nodeName` field is the simplest, most direct way to assign a pod to a node.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pinned
spec:
  nodeName: node01          # scheduler skipped; kubelet on node01 picks this up
  containers:
  - name: nginx
    image: nginx:alpine
```

**What happens if the node does not exist or has no capacity:**
- If the node name does not exist in the cluster, the pod stays in `Pending` indefinitely — the kubelet that would claim it is not there.
- If the node exists but has insufficient CPU/memory, the kubelet will still attempt to start the pod but may fail with an `OutOfMemory` or `OutOfCPU` error. The scheduler's resource-fit filter does not run when `nodeName` is already set.

### Binding Object (advanced — already-running pods)

**Why it exists** — The Binding API is what the scheduler itself uses internally to assign a node to a pod. You can POST a Binding object directly to assign a node to a pod that is already `Pending` without deleting and recreating it.
**What it is** — A `Binding` resource (under `v1`) that maps a pod name to a node name. Posting it to the API server has the same effect as the scheduler setting `nodeName`.
**One-liner** — A Binding object is the API-level equivalent of the scheduler's final bind step, usable directly for already-pending pods.

```yaml
apiVersion: v1
kind: Binding
metadata:
  name: nginx-pinned
target:
  apiVersion: v1
  kind: Node
  name: node01
```

```bash
# POST the binding (must be JSON, sent to the pod's binding subresource)
curl -X POST \
  http://<api-server>/api/v1/namespaces/default/pods/nginx-pinned/binding \
  -H "Content-Type: application/json" \
  -d '{"apiVersion":"v1","kind":"Binding","metadata":{"name":"nginx-pinned"},"target":{"apiVersion":"v1","kind":"Node","name":"node01"}}'
```

### Verifying placement

```bash
# -o wide shows the NODE column
kubectl get pod nginx-pinned -o wide

# Describe gives full scheduling details
kubectl describe pod nginx-pinned | grep Node:

# Watch all pods and their nodes
kubectl get pods -o wide --all-namespaces
```

### Troubleshooting

### Pod stuck in Pending after setting nodeName
1. Verify the node name is correct: `kubectl get nodes` — names are case-sensitive.
2. Check node conditions: `kubectl describe node <node01>` — look for `Ready: False` or taints.
3. Check pod events: `kubectl describe pod <name>` — the kubelet on the target node logs the reason.
4. If the node is cordoned (`SchedulingDisabled`), manually-scheduled pods with `nodeName` are still accepted by the kubelet (cordon only blocks the scheduler).

### Need to move a manually-scheduled pod to a different node
1. You cannot edit `nodeName` on a running pod in-place (`nodeName` is immutable after creation for most controllers).
2. Delete the pod and recreate it with the new `nodeName`.
3. If managed by a Deployment/ReplicaSet, the controller will reschedule normally — remove the `nodeName` from the pod template so the scheduler takes over.
