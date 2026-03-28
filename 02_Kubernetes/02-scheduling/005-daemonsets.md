# DaemonSets

# Overview

- **Why it exists** — Cluster infrastructure needs run on every node: log collectors need to read every node's `/var/log`, network plugins need to configure every node's networking stack, monitoring agents need to expose every node's metrics. You do not want to calculate replica counts manually — you want exactly one pod per node, automatically, as nodes come and go.
- **What it is** — A DaemonSet is a workload controller that ensures exactly one pod (matching the pod template) runs on every node (or every node matching a node selector/affinity). When a node joins the cluster, the DaemonSet controller creates a pod on it. When a node leaves, its DaemonSet pod is garbage-collected.
- **One-liner** — A DaemonSet runs exactly one pod per matching node — pod count tracks node count, not a replica field.

# Architecture

```text
DaemonSet "node-exporter"
  selector: app=node-exporter
        │
        ├── Node A  ──► node-exporter pod (auto-created when node joined)
        ├── Node B  ──► node-exporter pod
        ├── Node C  ──► node-exporter pod
        └── Node D  ──► node-exporter pod (created when node D joined)

  Node E joins cluster ──► DaemonSet controller creates pod on Node E automatically
  Node C removed       ──► DaemonSet pod on Node C is garbage-collected
```

# Mental Model

A DaemonSet replaces the mental model of "how many pods do I need?" with "every node is a slot." The controller continuously reconciles: for each node, is there exactly one pod from this DaemonSet? If not, create one. If a node is removed, delete the orphaned pod.

Unlike a Deployment, there is no `replicas` field. Scaling up means adding nodes; scaling down means removing nodes.

# Core Building Blocks

### DaemonSet spec

- **Why it exists** — Provides the template and targeting rules for which nodes get a daemon pod.
- **What it is** — Very similar to a Deployment spec, but without `replicas`. Key fields: `selector` (label selector for pod management), `template` (pod template), `updateStrategy`, and optionally `nodeSelector` / `affinity` / `tolerations` to narrow down which nodes receive a pod.
- **One-liner** — DaemonSet spec is a Deployment without `replicas`; pod count = matching node count.

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      tolerations:
      - operator: Exists    # run on ALL nodes including control-plane
      hostNetwork: true     # use node's network namespace (common for monitoring)
      containers:
      - name: node-exporter
        image: prom/node-exporter:latest
        ports:
        - containerPort: 9100
          hostPort: 9100
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
```

### Bypassing normal scheduling

- **Why it exists** — Normal pods go through the scheduler's filter/score/bind pipeline. DaemonSet pods have historically bypassed some of this.
- **What it is** — In modern Kubernetes (1.12+), DaemonSet pods do go through the scheduler, but the DaemonSet controller pre-sets `spec.nodeName` on the pod before submitting it — so the scheduler sees an already-assigned pod and just admits or rejects it based on resource fit. This means DaemonSet pods respect taints/tolerations and resource limits, but the scheduling target is determined by the controller, not by the scheduler's scoring.
- **One-liner** — The DaemonSet controller sets `nodeName` directly, so the scheduler validates but does not choose the node.

### Update strategy

- **Why it exists** — Updating a node-level daemon (e.g. a new version of fluentd) requires care — you don't want all log collectors restarting simultaneously.
- **What it is** — Two strategies:
- `RollingUpdate` (default): updates pods one node at a time; `maxUnavailable` controls how many pods can be down simultaneously (default: 1).
- `OnDelete`: pods are only updated when you manually delete them; gives full control over rollout timing.
- **One-liner** — `RollingUpdate` replaces DaemonSet pods one at a time; `OnDelete` waits for manual deletion.

```yaml
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1    # at most 1 node has its pod unavailable at a time
```

```bash
# Trigger an update by changing the image
kubectl set image daemonset/node-exporter node-exporter=prom/node-exporter:v1.7.0

# Watch rollout status
kubectl rollout status daemonset/node-exporter -n monitoring

# Rollback
kubectl rollout undo daemonset/node-exporter -n monitoring
```

### Tolerations for system nodes

**Why this matters** — Control-plane nodes have the taint `node-role.kubernetes.io/control-plane:NoSchedule`. Without a toleration, DaemonSet pods will not run there. Most infrastructure daemons need to run on control-plane too (e.g. calico, kube-proxy).
**What to do** — Add `operator: Exists` tolerations to the DaemonSet pod template to run on all nodes.

```yaml
tolerations:
- operator: Exists   # matches any taint; runs on ALL nodes including control-plane
```

### Limiting DaemonSet to a subset of nodes

Use `nodeSelector` or `nodeAffinity` to target only specific nodes (e.g. only GPU nodes for a GPU monitoring daemon):

```yaml
spec:
  template:
    spec:
      nodeSelector:
        hardware: gpu     # only nodes labeled hardware=gpu get this daemon pod
```

### Use cases

| Use Case | Example DaemonSet | What it mounts/does |
|----------|------------------|---------------------|
| Log collection | fluentd, filebeat | Mounts `/var/log`, ships logs to central store |
| Node monitoring | node-exporter, datadog-agent | Exposes node metrics via hostPort |
| Network plugin (CNI) | calico-node, cilium, weave | Configures iptables/eBPF on each node |
| Storage daemon | ceph-osd, glusterfs | Manages local disks per node |
| Intrusion detection | falco | Monitors syscalls via kernel module |
| kube-proxy | kube-proxy | Maintains iptables/ipvs rules for Services |

### Viewing DaemonSet pods

```bash
# List DaemonSets in kube-system (shows cluster infrastructure daemons)
kubectl get ds -n kube-system

# See which nodes each DaemonSet pod runs on
kubectl get pods -n kube-system -o wide | grep -E "calico|fluentd|kube-proxy"

# Describe a DaemonSet for full details
kubectl describe ds kube-proxy -n kube-system

# Check rollout history
kubectl rollout history daemonset/fluentd -n kube-system
```

### DaemonSet vs Deployment

| Aspect | Deployment | DaemonSet |
|--------|------------|-----------|
| Replicas | Explicit `replicas` field | One per matching node (no replicas field) |
| Scaling | Change `replicas` | Add/remove nodes |
| Pod placement | Scheduler decides | Controller sets `nodeName` per node |
| Use case | Stateless app instances | Node-level agents |
| Update | RollingUpdate with `maxSurge` | RollingUpdate with `maxUnavailable` or OnDelete |
| Namespace-scoped | Yes | Yes |

# Troubleshooting

### DaemonSet pod not appearing on a node
1. Check node taints: `kubectl describe node <name> | grep Taint` — add matching toleration.
2. Check DaemonSet `nodeSelector` or affinity: `kubectl get ds <name> -o yaml`.
3. Check node conditions: `kubectl describe node <name>` — `Ready: False` nodes still get DaemonSet pods but kubelet may not run them.
4. Check available resources: DaemonSet pods can fail to start if the node is resource-exhausted.

### DaemonSet rollout stuck
1. Check pod events: `kubectl describe pod <daemonset-pod> -n <ns>` for pull errors or crashes.
2. If `maxUnavailable: 1`, only one pod is replaced at a time — if that pod fails, rollout pauses.
3. Rollback: `kubectl rollout undo daemonset/<name>`.

### Accidentally running DaemonSet pods on control-plane
1. Remove the catch-all `operator: Exists` toleration.
2. Replace with specific tolerations only for needed system taints.
