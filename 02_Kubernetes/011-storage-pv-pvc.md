# Storage: PersistentVolume and PersistentVolumeClaim

- PersistentVolume (PV) is a cluster-level storage resource; PersistentVolumeClaim (PVC) is a namespace-level request for storage.
- StorageClass enables dynamic provisioning — PVCs automatically create PVs from a provisioner (cloud disk, NFS, etc.).
- Access modes (RWO, ROX, RWX) and reclaim policies (Retain, Delete) control how storage is shared and cleaned up.

# Architecture

```text
┌──────────────┐         ┌──────────────┐
│ StorageClass │         │  PV (manual) │
│ (provisioner)│         │  (static)    │
└──────┬───────┘         └──────┬───────┘
       │ dynamic provisioning   │ pre-created
       ▼                        ▼
┌──────────────────────────────────────┐
│         PVC (namespace-scoped)       │
│  requests: size, accessMode, class   │
│                                      │
│  Status: Pending → Bound             │
└──────────────────┬───────────────────┘
                   │ pod references PVC
                   ▼
            ┌─────────────┐
            │     Pod     │
            │  volumeMount│ → /app/data
            └─────────────┘
```

# Mental Model

```text
Admin creates StorageClass (or PV manually)
        │
        ▼
User creates PVC (requests size + access mode)
        │
        ▼
Kubernetes binds PVC to matching PV
  (dynamic: StorageClass provisions new PV)
  (static: matches existing unbound PV)
        │
        ▼
Pod mounts PVC as a volume
        │
        ▼
Pod deleted → PVC still exists → data persists
        │
        ▼
PVC deleted → reclaim policy decides:
  Retain  → PV kept (manual cleanup)
  Delete  → PV and underlying storage deleted
```

Example:
```bash
kubectl get storageclass                     # list available storage classes
kubectl get pv                               # list persistent volumes
kubectl get pvc -n dev                       # list claims in namespace
kubectl describe pvc my-data -n dev          # check binding status
```

# Core Building Blocks

### PersistentVolume (PV)

- Cluster-scoped resource representing a piece of storage (disk, NFS share, cloud volume).
- Defined by capacity, access modes, reclaim policy, and storage class.
- Can be statically provisioned (admin creates PV manually) or dynamically provisioned via StorageClass.
- PV is cluster-scoped; PVC is namespaced — PVC binds to PV across the cluster.
- `hostPath` is for dev/testing only; it ties data to one specific node.

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
  hostPath:
    path: /data/my-pv
```

### PersistentVolumeClaim (PVC)

- Namespaced request for storage; specifies size, access mode, and optionally storage class.
- Kubernetes binds PVC to a suitable PV; pod references PVC by name.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: standard
```

### Access Modes

| Mode | Short | Meaning |
|------|-------|---------|
| ReadWriteOnce | RWO | One node can mount read-write |
| ReadOnlyMany | ROX | Many nodes can mount read-only |
| ReadWriteMany | RWX | Many nodes can mount read-write |

- Cloud block storage (EBS, Persistent Disk) typically supports only RWO.
- NFS and CephFS support RWX.
- RWO means one node, not one pod — multiple pods on the same node can mount it.

### StorageClass and Dynamic Provisioning

- StorageClass defines a provisioner (e.g. `kubernetes.io/aws-ebs`, `pd.csi.storage.gke.io`) and parameters.
- PVC with `storageClassName` triggers dynamic provisioning — no manual PV creation needed.
- `storageclass.kubernetes.io/is-default-class: "true"` annotation sets the default class.
- Dynamic provisioning (StorageClass) is preferred over static PV creation in production.
- `WaitForFirstConsumer` delays volume binding until a pod is scheduled — avoids zone mismatch.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

### Reclaim Policies

| Policy | Behavior |
|--------|----------|
| Retain | PV kept after PVC deleted; admin must manually clean up |
| Delete | PV and underlying storage deleted when PVC is deleted |
| Recycle | (Deprecated) Basic `rm -rf` on the volume |

- Reclaim policy `Retain` is safest for important data; requires manual PV cleanup.

### Mounting in Pods

```yaml
spec:
  containers:
  - name: app
    volumeMounts:
    - name: data
      mountPath: /app/data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: my-data
```

### volumeClaimTemplates (StatefulSet)

- StatefulSet uses `volumeClaimTemplates` to create a unique PVC per pod.
- PVCs persist across pod restarts and rescheduling — each pod gets its own stable storage.
- StatefulSet `volumeClaimTemplates` create per-pod PVCs that survive rescheduling.

Related notes: [007-statefulset-daemonset](./007-statefulset-daemonset.md), [002-pods-labels](./002-pods-labels.md)

---

# Troubleshooting Guide

### PVC stuck in Pending
1. Check events: `kubectl describe pvc <name>` — look at Events.
2. No matching PV: check size, access mode, and storage class match.
3. Dynamic provisioning: check StorageClass exists and provisioner is running.
4. `WaitForFirstConsumer`: PVC stays Pending until a pod using it is scheduled.

### Pod stuck in Pending due to volume
1. Check pod events: `kubectl describe pod <name>` — look for volume-related messages.
2. PVC not bound: fix PVC first (see above).
3. Multi-attach error: RWO volume already attached to another node; check if old pod is terminating.

### Data lost after pod restart
1. Check if pod uses `emptyDir` (ephemeral) instead of PVC — `emptyDir` is lost on pod delete.
2. Check reclaim policy: if `Delete`, PV is destroyed when PVC is deleted.
3. For StatefulSet: PVCs persist across restarts; data should survive unless PVC was manually deleted.
