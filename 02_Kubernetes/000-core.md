# Kubernetes

- Container orchestration platform that automates deployment, scaling, self-healing, and service discovery across a cluster of nodes.
- Declarative model: you define desired state (YAML manifests), controllers reconcile actual state to match.
- Key property: workloads are portable across any Kubernetes cluster (on-prem, cloud, hybrid).

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

Concrete example:
```bash
# Define desired state
kubectl apply -f deployment.yaml    # 3 replicas of nginx

# Kubernetes reconciles
# Scheduler assigns pods to nodes
# kubelet pulls image and starts containers
# If a pod dies, controller creates a new one

kubectl get pods -o wide            # see pods and their nodes
```

# Core Building Blocks

### Control Plane

- **kube-apiserver**: Front door for all operations; REST API; validates and persists to etcd.
- **etcd**: Distributed key-value store; single source of truth for cluster state.
- **kube-scheduler**: Watches unscheduled pods; assigns to nodes based on resources, affinity, taints.
- **kube-controller-manager**: Runs controllers (Deployment, ReplicaSet, Node, Endpoint, etc.); reconciles actual → desired state.

Related notes: [001-kubernetes-overview](./001-kubernetes-overview.md)

### Worker Node

- **kubelet**: Agent on each node; ensures containers in pods are running and healthy.
- **kube-proxy**: Maintains network rules (iptables/IPVS) for Service → Pod routing.
- **Container runtime**: Runs containers (containerd, CRI-O); communicates via CRI.

Related notes: [001-kubernetes-overview](./001-kubernetes-overview.md)

### Workloads

| Concept | What it is |
|---------|-----------|
| Pod | Smallest unit; one or more containers sharing network/storage |
| Deployment | Manages ReplicaSets; rolling updates, rollback |
| StatefulSet | Pods with stable identity and persistent storage |
| DaemonSet | One pod per node (logging, monitoring agents) |
| HPA | Auto-scale pods based on metrics (CPU, memory, custom) |

Related notes: [002-pods-labels](./002-pods-labels.md), [003-deployments-rolling-update](./003-deployments-rolling-update.md), [007-statefulset-daemonset](./007-statefulset-daemonset.md), [009-hpa-pod-disruption](./009-hpa-pod-disruption.md)

### Networking and Access

| Concept | What it is |
|---------|-----------|
| Service | Stable network endpoint to reach pods (ClusterIP, NodePort, LB) |
| Ingress | HTTP/HTTPS routing into cluster via domain names |
| Namespace | Virtual cluster for isolation (dev, prod, team-a) |

Related notes: [004-services-ingress](./004-services-ingress.md)

### Configuration

| Concept | What it is |
|---------|-----------|
| ConfigMap | Inject non-sensitive config into pods (env or volume) |
| Secret | Inject sensitive data into pods (base64, encrypt at rest) |

Related notes: [005-configmaps-secrets](./005-configmaps-secrets.md)

### Resource Management

- **requests**: Scheduler reserves capacity; **limits**: cap usage (CPU throttle, memory OOMKill).
- **ResourceQuota** and **LimitRange** govern namespace-level capacity.

Related notes: [008-resource-requests-limits](./008-resource-requests-limits.md)

---

# Troubleshooting Guide

### Pod stuck in Pending
1. Check events: `kubectl describe pod <name>` — look at Events section.
2. Insufficient resources: `kubectl describe node <node>` — check Allocatable vs Allocated.
3. No matching node (nodeSelector/affinity): verify labels on nodes `kubectl get nodes --show-labels`.
4. PVC not bound: `kubectl get pvc` — check status.

### Pod in CrashLoopBackOff
1. Check logs: `kubectl logs <pod>` and `kubectl logs <pod> --previous`.
2. Common causes: missing config/env, wrong command, dependency not ready.
3. Check exit code: `kubectl describe pod <pod>` — Last State → Exit Code.
4. Debug interactively: `kubectl run debug --image=busybox -it --rm -- sh`.

### ImagePullBackOff
1. Check image name/tag: typo or tag doesn't exist in registry.
2. Private registry: need `imagePullSecrets` on pod or ServiceAccount.
3. Network/proxy: node can't reach registry; check DNS and proxy config.

### Service not routing traffic to pods
1. Check selector matches pod labels: `kubectl get endpoints <svc>`.
2. If endpoints empty: labels don't match or pods aren't Ready.
3. Check readiness probe: failing probe removes pod from endpoints.
4. Check port: Service `targetPort` must match container's listening port.

### Node NotReady
1. Check node: `kubectl describe node <name>` — Conditions section.
2. Check kubelet: `systemctl status kubelet` on the node; `journalctl -u kubelet`.
3. Common: kubelet stopped, container runtime down, disk/memory pressure.

---

# Quick Facts (Revision)

- Kubernetes = control plane (API, scheduler, controllers, etcd) + worker nodes (kubelet, kube-proxy, runtime).
- Pod is the smallest deployable unit; Deployment manages pods via ReplicaSets.
- Service provides stable DNS/IP; ClusterIP (internal), NodePort (external port), LoadBalancer (cloud LB).
- Labels + selectors connect Deployments to pods, Services to pods, HPA to Deployments.
- Namespace isolates resources; ResourceQuota and LimitRange govern namespace capacity.
- Declarative: `kubectl apply -f` is idempotent; controllers reconcile continuously.
- ConfigMap for config, Secret for credentials; inject via env or volume mount.
- HPA scales by metrics; PDB protects against voluntary disruption during drain/upgrade.

# Topic Map (basic → advanced)

- [001-kubernetes-overview](./001-kubernetes-overview.md) — Cluster, pod, deployment, service, kubectl
- [002-pods-labels](./002-pods-labels.md) — Pod spec, labels, probes, lifecycle, resources
- [003-deployments-rolling-update](./003-deployments-rolling-update.md) — Deployment, ReplicaSet, rolling update, rollback
- [004-services-ingress](./004-services-ingress.md) — Service types, Ingress, DNS, endpoints
- [005-configmaps-secrets](./005-configmaps-secrets.md) — ConfigMap, Secret, env, volume mounts
- [006-kubectl-debugging](./006-kubectl-debugging.md) — get, describe, logs, exec, port-forward, debugging
- [007-statefulset-daemonset](./007-statefulset-daemonset.md) — StatefulSet, DaemonSet, volumeClaimTemplate
- [008-resource-requests-limits](./008-resource-requests-limits.md) — requests, limits, QoS, quota, LimitRange
- [009-hpa-pod-disruption](./009-hpa-pod-disruption.md) — HPA, PDB, scaling, eviction
- [010-rbac-service-accounts](./010-rbac-service-accounts.md) — RBAC, Roles, ClusterRoles, ServiceAccounts
- [011-storage-pv-pvc](./011-storage-pv-pvc.md) — PersistentVolume, PVC, StorageClass, dynamic provisioning
- [012-network-policies](./012-network-policies.md) — NetworkPolicy, ingress/egress rules, default deny, CNI
- [013-node-management](./013-node-management.md) — Taints, tolerations, affinity, cordon, drain
