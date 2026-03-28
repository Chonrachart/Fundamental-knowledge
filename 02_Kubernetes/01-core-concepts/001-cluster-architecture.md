# Cluster Architecture

# Overview

- **Why it exists** — Running containers at scale across many machines requires automated scheduling, self-healing, and configuration management that cannot be done by hand.
- **What it is** — Kubernetes is a container orchestration platform with a control plane that makes decisions and worker nodes that run workloads. You declare desired state in YAML; Kubernetes continuously reconciles actual state to match.
- **One-liner** — Kubernetes is a declarative system where you describe what you want and controllers make it happen across a cluster of nodes.

# Architecture

```text
┌──────────────────────────────────────────────────────────────┐
│                      Control Plane                           │
│                                                              │
│  ┌────────────┐  ┌───────────┐  ┌──────────────────────────┐ │
│  │ API Server │  │ Scheduler │  │ Controller Manager       │ │
│  │ (kube-api) │  │           │  │ (deployment, replicaset, │ │
│  │            │  │ assigns   │  │  node, endpoint, etc.)   │ │
│  │ front door │  │ pods to   │  └──────────────────────────┘ │
│  │ for all    │  │ nodes     │                               │
│  │ operations │  └───────────┘  ┌──────────────────────────┐ │
│  └─────┬──────┘                 │ etcd                     │ │
│        │                        │ (cluster state store)    │ │
│        │                        └──────────────────────────┘ │
└────────┼─────────────────────────────────────────────────────┘
         │
    ┌────┴──────────────────────────────────────────────────┐
    │                   Worker Nodes                        │
    │                                                       │
    │  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  │
    │  │   Node 1    │  │   Node 2    │  │   Node 3     │  │
    │  │             │  │             │  │              │  │
    │  │ kubelet     │  │ kubelet     │  │ kubelet      │  │
    │  │ kube-proxy  │  │ kube-proxy  │  │ kube-proxy   │  │
    │  │ containerd  │  │ containerd  │  │ containerd   │  │
    │  │             │  │             │  │              │  │
    │  │ ┌───┐ ┌───┐│  │ ┌───┐ ┌───┐│  │ ┌───┐       │  │
    │  │ │Pod│ │Pod││  │ │Pod│ │Pod││  │ │Pod│       │  │
    │  │ └───┘ └───┘│  │ └───┘ └───┘│  │ └───┘       │  │
    │  └─────────────┘  └─────────────┘  └──────────────┘  │
    └───────────────────────────────────────────────────────┘
```

# Mental Model

```text
User writes YAML  ──apply──▶  API Server  ──store──▶  etcd
                                  │
                          ┌───────┴───────┐
                          ▼               ▼
                     Scheduler      Controllers
                     (place pod)    (reconcile state)
                          │               │
                          ▼               ▼
                     kubelet on node runs the pod
```

`kubectl apply` flow step by step:
1. `kubectl` sends HTTP request to API server (port 6443)
2. API server authenticates, authorizes (RBAC), validates the object
3. API server persists the object to etcd
4. Scheduler watches etcd (via API server) for pods with no `nodeName` assigned, picks a node, writes `nodeName` back
5. kubelet on the chosen node sees the PodSpec, pulls the image, starts containers via containerd
6. Controller Manager watches for drift — if a pod dies, the ReplicaSet controller creates a replacement

# Core Building Blocks

### API Server

- **Why it exists** — Every component in the cluster needs a single source of truth and a single entry point for reads and writes.
- **What it is** — The front door for all cluster operations; validates and authenticates requests, authorizes via RBAC, and persists objects to etcd. It is the only component that reads/writes etcd directly. Exposes a REST API on port 6443 (HTTPS).
- **One-liner** — The API server is the gatekeeper and message bus for the entire cluster.

```bash
# Health check
curl -k https://<control-plane-ip>:6443/healthz

# List API versions
kubectl api-versions

# See raw API call kubectl is making
kubectl get pods -v=8
```

### etcd

- **Why it exists** — Cluster state (every object, every config) must be stored durably and consistently across control plane replicas.
- **What it is** — A distributed key-value store using the Raft consensus algorithm. Stores all Kubernetes objects. Only the API server communicates with etcd directly. Losing etcd without a backup means losing the entire cluster state.
- **One-liner** — etcd is the brain of the cluster; everything Kubernetes knows lives here.

### Scheduler

- **Why it exists** — Pods need to be placed on nodes that have sufficient resources and meet constraints.
- **What it is** — Watches for pods with no `nodeName` set, scores candidate nodes by available resources, affinity rules, and taints/tolerations, then writes the chosen `nodeName` back to the pod via the API server.
- **One-liner** — The scheduler decides which node each pod lands on.

### Controller Manager

- **Why it exists** — Desired state must be continuously reconciled against actual state without human intervention.
- **What it is** — Runs many control loops in a single process (Deployment controller, ReplicaSet controller, Node controller, Endpoint controller, etc.). Each loop watches objects and takes corrective action when actual state drifts from desired state.
- **One-liner** — The controller manager is the automation engine that keeps the cluster in its desired state.

### kubelet

- **Why it exists** — Something on each node must be responsible for starting and monitoring the containers described in PodSpecs.
- **What it is** — An agent running on every worker node. Watches PodSpecs assigned to its node (via API server), pulls container images, starts containers through the container runtime (containerd), and reports pod status back. kubelet itself is NOT containerized — it runs as a system process.
- **One-liner** — kubelet is the node-level agent that runs and monitors pods.

### kube-proxy

- **Why it exists** — Pods must be able to reach Services by ClusterIP/DNS without knowing the current pod IPs behind them.
- **What it is** — Runs on every node and maintains iptables (or IPVS) rules that redirect Service IP traffic to actual pod IPs. When a pod changes (scaled up/down, restarted), kube-proxy updates the rules automatically.
- **One-liner** — kube-proxy is the network rules engine that makes Services work on each node.

### Container Runtime

- **Why it exists** — Kubernetes needs a standard interface to pull images and manage container lifecycles across different runtimes.
- **What it is** — The software that actually runs containers (e.g. `containerd`, `CRI-O`). kubelet talks to it via the Container Runtime Interface (CRI). Docker was historically used but is no longer directly supported.
- **One-liner** — The container runtime is the low-level engine that starts and stops containers on a node.

# Troubleshooting

### Cannot connect to cluster

1. Check kubeconfig: `kubectl config view` — verify server URL, context, credentials.
2. Check context: `kubectl config current-context` — switch with `kubectl config use-context <name>`.
3. Check API server reachable: `curl -k https://<api-server>:6443/healthz`.
4. If on control plane node: `systemctl status kube-apiserver`.

### Node shows NotReady

1. `kubectl describe node <name>` — check Conditions section.
2. SSH to node: `systemctl status kubelet` — look for errors.
3. Check container runtime: `systemctl status containerd`.
4. Check disk/memory pressure — kubelet reports these as node conditions.

### Pod stuck in Pending after apply

1. `kubectl describe pod <name>` — check Events section for scheduler messages.
2. Common: insufficient CPU/memory on all nodes, no nodes match affinity, all nodes tainted.
3. `kubectl get nodes` — verify nodes are Ready and not cordoned.
