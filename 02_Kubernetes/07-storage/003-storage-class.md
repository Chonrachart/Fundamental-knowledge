# StorageClass and Dynamic Provisioning

# Overview
- **Why it exists** — Without StorageClass, every piece of durable storage requires an admin to manually create a PersistentVolume before a developer can use it. StorageClass enables on-demand dynamic provisioning: Kubernetes automatically creates a PV the moment a PVC requests one, with no pre-creation needed.
- **What it is** — A cluster-scoped resource that defines a storage provisioner (the plugin that creates the actual storage), parameters (disk type, IOPS, zone, etc.), and a reclaim policy. When a PVC references a StorageClass, the provisioner creates a PV automatically.
- **One-liner** — StorageClass is the blueprint that tells Kubernetes how to auto-create storage on demand.

### Architecture (ASCII)

```text
Static provisioning (no StorageClass)        Dynamic provisioning (with StorageClass)
─────────────────────────────────────        ────────────────────────────────────────

Admin manually creates PV                    Admin creates StorageClass once
         │                                            │
         ▼                                            │
Developer creates PVC ──────────────────►  Developer creates PVC
         │                                   (references StorageClass)
         │ Kubernetes binds existing PV                │
         ▼                                             ▼
       Pod mounts PVC                       Kubernetes calls provisioner
                                                       │
                                            Provisioner creates real storage
                                            (e.g., AWS EBS volume)
                                                       │
                                            Kubernetes creates PV automatically
                                                       │
                                            PVC binds to new PV
                                                       │
                                                  Pod mounts PVC
```

# Mental Model

```text
StorageClass = a template / "product catalog entry" for storage

  "When someone requests storage with class fast-ssd,
   spin up an SSD volume using the GCP CSI driver,
   and delete it when the claim is released."

One StorageClass can serve many PVCs.
Each PVC that references it gets its own dynamically created PV.

Default StorageClass:
  If a PVC does not specify storageClassName, Kubernetes uses the
  StorageClass annotated as default (if one exists).
```

# Core Building Blocks

### StorageClass Resource

- **Why it exists** — Centralizes storage configuration so developers only need to name a class (e.g., `fast-ssd`, `standard`) rather than specify provisioner details in every PVC.
- **What it is** — A cluster-scoped object with a provisioner name, optional parameters, reclaim policy, and volume binding mode. Created once by admins; consumed by PVCs.
- **One-liner** — The storage policy definition that the provisioner uses to create PVs on demand.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"   # makes this the default
provisioner: ebs.csi.aws.com          # AWS EBS CSI driver
parameters:
  type: gp3                           # EBS volume type
  iops: "3000"
  throughput: "125"
reclaimPolicy: Delete                 # PV deleted when PVC is deleted
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

### Provisioner Field

- **Why it exists** — Tells Kubernetes which plugin (in-tree or CSI driver) is responsible for creating and deleting the actual storage backend.
- **What it is** — A string identifier for the provisioner. Cloud providers ship CSI drivers that implement the provisioner interface.
- **One-liner** — The driver name that does the actual disk creation.

Common provisioner values:

| Cloud / Backend | Provisioner |
|-----------------|-------------|
| AWS EBS (CSI) | `ebs.csi.aws.com` |
| GCP Persistent Disk (CSI) | `pd.csi.storage.gke.io` |
| Azure Disk (CSI) | `disk.csi.azure.com` |
| Azure Files (CSI) | `file.csi.azure.com` |
| NFS (community) | `nfs.csi.k8s.io` |
| Local path (Rancher) | `rancher.io/local-path` |
| No provisioning (manual) | `kubernetes.io/no-provisioner` |

### Default StorageClass

When a PVC does not specify `storageClassName`, Kubernetes automatically uses the StorageClass annotated with:

```yaml
annotations:
  storageclass.kubernetes.io/is-default-class: "true"
```

Rules:
- Only one StorageClass should be marked as default per cluster (if multiple are default, PVC creation may be ambiguous and fail).
- To explicitly opt out of dynamic provisioning (even with a default class present), set `storageClassName: ""` in the PVC.

