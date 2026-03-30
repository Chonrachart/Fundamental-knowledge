# Kubernetes

# Overview

- **Why it exists** — Running containers at scale across many machines requires automated scheduling, self-healing, service discovery, and configuration management that cannot be done by hand.
- **What it is** — Kubernetes is a container orchestration platform with a control plane that makes decisions and worker nodes that run workloads. You declare desired state in YAML; Kubernetes continuously reconciles actual state to match.
- **One-liner** — Kubernetes is a declarative system where you describe what you want and controllers make it happen across a cluster of nodes.

# Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                        Control Plane                        │
│                                                             │
│  ┌─────────────┐  ┌──────────┐  ┌──────────────────────┐  │
│  │ kube-       │  │  etcd    │  │  kube-controller-    │  │
│  │ apiserver   │  │ (state)  │  │  manager             │  │
│  └──────┬──────┘  └──────────┘  └──────────────────────┘  │
│         │                                                   │
│  ┌──────┴──────┐                                           │
│  │ kube-       │                                           │
│  │ scheduler   │                                           │
│  └─────────────┘                                           │
└──────────────────────────┬──────────────────────────────────┘
                           │ API
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│  Worker Node  │  │  Worker Node  │  │  Worker Node  │
│  ┌─────────┐  │  │  ┌─────────┐  │  │  ┌─────────┐  │
│  │ kubelet │  │  │  │ kubelet │  │  │  │ kubelet │  │
│  │kube-    │  │  │  │kube-    │  │  │  │kube-    │  │
│  │proxy    │  │  │  │proxy    │  │  │  │proxy    │  │
│  │Pods...  │  │  │  │Pods...  │  │  │  │Pods...  │  │
│  └─────────┘  │  │  └─────────┘  │  │  └─────────┘  │
└───────────────┘  └───────────────┘  └───────────────┘
```

# Mental Model

```text
You write YAML (desired state)
       │
       ▼
kube-apiserver (stores in etcd)
       │
       ▼
Controllers watch state → reconcile actual vs desired
       │
       ▼
kube-scheduler assigns Pods to Nodes
       │
       ▼
