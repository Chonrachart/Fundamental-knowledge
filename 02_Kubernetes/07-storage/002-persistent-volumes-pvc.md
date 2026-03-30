# Persistent Volumes and PersistentVolumeClaims

# Overview
- **Why it exists** — Decouples storage provisioning from storage consumption. Cluster admins provision (or configure auto-provisioning of) PersistentVolumes; developers simply claim the storage they need via PersistentVolumeClaims without knowing the underlying infrastructure.
- **What it is** — A PersistentVolume (PV) is a cluster-scoped resource representing a piece of real storage (cloud disk, NFS share, local disk). A PersistentVolumeClaim (PVC) is a namespaced request for storage that gets bound to a matching PV.
- **One-liner** — PV is the storage unit; PVC is the request — they meet in the middle so devs and admins work independently.

# Architecture

```text
Admin side                           Developer side
──────────────────────────────────────────────────────────

┌──────────────────┐                 ┌──────────────────┐
│  StorageClass    │  dynamic prov.  │  PVC             │
│  (provisioner)   │ ──────────────► │  requests: 10Gi  │
└──────────────────┘                 │  mode: RWO       │
         OR                          │  class: fast-ssd │
┌──────────────────┐                 └────────┬─────────┘
│  PV (static)     │ ◄── bind ───────────────┘
│  10Gi, RWO       │
└──────────────────┘
         │
         │ mounted by
         ▼
┌──────────────────┐
│      Pod         │
│  mountPath:      │
│  /app/data       │
└──────────────────┘
```

# Mental Model

```text
Admin creates StorageClass (or PV manually)
        │
        ▼
Developer creates PVC (requests size + access mode + storageClass)
        │
        ▼
Kubernetes binds PVC to matching PV
  dynamic: StorageClass provisions new PV automatically
  static:  binds to existing unbound PV that satisfies the request
        │
        ▼
Pod references PVC by name → data is accessible at mountPath
        │
        ▼
Pod deleted → PVC still exists → data persists
        │
        ▼
PVC deleted → reclaim policy decides fate of PV
  Retain  → PV kept (admin must manually clean up and re-use)
  Delete  → PV and underlying storage deleted automatically
```

# Core Building Blocks

### PersistentVolume (PV)

- **Why it exists** — Represents a concrete piece of storage in the cluster, independent of any pod or namespace.
- **What it is** — A cluster-scoped object that wraps a real storage backend (AWS EBS, GCP PD, NFS, hostPath for dev, etc.). Contains capacity, access modes, reclaim policy, and optionally a storage class name.
- **One-liner** — The storage unit that admins provision and Kubernetes manages.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: standard
  hostPath:               # dev/testing only — ties data to one node
    path: /data/my-pv
```

Key fields:

| Field | Purpose |
|-------|---------|
| `capacity.storage` | Total storage capacity of this PV |
| `accessModes` | How this PV can be mounted (see table below) |
| `persistentVolumeReclaimPolicy` | What happens when PVC is deleted |
| `storageClassName` | Ties PV to a StorageClass for binding |
| `hostPath` / `nfs` / `csi` | The actual storage backend |

### PV Lifecycle

- **Why it exists** — Understanding the lifecycle states of a PV is essential for diagnosing why a PVC is stuck in Pending or why data persists or disappears after a PVC deletion.
- **What it is** — The four sequential states a PV moves through: Available, Bound, Released, and then either Deleted or Retained depending on the reclaim policy.
- **One-liner** — PV state machine: Available → Bound → Released → Deleted or Retained.

```text
Available → Bound → Released → Deleted (or Retained)

