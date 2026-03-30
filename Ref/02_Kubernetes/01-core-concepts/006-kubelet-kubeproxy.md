# kubelet and kube-proxy

# Overview

- **Why it exists** — Every worker node needs a local agent to run pods and route Service traffic; kubelet and kube-proxy fill those two roles.
- **What it is** — kubelet ensures containers described in PodSpecs are running and healthy; kube-proxy maintains network rules so Service IPs route to the right pods.
- **One-liner** — kubelet runs your pods; kube-proxy makes Services work.

# Architecture

```text
Worker Node
┌──────────────────────────────────────────────────────────┐
│                                                          │
│  kubelet (system process, NOT containerized)             │
│    │ watches PodSpecs assigned to this node              │
│    │ pulls images → starts containers via containerd     │
│    │ reports pod status back to API server               │
│    ▼                                                     │
│  ┌──────┐  ┌──────┐  ┌──────┐                           │
│  │ Pod  │  │ Pod  │  │ Pod  │   ← containers running    │
│  └──────┘  └──────┘  └──────┘                           │
│                                                          │
│  kube-proxy (runs as DaemonSet pod)                      │
│    │ watches Services and Endpoints via API server        │
│    │ maintains iptables/IPVS rules on this node          │
│    ▼                                                     │
│  iptables rules:                                         │
│    ClusterIP:80 → [pod1:8080, pod2:8080, pod3:8080]      │
│    (random selection = load balancing)                   │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

# Mental Model

```text
kubelet flow:
  API server writes nodeName=node1 to pod spec
          │
          ▼
  kubelet on node1 sees new PodSpec via watch
          │
          ▼
  kubelet pulls image (via containerd)
          │
          ▼
  kubelet creates container(s)
          │
          ▼
  kubelet runs liveness/readiness probes
          │
          ▼
  kubelet reports status (Running/Failed) back to API server

kube-proxy flow:
  Endpoint controller updates Endpoints for Service "web"
          │
          ▼
  kube-proxy watches Endpoints change
          │
          ▼
  kube-proxy updates iptables rules on this node
          │
          ▼
  Any pod on this node that connects to web:80
  gets redirected to one of the backend pod IPs
```

# Core Building Blocks

### kubelet

- **Why it exists** — Something on each node must be responsible for ensuring the containers described in PodSpecs are actually running and healthy — the control plane cannot do this remotely.
- **What it is** — A system-level agent (not a container itself) running on every worker node. It:
- Registers the node with the API server on startup
- Watches the API server for PodSpecs assigned to its node (`nodeName` = this node)
- Pulls container images via the container runtime interface (CRI) — e.g. containerd
- Creates and starts containers, sets up volumes and env vars
- Runs liveness, readiness, and startup probes; restarts containers on liveness failure
- Reports pod and node status back to the API server continuously (heartbeat)
- Manages static pods from `/etc/kubernetes/manifests/` (this is how control plane components run)

Key fact: **kubelet is NOT containerized itself**. It runs as a systemd service (`systemctl status kubelet`). This is necessary because kubelet manages the container runtime; it cannot be inside the thing it manages.

- **One-liner** — kubelet is the node agent that turns PodSpecs into running containers and keeps them healthy.

```bash
# Check kubelet status on a node
systemctl status kubelet
journalctl -u kubelet -n 100   # last 100 log lines

# See kubelet configuration
cat /var/lib/kubelet/config.yaml

# Static pod manifests (control plane components)
ls /etc/kubernetes/manifests/

# kubelet reports these back to API server
kubectl get node <name> -o yaml | grep -A20 "status:"
```

### kube-proxy

- **Why it exists** — Pods need to reach Services by their stable ClusterIP or DNS name, but the actual backend pods change IPs constantly (restarts, scaling). Something must translate Service IPs to current pod IPs at the network level.
- **What it is** — Runs as a DaemonSet pod on every node (so it IS containerized, unlike kubelet). Watches the API server for Service and Endpoints changes. Maintains network rules on each node that intercept traffic destined for a Service ClusterIP and redirect it to one of the healthy backend pod IPs. Supports two modes:
- **iptables mode** (default): uses iptables rules; random pod selection; efficient for most clusters
- **IPVS mode**: uses Linux IPVS (IP Virtual Server); more algorithms (round-robin, least-conn), better performance at scale

- **One-liner** — kube-proxy turns Service ClusterIPs into real pod IPs by managing iptables rules on every node.

```bash
# Check kube-proxy pods
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# Check kube-proxy mode
kubectl logs -n kube-system -l k8s-app=kube-proxy | grep "Using"

# View iptables rules kube-proxy creates (run on node)
iptables -t nat -L KUBE-SERVICES -n
iptables -t nat -L KUBE-SVC-<hash> -n   # rules for a specific service

# kube-proxy config
kubectl get configmap -n kube-system kube-proxy -o yaml
```

### Container Runtime Interface (CRI)

- **Why it exists** — kubelet needs to support multiple container runtimes without being rewritten for each.
- **What it is** — A standard gRPC API between kubelet and the container runtime. kubelet calls CRI methods (`RunPodSandbox`, `CreateContainer`, `StartContainer`) and the runtime implements them. Current default runtime is **containerd**; CRI-O is also common.
- **One-liner** — CRI is the plugin interface that lets kubelet work with any compliant container runtime.

```bash
# Check which runtime is in use
kubectl get node <name> -o jsonpath='{.status.nodeInfo.containerRuntimeVersion}'

# Interact with containerd directly on a node (when kubectl is unavailable)
crictl ps          # running containers
crictl pods        # running pod sandboxes
crictl logs <id>   # container logs
```
