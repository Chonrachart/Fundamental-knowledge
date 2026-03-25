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

- API server, etcd, scheduler, controller-manager — detailed in [001-kubernetes-overview](./001-kubernetes-overview.md).
- Declarative: `kubectl apply -f` is idempotent; controllers reconcile continuously.

### Worker Node

- kubelet, kube-proxy, container runtime — detailed in [001-kubernetes-overview](./001-kubernetes-overview.md).

### Workloads

| Concept | What it is |
|---------|-----------|
| Pod | Smallest unit; one or more containers sharing network/storage |
| Deployment | Manages ReplicaSets; rolling updates, rollback |
| StatefulSet | Pods with stable identity and persistent storage |
| DaemonSet | One pod per node (logging, monitoring agents) |
| HPA | Auto-scale pods based on metrics (CPU, memory, custom) |

- Pod is the smallest deployable unit; Deployment manages pods via ReplicaSets.
- Labels + selectors connect Deployments to pods, Services to pods, HPA to Deployments.
- HPA scales by metrics; PDB protects against voluntary disruption during drain/upgrade.

Related notes: [002-pods-labels](./002-pods-labels.md), [003-deployments-rolling-update](./003-deployments-rolling-update.md), [007-statefulset-daemonset](./007-statefulset-daemonset.md), [009-hpa-pod-disruption](./009-hpa-pod-disruption.md)

### Networking and Access

| Concept | What it is |
|---------|-----------|
| Service | Stable network endpoint to reach pods (ClusterIP, NodePort, LB) |
| Ingress | HTTP/HTTPS routing into cluster via domain names |
| Namespace | Virtual cluster for isolation (dev, prod, team-a) |

- Service provides stable DNS/IP; ClusterIP (internal), NodePort (external port), LoadBalancer (cloud LB).

Related notes: [004-services-ingress](./004-services-ingress.md)

### Configuration

| Concept | What it is |
|---------|-----------|
| ConfigMap | Inject non-sensitive config into pods (env or volume) |
| Secret | Inject sensitive data into pods (base64, encrypt at rest) |

- ConfigMap for config, Secret for credentials; inject via env or volume mount.

Related notes: [005-configmaps-secrets](./005-configmaps-secrets.md)

### Resource Management

- **requests**: Scheduler reserves capacity; **limits**: cap usage (CPU throttle, memory OOMKill).
- **ResourceQuota** and **LimitRange** govern namespace-level capacity.
- Namespace isolates resources; ResourceQuota and LimitRange govern namespace capacity.

Related notes: [008-resource-requests-limits](./008-resource-requests-limits.md)

---

# Troubleshooting Guide

### Pod stuck in Pending
For Pod Pending troubleshooting, see [006-kubectl-debugging](./006-kubectl-debugging.md).

### Pod in CrashLoopBackOff
For CrashLoopBackOff troubleshooting, see [006-kubectl-debugging](./006-kubectl-debugging.md).

### ImagePullBackOff
For ImagePullBackOff troubleshooting, see [006-kubectl-debugging](./006-kubectl-debugging.md).

### Service not routing traffic to pods
For Service routing troubleshooting, see [004-services-ingress](./004-services-ingress.md).

### Node NotReady
For Node NotReady troubleshooting, see [006-kubectl-debugging](./006-kubectl-debugging.md).

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
- [014-cert-manager](./014-cert-manager.md) — TLS certificate automation, Issuers, ACME, Ingress integration
