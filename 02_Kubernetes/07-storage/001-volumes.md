# Volumes

### Overview
- **Why it exists** — Containers have ephemeral filesystems: when a container restarts, all data written to its local filesystem is lost. Volumes provide a way for data to outlive individual container restarts and to be shared between containers within the same pod.
- **What it is** — A volume is a directory (backed by some storage medium) that is mounted into one or more containers in a pod. Volumes are declared in the pod spec and exist for the lifetime of the pod, not the lifetime of any single container.
- **One-liner** — Volumes give pods a place to store and share data that survives container restarts.

### Architecture (ASCII)

```text
┌─────────────────────────────────────────┐
│                  Pod                    │
│                                         │
│  ┌────────────┐    ┌────────────┐       │
│  │ Container A│    │ Container B│       │
│  │            │    │            │       │
│  │  /data ────┼────┼── /data    │       │
│  └────────────┘    └────────────┘       │
│          │                              │
│     ┌────▼────┐                         │
│     │ Volume  │  (shared within pod)    │
│     └─────────┘                         │
└─────────────────────────────────────────┘

Volume lifecycle: tied to the Pod (not the container)
```

### Mental Model

```text
Container filesystem  →  ephemeral (dies with container)
Volume                →  survives container restarts within a pod
PersistentVolume      →  survives pod deletion entirely

Think of it like:
  Container = process with its own temp workspace
  Volume     = shared folder mounted into that workspace
  PVC/PV     = external hard drive plugged into the pod
```

### Core Building Blocks

### Volume Types Overview

| Type | Lifetime | Use Case |
|------|----------|----------|
| emptyDir | Pod | Temp scratch space, sharing data between containers |
| hostPath | Node | Accessing node files (logs, Docker socket) — use with caution |
| configMap | Cluster | Mount ConfigMap entries as files |
| secret | Cluster | Mount Secrets as files (base64-decoded) |
| persistentVolumeClaim | Cluster | Durable storage backed by a PersistentVolume |

### emptyDir
- **Why it exists** — Provides a temporary, empty directory that containers in the same pod can share. Useful for scratch space or inter-container communication via the filesystem.
- **What it is** — An empty directory created when the pod is assigned to a node. It is deleted permanently when the pod is removed from the node (deleted, evicted, or node failure).
- **One-liner** — Shared scratch space for the lifetime of the pod.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shared-data-pod
spec:
  containers:
  - name: writer
    image: busybox
    command: ["sh", "-c", "echo hello > /scratch/msg; sleep 3600"]
    volumeMounts:
    - name: scratch
      mountPath: /scratch
  - name: reader
    image: busybox
    command: ["sh", "-c", "cat /scratch/msg; sleep 3600"]
    volumeMounts:
    - name: scratch
      mountPath: /scratch
  volumes:
  - name: scratch
    emptyDir: {}
```

Optional — store in memory instead of disk (useful for sensitive temp data):

```yaml
  volumes:
  - name: scratch
    emptyDir:
      medium: Memory
      sizeLimit: 64Mi
```

### hostPath
- **Why it exists** — Allows a pod to access files or directories on the host node's filesystem. Common use cases include reading node-level logs or accessing the Docker/containerd socket.
- **What it is** — A volume that mounts a specific path from the host node into the pod. The data persists on the node even after the pod is deleted, but it is NOT portable across nodes.
- **One-liner** — Direct window into the host node's filesystem — powerful but dangerous.

> **Security risk:** hostPath breaks pod isolation. A pod with hostPath access to `/` can read or modify any file on the node. Avoid in production workloads; use only when absolutely necessary (e.g., node agents, log collectors).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: node-log-reader
spec:
  containers:
  - name: log-reader
    image: busybox
    command: ["sh", "-c", "tail -f /node-logs/syslog"]
    volumeMounts:
    - name: host-logs
      mountPath: /node-logs
      readOnly: true
  volumes:
  - name: host-logs
    hostPath:
      path: /var/log
      type: Directory
```

hostPath `type` options:

| Type | Behavior |
|------|----------|
| `""` (empty) | No checks; path may or may not exist |
| `Directory` | Path must exist and be a directory |
| `File` | Path must exist and be a file |
| `DirectoryOrCreate` | Create directory if it does not exist |
| `FileOrCreate` | Create file if it does not exist |
| `Socket` | Path must be a Unix socket |

### configMap
- **Why it exists** — Allows configuration data stored in a ConfigMap to be consumed as files rather than environment variables, which is useful for config files, scripts, or certificates.
- **What it is** — Mounts ConfigMap keys as files in a directory inside the container. The content of each file is the value of the corresponding key.
- **One-liner** — ConfigMap entries projected as read-only files into a container.

```yaml
  volumes:
  - name: app-config
    configMap:
      name: my-config
```

### secret
- **Why it exists** — Safely injects sensitive data (passwords, tokens, TLS certs) as files rather than environment variables, which are easier to leak via logs.
- **What it is** — Mounts Secret keys as files. Values are base64-decoded automatically. Backed by tmpfs (in-memory) by default — never written to disk.
- **One-liner** — Secret entries projected as in-memory read-only files into a container.

```yaml
  volumes:
  - name: tls-certs
    secret:
      secretName: my-tls-secret
```

### persistentVolumeClaim
- **Why it exists** — Connects a pod to durable external storage (cloud disk, NFS, etc.) that outlives the pod itself.
- **What it is** — References a PVC by name. Kubernetes resolves the PVC to a bound PV and mounts the underlying storage. See `002-persistent-volumes-pvc.md` for full details.
- **One-liner** — The bridge between a pod and long-lived external storage.

```yaml
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: my-data-pvc
```

### Troubleshooting

### Container data lost after restart (but pod still running)
1. Verify the container is using a volume — check `spec.volumes` and `spec.containers[].volumeMounts`.
2. If using `emptyDir`, data survives container restarts within the same pod but NOT pod deletion.
3. For data that must survive pod deletion, switch to a PVC.

### Volume not mounting — pod stuck in ContainerCreating
1. `kubectl describe pod <name>` — check Events for volume-related errors.
2. For `configMap` / `secret` volumes, confirm the referenced resource exists in the same namespace.
3. For `hostPath`, verify the path exists on the node (or use `DirectoryOrCreate`).

### hostPath data only visible on one node
1. hostPath is node-local — if the pod reschedules to a different node, the data on the original node is inaccessible.
2. Use a `persistentVolumeClaim` backed by network storage for portable data.
