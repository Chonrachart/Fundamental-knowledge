# Static Pods

# Overview

- **Why it exists** — The Kubernetes control-plane itself (API server, etcd, controller-manager, scheduler) needs to start somewhere before any of those components are running. Static pods let the kubelet bootstrap these critical components directly from files on disk, without depending on the API server.
- **What it is** — A static pod is a pod whose definition lives as a YAML/JSON file in a directory on the node's filesystem (default: `/etc/kubernetes/manifests/`). The kubelet watches that directory and creates, updates, or deletes pods as files appear, change, or disappear — entirely without communicating with the API server.
- **One-liner** — Static pods are kubelet-managed pods defined by files in `/etc/kubernetes/manifests/` — used to bootstrap the control plane before the API server exists.

# Architecture

```text
Control-plane node filesystem:
  /etc/kubernetes/manifests/
    ├── etcd.yaml               ─┐
    ├── kube-apiserver.yaml      │  kubelet watches this directory
    ├── kube-controller-manager.yaml │  directly (inotify)
    └── kube-scheduler.yaml     ─┘
              │
              ▼
         kubelet creates pods locally
              │
              ▼ (once API server is up)
         API server shows "mirror pods" (read-only copies)
              │
         kube-system namespace:
           etcd-controlplane
           kube-apiserver-controlplane
           kube-controller-manager-controlplane
           kube-scheduler-controlplane
                    ↑
           Name ends with node name (e.g. "-controlplane")
```

# Mental Model

Normal pods: user creates pod manifest → API server stores it → scheduler assigns it → kubelet on the assigned node creates the container.

Static pods: kubelet reads manifest file from disk → creates the container directly on that node → no API server, no scheduler, no etcd involved.

The kubelet acts as a mini-control-plane for static pods. It also watches the pods it creates and restarts them if they crash — the same way it does for regular pods.

Once the API server is running, the kubelet registers "mirror pods" — read-only API objects that represent the static pods. You can see them with `kubectl`, but you cannot delete them via kubectl (deleting the mirror pod just recreates it; you must delete the file from disk).

# Core Building Blocks

### How static pods work

- **Why it exists** — Bootstrapping: kubeadm uses static pods to install `etcd`, `kube-apiserver`, `kube-controller-manager`, and `kube-scheduler` before any of those services are available to schedule workloads.
- **What it is** — The kubelet's `--pod-manifest-path` flag (or `staticPodPath` in the kubelet config) points to a directory. The kubelet uses inotify to watch that directory. Any valid pod spec file dropped there is immediately created. Changes to the file cause the kubelet to recreate the pod. Deleting the file causes the kubelet to stop and remove the pod.
- **One-liner** — Drop a pod YAML into `/etc/kubernetes/manifests/` and the kubelet creates it immediately; remove the file to delete the pod.

```bash
# Default manifests directory on most clusters (set in kubelet config)
ls /etc/kubernetes/manifests/

# Check kubelet config for the staticPodPath
cat /var/lib/kubelet/config.yaml | grep staticPodPath

# Or find it in kubelet flags
ps aux | grep kubelet | grep -o 'pod-manifest-path=[^ ]*'
```

### Adding a static pod

```bash
# Drop a pod spec into the manifests directory on the target node
cat > /etc/kubernetes/manifests/my-static-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: my-static-pod
  namespace: default
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
EOF
# kubelet picks it up within seconds — no kubectl apply needed
```

### Removing a static pod

```bash
# Delete the file — kubelet will stop and remove the pod
rm /etc/kubernetes/manifests/my-static-pod.yaml
```

### Mirror pods

- **Why it exists** — Cluster operators need visibility into all running pods, including static pods, through the standard API. Mirror pods provide that without giving the API server control over static pods.
- **What it is** — When the API server is running, the kubelet creates a "mirror pod" — a read-only copy of each static pod — in the API server. Mirror pods appear in `kubectl get pods` and `kubectl describe pod`, but any attempt to delete them via kubectl just recreates the mirror. To actually stop a static pod, you must delete the source file from the manifests directory.
- **One-liner** — Mirror pods are read-only API representations of static pods — `kubectl delete` on them has no lasting effect.

```bash
# Mirror pods are visible in kube-system
kubectl get pods -n kube-system

# Control-plane static pods all have the node name as a suffix
kubectl get pods -n kube-system | grep controlplane
# etcd-controlplane
# kube-apiserver-controlplane
# kube-controller-manager-controlplane
# kube-scheduler-controlplane

# Trying to delete a mirror pod is futile — it recreates
kubectl delete pod etcd-controlplane -n kube-system
# pod "etcd-controlplane" deleted
# (immediately recreated by kubelet)
```

### Identifying static pods

**Why it matters** — When debugging, you need to know whether a pod is managed by the API server (can be deleted/edited normally) or by the kubelet directly (must modify the file on disk).

Three ways to identify a static pod:

1. **Name ends with the node name:** `etcd-controlplane`, `kube-apiserver-node1`
2. **`ownerReferences` is empty or points to a Node:** In a regular pod, `ownerReferences` points to a ReplicaSet or StatefulSet. In a static pod (mirror), it points to the Node object.
3. **Annotation `kubernetes.io/config.mirror`** is set on the mirror pod.

```bash
# Method 1: name suffix
kubectl get pods -n kube-system | grep "$(hostname)"

# Method 2: check ownerReferences
kubectl get pod etcd-controlplane -n kube-system -o yaml | grep -A5 ownerReferences
# ownerReferences:
# - apiVersion: v1
#   kind: Node
#   name: controlplane     ← owned by the Node, not a controller

# Method 3: mirror annotation
kubectl get pod etcd-controlplane -n kube-system -o yaml | grep mirror
# kubernetes.io/config.mirror: ...
```

### Static pod path configuration

```bash
# kubelet config file (common location)
cat /var/lib/kubelet/config.yaml
# staticPodPath: /etc/kubernetes/manifests

# Alternatively, kubelet may use --pod-manifest-path flag
# Check the kubelet service definition
systemctl cat kubelet | grep manifest
```

# Troubleshooting

### Static pod not starting after dropping a file in manifests/
1. Check kubelet logs: `journalctl -u kubelet -f` — manifest parse errors appear here.
2. Verify file is valid YAML: `kubectl --dry-run=client apply -f /etc/kubernetes/manifests/my-pod.yaml`.
3. Confirm `staticPodPath` matches the directory: `cat /var/lib/kubelet/config.yaml | grep staticPodPath`.
4. Check kubelet is running: `systemctl status kubelet`.

### kubectl delete pod on a static pod has no effect
1. This is expected — you're deleting the mirror pod; kubelet recreates it.
2. To actually delete: `rm /etc/kubernetes/manifests/<pod-file>.yaml` on the node.
3. To edit: modify the file on disk; kubelet detects the change and recreates the pod.

### Control-plane component is crashing (e.g. etcd)
1. The file is in `/etc/kubernetes/manifests/` — edit it directly.
2. Check kubelet logs: `journalctl -u kubelet -n 100`.
3. Check the pod's container logs via `crictl`: `crictl logs <container-id>` (before API server is up) or `kubectl logs` (after).
4. Common cause: misconfigured flags in the manifest YAML, wrong certificate paths, or missing volumes.