Available   PV exists and is not bound to any PVC
Bound       PV is bound to a PVC; exclusively used
Released    PVC was deleted; PV is no longer claimed (data may still exist)
Deleted     Underlying storage has been reclaimed (Delete policy)
Retained    PV kept with old data; must be manually reclaimed (Retain policy)
```

### PersistentVolumeClaim (PVC)

- **Why it exists** — Allows developers to request storage without knowing the underlying infrastructure details.
- **What it is** — A namespaced object that specifies desired size, access mode, and optionally storage class. Kubernetes finds (or creates) a matching PV and binds them together.
- **One-liner** — The developer's request ticket for storage.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data
  namespace: dev
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: standard
```

PVC binding rules — Kubernetes binds a PVC to a PV when ALL of these match:
- Capacity: PV capacity >= PVC requested size
- Access modes: PV supports all access modes requested by PVC
- StorageClass: PV and PVC have the same `storageClassName` (or both have none)
- Volume mode: both are Filesystem or both are Block (default is Filesystem)
- Label selectors: if PVC has `selector`, PV labels must match

### Mounting PVC in a Pod

- **Why it exists** — A PVC on its own does nothing; it must be referenced in a pod spec so Kubernetes knows to attach and mount the underlying storage into the container.
- **What it is** — The two-part pod spec pattern: declare the PVC as a named volume under `spec.volumes`, then mount it into a container via `spec.containers[].volumeMounts`.
- **One-liner** — Reference the PVC by name in `spec.volumes`, then mount it at the desired container path.

```yaml
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /app/data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: my-data
```

### Access Modes

- **Why it exists** — Different storage backends support different concurrency models; declaring the wrong access mode causes a PVC to remain unbound or causes data corruption when multiple writers are assumed.
- **What it is** — A set of four access mode values that describe how many nodes (or pods) can mount a volume simultaneously and with what read/write permissions.
- **One-liner** — Declares whether the volume can be mounted by one node, many nodes, or one pod — and in what read/write combination.

| Mode | Short | Meaning |
|------|-------|---------|
| ReadWriteOnce | RWO | One node can mount read-write at a time |
| ReadOnlyMany | ROX | Many nodes can mount read-only simultaneously |
| ReadWriteMany | RWX | Many nodes can mount read-write simultaneously |
| ReadWriteOncePod | RWOP | Only one pod (anywhere) can mount read-write |

Notes:
- Cloud block storage (AWS EBS, GCP PD, Azure Disk) typically supports RWO only.
- NFS, CephFS, and Azure Files support RWX.
- RWO means one **node**, not one pod — multiple pods on the same node can share it.
- RWOP (Kubernetes 1.22+) is stricter than RWO: enforces single-pod exclusivity.

### Reclaim Policies

| Policy | Behavior |
|--------|----------|
| Retain | PV is kept after PVC is deleted; data preserved; admin must manually reclaim |
| Delete | PV and the underlying storage are deleted automatically when PVC is deleted |
| Recycle | (Deprecated) Runs `rm -rf` on the volume then makes it Available again |

- `Retain` is safest for critical data — gives you a recovery window.
- `Delete` is the default for dynamically provisioned PVs and cleans up automatically.
- `Recycle` is deprecated; use dynamic provisioning instead.

### kubectl Commands

```bash
# List PVs and PVCs
kubectl get pv                               # cluster-scoped — no namespace needed
kubectl get pvc                              # current namespace
kubectl get pvc -n dev                       # specific namespace
kubectl get pvc -A                           # all namespaces

# Inspect
kubectl describe pv my-pv
kubectl describe pvc my-data -n dev          # check Status, Events, bound PV name

# Delete
kubectl delete pvc my-data -n dev
```

### volumeClaimTemplates (StatefulSet)

StatefulSets use `volumeClaimTemplates` to automatically create a unique PVC per pod replica. Each pod gets its own stable, persistent storage that survives rescheduling.

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
spec:
  serviceName: db
  replicas: 3
  template:
    spec:
      containers:
      - name: db
        image: postgres:15
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 20Gi
```

This creates PVCs named `data-db-0`, `data-db-1`, `data-db-2` — one per pod.
