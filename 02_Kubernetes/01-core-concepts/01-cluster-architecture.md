# Cluster Architecture

# Overview
- **Why it exists** — running containers at scale 
- **What it is** — Kubernetes is a container orchestration platform with a control plane that makes decisions and worker nodes that run workloads. You declare desired state in YAML; Kubernetes continuously reconciles actual state to match.
- **One-liner** — Kubernetes is a declarative system where you describe what you want and controllers make it happen across a cluster of nodes.

# Architecture

![kubernetes-Architecture](../pic/kubernetes-architecture.png)

# Core Building Blocks

### API Server
- **Why it exists** — Every component in the cluster needs a single source of truth and a single entry point for reads and writes.
- **What it is** —The front door for all cluster operations; validates and authenticates requests, authorizes via RBAC, and persists objects to etcd. It is the only component that reads/writes etcd directly.
- **One-liner** — he API server is the gatekeeper — everything goes through it, nothing bypasses it.


```bash
curl -k https://<control-plane-ip>:6443/healthz     # Health check
kubectl api-versions                                # List API versions
```
### etcd
- **Why it exists** — Cluster state (every object, every config) must be stored durably and consistently across control plane replicas.
- **What it is** — A distributed key-value store that holds all Kubernetes objects. Only the API server communicates with etcd directly. Losing etcd without a backup means losing the entire cluster state.
- **One-liner** — etcd is the brain of the cluster; everything Kubernetes knows lives here.

### Scheduler
- **Why it exists** — Pods need to be placed on nodes that have sufficient resources and meet constraints.
- **What it is** — Watches for pods with no `nodeName` set, scores candidate nodes by available resources and more, then writes the chosen `nodeName` back to the pod via the API server.
- **One-liner** — The scheduler decides which node each pod lands on.

### Controller Manager
- **Why it exists** — Desired state must be continuously reconciled against actual state
- **What it is** — Runs many control loops in a single process (Deployment controller, ReplicaSet controller, Node controller, Endpoint controller, etc.). Each loop watches objects and takes corrective action when actual state drifts from desired state.
- **One-liner** — The controller manager is the automation engine that keeps the cluster in its desired state.


### kubelet
- **Why it exists** —
- **What it is** —
- **One-liner** —

### kube-proxy
- **Why it exists** —
- **What it is** —
- **One-liner** —

### Container Runtime
- **Why it exists** —
- **What it is** —
- **One-liner** —
