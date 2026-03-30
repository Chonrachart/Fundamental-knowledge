# Cluster Upgrade with kubeadm

# Overview

- **Why it exists** — Kubernetes releases security patches and new features on a regular cadence. Running an outdated cluster exposes workloads to known CVEs and prevents access to newer API versions. kubeadm provides a structured, reproducible path for upgrading cluster components without re-provisioning nodes.
- **What it is** — A two-phase process: first upgrade the control plane (API server, controller-manager, scheduler, etcd), then upgrade each worker node one at a time. kubeadm handles the ordering and component config regeneration; you manage the OS-level package installation.
- **One-liner** — kubeadm upgrades the control plane first, then workers are drained, upgraded, and uncordoned one at a time.

# Architecture

```text
Upgrade order (MUST follow this sequence):

  1. Control plane node
     ├─ apt install kubeadm=1.X.Y
     ├─ kubeadm upgrade plan       ← shows what will change
     ├─ kubeadm upgrade apply v1.X.Y  ← upgrades API server, controller-manager, scheduler, etcd
     └─ apt install kubelet=1.X.Y kubectl=1.X.Y + restart kubelet

  2. Worker nodes (one at a time)
     ├─ kubectl drain <worker>     ← from control plane
     ├─ apt install kubeadm=1.X.Y  ← on the worker node
     ├─ kubeadm upgrade node       ← updates worker node config
     ├─ apt install kubelet=1.X.Y  ← on the worker node
     ├─ systemctl restart kubelet  ← on the worker node
     └─ kubectl uncordon <worker>  ← from control plane
```

# Mental Model

Think of the cluster upgrade like upgrading a relay race team: the lead runner (control plane) upgrades first and sets the new pace. The rest of the runners (workers) upgrade one at a time so the race (workloads) never fully stops. The version skew policy is the rule that says no runner can be more than one version behind the leader — fall too far behind and the team cannot coordinate.

The key insight: `kubeadm upgrade apply` only touches control plane static pod manifests. It does not restart worker kubelets or reschedule pods — you must drain and restart each worker separately.

# Core Building Blocks

### Version skew policy

- **Why it exists** — Kubernetes components communicate via APIs that change between versions. If components are too far apart in version, API incompatibilities cause subtle failures.
- **What it is** — The supported skew rules:

| Component pair | Max skew |
|---------------|----------|
| kube-apiserver vs kube-controller-manager | ±1 minor version |
| kube-apiserver vs kube-scheduler | ±1 minor version |
| kube-apiserver vs kubelet | ±2 minor versions |
| kube-apiserver vs kubectl | ±1 minor version |

- **One-liner** — Control plane must be upgraded before workers; no component should be more than 1 minor version behind the API server.

### Checking current versions

- **Why it exists** — Before planning or executing an upgrade, you need to know the current versions of all components to determine what upgrade path is available and what skew constraints apply.
- **What it is** — A set of CLI commands that query the running cluster and local binaries to report their current versions.
- **One-liner** — Run these commands to see what version each component is running before planning an upgrade.

```bash
# Kubernetes server and client version
kubectl version

# kubeadm version
kubeadm version

# All node versions (SERVER VERSION column = kubelet version)
kubectl get nodes

# Which upgrade is available
kubeadm upgrade plan
```

### Control plane upgrade

- **Why it exists** — The API server is the single point of truth for the cluster; upgrading it first ensures all newer API resources are available before workers switch over.
- **What it is** — Install the new kubeadm binary, run `upgrade plan` to preview changes, then `upgrade apply` to replace static pod manifests under `/etc/kubernetes/manifests/`. Then upgrade kubelet and kubectl on the same node.
- **One-liner** — `kubeadm upgrade apply` rewrites control plane manifests; then kubelet is upgraded and restarted.

```bash
# On control plane node
apt-get update && apt-get install -y kubeadm=1.X.Y-*
kubeadm upgrade plan              # shows available upgrades
kubeadm upgrade apply v1.X.Y      # upgrades control plane components

apt-get install -y kubelet=1.X.Y-* kubectl=1.X.Y-*
systemctl daemon-reload && systemctl restart kubelet
```

### Worker node upgrade

- **Why it exists** — Worker kubelets run pods; they must be updated to match the new API server. Draining first ensures in-flight workloads are not interrupted by a mid-request kubelet restart.
- **What it is** — For each worker: drain from the control plane, install new kubeadm + run `kubeadm upgrade node` (syncs the node's kubeadm config), install new kubelet, restart, then uncordon.
- **One-liner** — Drain → upgrade kubeadm → `kubeadm upgrade node` → upgrade kubelet → restart → uncordon.

```bash
# On control plane — drain worker
kubectl drain <worker> --ignore-daemonsets --delete-emptydir-data

# On worker node
apt-get update && apt-get install -y kubeadm=1.X.Y-*
kubeadm upgrade node              # syncs node config with new control plane version
apt-get install -y kubelet=1.X.Y-* kubectl=1.X.Y-*
systemctl daemon-reload && systemctl restart kubelet

# On control plane — return to service
kubectl uncordon <worker>

# Verify node shows the new version
kubectl get nodes
```

### Verifying upgrade success

```bash
# All nodes should show the new version under VERSION column
kubectl get nodes

# Confirm control plane pods are running the new image version
kubectl get pods -n kube-system

# Sanity check — API server is responsive
kubectl cluster-info

# Confirm kubectl is at the right version
kubectl version --short
```

### One minor version at a time rule

| Scenario | Valid? |
|----------|--------|
| 1.27 → 1.28 | Yes — one minor version |
| 1.27 → 1.29 | No — must go 1.27 → 1.28 → 1.29 |
| 1.28.0 → 1.28.5 | Yes — patch version bump only |
