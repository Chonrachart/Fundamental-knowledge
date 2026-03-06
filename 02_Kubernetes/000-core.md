overview of

    Kubernetes
    cluster
    pod
    deployment
    service

---

# Kubernetes

- Orchestration platform for containerized workloads.
- Manages deployment, scaling, healing, and discovery across a cluster.

# Cluster

- Set of nodes (machines) running container workloads.
- Control plane (API server, scheduler, etcd) + worker nodes (run pods).

# Pod

- Smallest deployable unit; one or more containers sharing network and storage.
- Ephemeral; use controllers (Deployment, StatefulSet) to manage pods.

# Deployment

- Declarative way to manage ReplicaSets and pods; rolling updates, rollback.

# Service

- Stable network endpoint to reach pods (cluster IP, NodePort, LoadBalancer).

# Control Plane

- **API server**: Front for cluster; all clients and components talk to it.
- **etcd**: Key-value store; cluster state.
- **Scheduler**: Assigns pods to nodes.
- **Controller manager**: Reconciles state (e.g. Deployment → ReplicaSet → Pods).

# Worker Node

- **kubelet**: Runs on each node; ensures containers in pods are running.
- **kube-proxy**: Network rules for Services (e.g. cluster IP → pod IPs).
- **Container runtime**: Runs containers (containerd, CRI-O).

# Namespace

- Virtual cluster; isolate resources (e.g. dev, prod, team-a).
- `kubectl get ns`; most resources are namespaced; some (Node, PV) are cluster-scoped.

# Topic Map (basic → advanced)

- [001-kubernetes-overview](./001-kubernetes-overview.md) — Cluster, pod, deployment, service (start here)
- [002-pods-labels](./002-pods-labels.md) — Pod spec, labels, probes, lifecycle
- [003-deployments-rolling-update](./003-deployments-rolling-update.md) — Deployment, ReplicaSet, rolling update, rollback
- [004-services-ingress](./004-services-ingress.md) — Service types, Ingress, DNS
- [005-configmaps-secrets](./005-configmaps-secrets.md) — ConfigMap, Secret, env, mounts
- [006-kubectl-debugging](./006-kubectl-debugging.md) — get, describe, logs, exec, port-forward, debugging
- [007-statefulset-daemonset](./007-statefulset-daemonset.md) — StatefulSet, DaemonSet, volumeClaimTemplate
- [008-resource-requests-limits](./008-resource-requests-limits.md) — requests, limits, QoS, quota, LimitRange
- [009-hpa-pod-disruption](./009-hpa-pod-disruption.md) — HPA, PDB, scaling, eviction