kubelet on Node pulls image → starts container
```

- Every Kubernetes resource is a declaration of desired state stored in etcd.
- Controllers run in a continuous loop comparing actual state to desired state and acting to close the gap.
- You never tell Kubernetes how to do things — you tell it what you want.

# Core Building Blocks

### Control Plane

- **Why it exists** — Someone needs to make global decisions about scheduling, state tracking, and self-healing across the entire cluster.
- **What it is** — Set of components (apiserver, etcd, scheduler, controller-manager) that manage cluster state and drive reconciliation.
- **One-liner** — The brain of the cluster; stores state and makes decisions.

### Worker Node

- **Why it exists** — Pods need physical machines to run on; nodes provide compute, networking, and storage to workloads.
- **What it is** — A machine (VM or physical) running kubelet and kube-proxy that executes the Pods assigned by the scheduler.
- **One-liner** — The muscle of the cluster; runs workloads.

### Pod

- **Why it exists** — Containers that share a network and storage need a co-scheduling unit; Kubernetes uses Pod as the smallest deployable unit.
- **What it is** — One or more containers sharing a network namespace and lifecycle, scheduled together on the same node.
- **One-liner** — The smallest deployable unit in Kubernetes; one or more containers running together.

### Controller

- **Why it exists** — Desired state must be continuously enforced; controllers watch and react so humans don't have to.
- **What it is** — A control loop that watches resources and takes actions to reconcile actual state to desired state (e.g. Deployment controller, ReplicaSet controller).
- **One-liner** — A watch loop that makes actual state match desired state.

### Topic Map

- [01-core-concepts/001-cluster-architecture](./01-core-concepts/001-cluster-architecture.md) — Control plane, worker nodes, component overview
- [01-core-concepts/002-etcd](./01-core-concepts/002-etcd.md) — Cluster state store
- [01-core-concepts/003-kube-apiserver](./01-core-concepts/003-kube-apiserver.md) — API gateway for all cluster operations
- [01-core-concepts/004-kube-scheduler](./01-core-concepts/004-kube-scheduler.md) — Pod-to-node assignment
- [01-core-concepts/005-controller-manager](./01-core-concepts/005-controller-manager.md) — Reconciliation controllers
- [01-core-concepts/006-kubelet-kubeproxy](./01-core-concepts/006-kubelet-kubeproxy.md) — Node agents
- [01-core-concepts/007-pods](./01-core-concepts/007-pods.md) — Pod lifecycle, probes, init containers
- [01-core-concepts/008-replicasets-deployments](./01-core-concepts/008-replicasets-deployments.md) — Scaling and rolling updates
- [01-core-concepts/009-services](./01-core-concepts/009-services.md) — Service types and networking
- [01-core-concepts/010-namespaces](./01-core-concepts/010-namespaces.md) — Namespace isolation
- [01-core-concepts/011-imperative-vs-declarative](./01-core-concepts/011-imperative-vs-declarative.md) — kubectl usage patterns
- [01-core-concepts/012-statefulsets](./01-core-concepts/012-statefulsets.md) — Stateful workloads
- [02-scheduling/001-manual-scheduling](./02-scheduling/001-manual-scheduling.md) — nodeName and manual placement
- [02-scheduling/002-labels-selectors](./02-scheduling/002-labels-selectors.md) — Labels, selectors, annotations
- [02-scheduling/003-taints-tolerations](./02-scheduling/003-taints-tolerations.md) — Node taints and Pod tolerations
- [02-scheduling/004-node-affinity](./02-scheduling/004-node-affinity.md) — Node affinity and anti-affinity
- [02-scheduling/005-daemonsets](./02-scheduling/005-daemonsets.md) — Per-node Pods
- [02-scheduling/006-static-pods](./02-scheduling/006-static-pods.md) — kubelet-managed Pods
- [02-scheduling/007-admission-controllers](./02-scheduling/007-admission-controllers.md) — API request validation and mutation
- [03-logging-monitoring/001-managing-logs](./03-logging-monitoring/001-managing-logs.md) — kubectl logs, sidecar patterns, log aggregation
- [04-application-lifecycle/001-rolling-updates-rollback](./04-application-lifecycle/001-rolling-updates-rollback.md) — Deployment strategies
- [04-application-lifecycle/002-configmaps-secrets](./04-application-lifecycle/002-configmaps-secrets.md) — Configuration and secrets injection
- [04-application-lifecycle/003-multi-container-pods](./04-application-lifecycle/003-multi-container-pods.md) — Sidecar, init, ambassador patterns
- [04-application-lifecycle/004-resource-requests-limits](./04-application-lifecycle/004-resource-requests-limits.md) — CPU/memory management
- [04-application-lifecycle/005-hpa-vpa-autoscaling](./04-application-lifecycle/005-hpa-vpa-autoscaling.md) — Horizontal and vertical autoscaling
- [04-application-lifecycle/006-pod-disruption-budget](./04-application-lifecycle/006-pod-disruption-budget.md) — Availability during disruptions
- [05-cluster-maintenance/001-os-upgrades](./05-cluster-maintenance/001-os-upgrades.md) — Node drain and cordon
- [05-cluster-maintenance/002-cluster-upgrade-kubeadm](./05-cluster-maintenance/002-cluster-upgrade-kubeadm.md) — kubeadm upgrade workflow
- [05-cluster-maintenance/003-etcd-backup-restore](./05-cluster-maintenance/003-etcd-backup-restore.md) — etcd snapshot and restore
- [06-security/001-tls-basics](./06-security/001-tls-basics.md) — TLS in Kubernetes
- [06-security/002-certificates-api-kubeconfig](./06-security/002-certificates-api-kubeconfig.md) — Certificates API and kubeconfig
- [06-security/003-rbac](./06-security/003-rbac.md) — Role-based access control
- [06-security/004-network-policies](./06-security/004-network-policies.md) — Pod-level network segmentation
- [06-security/005-security-contexts](./06-security/005-security-contexts.md) — Pod and container security settings
- [07-storage/001-volumes](./07-storage/001-volumes.md) — Volume types
- [07-storage/002-persistent-volumes-pvc](./07-storage/002-persistent-volumes-pvc.md) — PV, PVC, and StorageClass
- [07-storage/003-storage-class](./07-storage/003-storage-class.md) — Dynamic provisioning
- [08-networking/001-network-namespaces](./08-networking/001-network-namespaces.md) — Linux network namespaces
- [08-networking/002-cni](./08-networking/002-cni.md) — Container Network Interface
- [08-networking/003-pod-service-networking](./08-networking/003-pod-service-networking.md) — Pod IPs and Service ClusterIP
- [08-networking/004-dns-coredns](./08-networking/004-dns-coredns.md) — CoreDNS and in-cluster DNS
- [08-networking/005-ingress-gateway-api](./08-networking/005-ingress-gateway-api.md) — Ingress and Gateway API
- [09-troubleshooting/000-kubectl-debugging](./09-troubleshooting/000-kubectl-debugging.md) — kubectl debugging commands
- [09-troubleshooting/001-application-failure](./09-troubleshooting/001-application-failure.md) — Pod/Deployment failures
- [09-troubleshooting/002-control-plane-failure](./09-troubleshooting/002-control-plane-failure.md) — Control plane debugging
- [09-troubleshooting/003-worker-node-failure](./09-troubleshooting/003-worker-node-failure.md) — Node failures
- [10-helm/001-helm-basics](./10-helm/001-helm-basics.md) — Helm overview and commands
- [10-helm/002-helm-charts](./10-helm/002-helm-charts.md) — Chart structure and templating
- [11-kustomize/001-kustomize-basics](./11-kustomize/001-kustomize-basics.md) — Kustomize overview
- [11-kustomize/002-overlays-patches](./11-kustomize/002-overlays-patches.md) — Overlays and patch strategies
- [work-specific/cert-manager](./work-specific/cert-manager.md) — cert-manager for TLS automation