```bash
kubectl get storageclass            # list all StorageClasses
kubectl get sc                      # shorthand alias

# Example output:
# NAME                PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      AGE
# standard (default)  k8s.io/minikube-hostpath  Delete         Immediate              5d
# fast-ssd            ebs.csi.aws.com           Delete         WaitForFirstConsumer   2d
```

### volumeBindingMode

- **Why it exists** — Controls when the PV is provisioned and bound, which matters for zone-aware scheduling.
- **What it is** — A field on StorageClass with two values.
- **One-liner** — Controls whether volumes are created immediately or only once a pod is scheduled.

| Mode | Behavior |
|------|----------|
| `Immediate` | PV is provisioned and bound as soon as PVC is created (default) |
| `WaitForFirstConsumer` | PV provisioning is deferred until a pod using the PVC is scheduled |

Use `WaitForFirstConsumer` when:
- Your cluster spans multiple availability zones.
- You want the volume to be created in the same zone as the pod's node (avoids zone mismatch errors).
- Using local storage where the node must be chosen first.

### allowVolumeExpansion

Setting `allowVolumeExpansion: true` on a StorageClass lets users resize PVCs after creation by editing the PVC's `spec.resources.requests.storage`. Not all provisioners support this.

```bash
# Expand a PVC (StorageClass must have allowVolumeExpansion: true)
kubectl patch pvc my-data -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

### PVC Referencing a StorageClass

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-storage
  namespace: production
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: fast-ssd    # triggers dynamic provisioning via fast-ssd StorageClass
```

When this PVC is created:
1. Kubernetes sees `storageClassName: fast-ssd`.
2. It calls the `ebs.csi.aws.com` provisioner with the StorageClass parameters.
3. The provisioner creates a real EBS gp3 volume (20Gi) in AWS.
4. Kubernetes creates a PV object representing that volume.
5. The PVC transitions from `Pending` to `Bound`.

### Reclaim Policy on StorageClass vs PV

The `reclaimPolicy` on a StorageClass is inherited by dynamically provisioned PVs. It can also be overridden on a specific PV after creation.

| Location | Effect |
|----------|--------|
| `StorageClass.reclaimPolicy` | Applied to all PVs dynamically created by this class |
| `PersistentVolume.spec.persistentVolumeReclaimPolicy` | Overrides per-PV, can be changed after creation |

### kubectl Commands

```bash
# Inspect StorageClasses
kubectl get sc                               # list all
kubectl describe sc fast-ssd                 # show provisioner, parameters, binding mode

# Watch PV creation after applying a PVC
kubectl get pvc -w                           # watch PVC status change from Pending to Bound
kubectl get pv                               # see auto-created PV

# Change reclaim policy on an existing PV
kubectl patch pv <pv-name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
```

# Troubleshooting

### PVC stuck in Pending with dynamic provisioning
1. `kubectl describe pvc <name>` — Events will show provisioner errors.
2. Verify `kubectl get sc` — check that the StorageClass named in the PVC exists.
3. Check that the provisioner pod (CSI driver) is running in `kube-system`.
4. Confirm cloud credentials/IAM permissions allow disk creation.
5. With `WaitForFirstConsumer`, PVC stays Pending until a pod using it is scheduled — expected behavior.

### Wrong availability zone (zone mismatch)
1. PV was provisioned in zone A, pod is scheduled to zone B — volume cannot attach.
2. Fix: use `volumeBindingMode: WaitForFirstConsumer` so the volume is created in the pod's zone.

### PV not deleted after PVC deletion
1. The StorageClass `reclaimPolicy` is `Retain` — PV is intentionally kept. Admin must manually delete it.
2. Change to `Delete` on the StorageClass for automatic cleanup (or patch the specific PV).

### Multiple default StorageClasses
1. `kubectl get sc` and look for multiple entries with `(default)`.
2. Remove the annotation from all but one: `kubectl annotate sc <name> storageclass.kubernetes.io/is-default-class-`.
