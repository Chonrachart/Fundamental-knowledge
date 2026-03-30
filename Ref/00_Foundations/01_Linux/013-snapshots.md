# Snapshots

- A snapshot is a point-in-time copy of data state — it captures the exact condition of a filesystem, volume, database, or VM at a specific moment for backup, rollback, or cloning.
- Snapshots use copy-on-write (CoW) to be space-efficient: only changed blocks consume additional storage after the snapshot is taken.
- Snapshots are not full backups — they depend on the original data source; if the underlying storage fails, the snapshot is lost too.

# Architecture

```text
Snapshot Concept (Copy-on-Write):

BEFORE SNAPSHOT:
  Volume: [Block A] [Block B] [Block C] [Block D]

AFTER SNAPSHOT (no extra space yet):
  Volume:   [Block A] [Block B] [Block C] [Block D]
  Snapshot: [ptr -> A] [ptr -> B] [ptr -> C] [ptr -> D]
            (pointers to original blocks, no copy yet)

AFTER WRITE TO BLOCK B:
  Volume:   [Block A] [Block B'] [Block C] [Block D]
                         ^--- new data written
  Snapshot: [ptr -> A] [Block B (original)] [ptr -> C] [ptr -> D]
                         ^--- original preserved in snapshot

Space used by snapshot = only the changed blocks (B original)
```

```text
Snapshot Types Across Technologies:

+---------------------+-------------------+-------------------------------+
| Technology          | Snapshot Type     | Mechanism                     |
+---------------------+-------------------+-------------------------------+
| LVM                 | LV Snapshot       | CoW on logical volume         |
| Btrfs               | Subvolume Snap    | CoW filesystem-level          |
| ZFS                 | Dataset Snapshot  | CoW filesystem-level          |
| AWS EBS             | EBS Snapshot      | Incremental block-level to S3 |
| AWS RDS             | DB Snapshot       | Full or automated backup      |
| VMware / KVM        | VM Snapshot       | Disk + memory state capture   |
| Docker              | Image Layer       | Union filesystem layers       |
| Kubernetes (CSI)    | VolumeSnapshot    | CSI driver-dependent          |
+---------------------+-------------------+-------------------------------+
```

# Mental Model

```text
Snapshot lifecycle:

  [1] TAKE SNAPSHOT
      |   - Freeze or quiesce data momentarily
      |   - Record current state (metadata + block pointers)
      |   - Very fast (seconds) — no full copy
      |
      v
  [2] CONTINUE WORKING
      |   - New writes go to live volume
      |   - Original blocks preserved in snapshot (CoW)
      |   - Snapshot grows only as data changes
      |
      v
  [3] USE SNAPSHOT (choose one)
      |
      +-- ROLLBACK: revert live volume to snapshot state
      |     (undo all changes since snapshot)
      |
      +-- CLONE: create new volume from snapshot
      |     (independent copy for testing/dev)
      |
      +-- BACKUP: copy snapshot data to external storage
      |     (consistent point-in-time backup)
      |
      +-- READ: mount snapshot read-only for inspection
      |
      v
  [4] DELETE SNAPSHOT (when no longer needed)
      - Releases the preserved original blocks
      - Frees storage space
      - Live volume is unaffected
```

# Core Building Blocks

### Copy-on-Write (CoW)

- Core mechanism behind most snapshot implementations.
- On snapshot creation: no data is copied; only metadata pointers are created (instant).
- On first write to a block after snapshot: original block is copied to snapshot area, then the write proceeds.
- Trade-off: writes are slightly slower during active snapshot (extra copy operation).
- Space: snapshot starts at 0 size; grows as the live volume diverges from the snapshot.
- Multiple snapshots: each snapshot only stores the delta from the previous state.
- Snapshot = point-in-time state capture; uses CoW for space efficiency.
- Snapshots are NOT backups — they depend on the original storage.
- CoW trade-off: writes are slower during active snapshot but reads are unaffected.

```text
CoW write path:

  Application writes Block X
      |
      v
  Is Block X in a snapshot?
      |
      +--NO---> Write directly to Block X (normal speed)
      |
      +--YES--> Copy original Block X to snapshot area
                  |
                  v
                Write new data to Block X
                (original preserved in snapshot)
```

Related notes: [006-disk](./006-disk.md), [005-file-system-mount](./005-file-system-mount.md)

### LVM Snapshots

- LVM creates snapshots at the logical volume level using CoW.
- Snapshot is a separate LV that tracks changes to the origin LV.
- Must pre-allocate snapshot size — if snapshot fills up (too many changes), it becomes invalid.
- Use cases: safe system upgrades, consistent backup of active volumes.

```bash
# Create snapshot of logical volume
lvcreate --size 5G --snapshot --name snap_root /dev/vg0/root

# List snapshots
lvs -o lv_name,lv_size,snap_percent,origin

# Mount snapshot (read-only)
mount -o ro /dev/vg0/snap_root /mnt/snapshot

# Restore from snapshot (DANGER: reverts all changes)
lvconvert --merge /dev/vg0/snap_root
# Reboot required if restoring root volume

# Remove snapshot
lvremove /dev/vg0/snap_root
```

```text
LVM snapshot sizing:
  - Snapshot must be large enough to hold all CoW blocks
  - Rule of thumb: 10-20% of origin volume size for short-lived snapshots
  - Monitor usage: lvs shows snap_percent (% of snapshot used)
  - If snap_percent reaches 100%: snapshot is INVALID and must be removed
```
- LVM snapshots: must pre-allocate size; if full, snapshot is invalid.

Related notes: [006-disk](./006-disk.md)

### Btrfs Snapshots

- Btrfs supports snapshots natively at the subvolume level — no pre-allocation needed.
- Snapshots are instant, lightweight, and share data with the original subvolume via CoW.
- Can create writable snapshots (unlike LVM which defaults to CoW read-only behavior).
- Commonly used by: Snapper (SUSE/openSUSE), Timeshift (Ubuntu/Fedora).

```bash
# Create snapshot of subvolume
btrfs subvolume snapshot /home /snapshots/home-$(date +%Y%m%d)

# Create read-only snapshot (for backup)
btrfs subvolume snapshot -r /home /snapshots/home-readonly

# List snapshots
btrfs subvolume list /

# Delete snapshot
btrfs subvolume delete /snapshots/home-20260317

# Send/receive (backup to external drive)
btrfs send /snapshots/home-readonly | btrfs receive /mnt/backup/
```

- Advantages over LVM snapshots: no size pre-allocation, no performance degradation, incremental send/receive for backups.
- Btrfs/ZFS snapshots: no size limit, instant, support send/receive for backup.

Related notes: [005-file-system-mount](./005-file-system-mount.md)

### ZFS Snapshots

- ZFS snapshots are instantaneous and zero-cost until data diverges.
- Snapshots are read-only; clones (writable copies) can be created from snapshots.
- ZFS tracks all block changes automatically — no size limits on snapshots.
- Supports incremental send/receive for efficient replication and backup.

```bash
# Create snapshot
zfs snapshot pool/dataset@snap-20260317

# List snapshots
zfs list -t snapshot

# Rollback to snapshot (reverts dataset)
zfs rollback pool/dataset@snap-20260317

# Clone from snapshot (writable copy)
zfs clone pool/dataset@snap-20260317 pool/dataset-clone

# Send to remote (incremental backup)
zfs send -i pool/dataset@snap1 pool/dataset@snap2 | ssh remote zfs receive pool/dataset

# Destroy snapshot
zfs destroy pool/dataset@snap-20260317
```

Related notes: [005-file-system-mount](./005-file-system-mount.md)

### VM Snapshots (VMware / KVM / Hyper-V)

- VM snapshots capture the entire state: disk, memory, and VM configuration.
- Useful for: pre-upgrade safety, testing patches, quick rollback.
- NOT a replacement for backups — snapshots degrade performance over time and depend on the underlying datastore.
- Best practice: take snapshot, make change, verify, then delete snapshot (don't keep long-term).

```text
VM snapshot includes:
  - Disk state: delta/differencing disk file (VMDK, qcow2)
  - Memory state: RAM contents at snapshot time (optional)
  - VM config: CPU, NIC, device settings

Performance impact:
  - Active snapshots create a chain of delta files
  - Each write goes through the chain (slower I/O)
  - Long snapshot chains = significant performance degradation
  - Rule: delete snapshots within 24-72 hours
```

```bash
# KVM/libvirt snapshot
virsh snapshot-create-as myvm snap1 --description "before upgrade"
virsh snapshot-list myvm
virsh snapshot-revert myvm snap1
virsh snapshot-delete myvm snap1

# QEMU/qcow2 snapshot (offline)
qemu-img snapshot -c snap1 /var/lib/libvirt/images/myvm.qcow2
qemu-img snapshot -a snap1 /var/lib/libvirt/images/myvm.qcow2   # revert
qemu-img snapshot -d snap1 /var/lib/libvirt/images/myvm.qcow2   # delete
```
- VM snapshots: capture disk + memory; delete within 72 hours (performance impact).

Related notes: [012-network-storage](./012-network-storage.md)

### Cloud Snapshots (AWS EBS / RDS)

- **EBS Snapshots**: point-in-time backup of EBS volumes stored in S3.
  - First snapshot: full copy of used blocks.
  - Subsequent snapshots: incremental (only changed blocks since last snapshot).
  - Can create new volumes from snapshots (any AZ in same region).
  - Can copy snapshots across regions for disaster recovery.

```bash
# AWS CLI: EBS snapshot
aws ec2 create-snapshot --volume-id vol-123abc --description "pre-upgrade"
aws ec2 describe-snapshots --owner-ids self
aws ec2 create-volume --snapshot-id snap-456def --availability-zone us-east-1a

# Automated: AWS Data Lifecycle Manager (DLM) or AWS Backup
```

- **RDS Snapshots**: full database backup at a point in time.
  - Automated snapshots: configured retention (1-35 days), taken during backup window.
  - Manual snapshots: user-initiated, persist until manually deleted.
  - Restore: creates a new RDS instance from the snapshot (new endpoint).

```bash
# AWS CLI: RDS snapshot
aws rds create-db-snapshot --db-instance-identifier mydb --db-snapshot-identifier mydb-snap
aws rds restore-db-instance-from-db-snapshot --db-instance-identifier mydb-new --db-snapshot-identifier mydb-snap
```
- EBS snapshots: incremental, stored in S3, can create volumes across AZs.

Related notes: [005-file-system-mount](./005-file-system-mount.md)

### Kubernetes Volume Snapshots (CSI)

- Kubernetes VolumeSnapshot API (CSI) provides snapshot support for persistent volumes.
- Storage driver must support CSI snapshots (AWS EBS CSI, GCE PD CSI, Ceph, etc.).
- Use cases: backup PVCs before migrations, clone volumes for testing.

```yaml
# VolumeSnapshot
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: myapp-data-snap
spec:
  volumeSnapshotClassName: csi-aws-vsc
  source:
    persistentVolumeClaimName: myapp-data

# Restore: create PVC from snapshot
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myapp-data-restored
spec:
  dataSource:
    name: myapp-data-snap
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 50Gi
```

Related notes: [006-disk](./006-disk.md)

### Database Snapshots

- Database-consistent snapshots require the database to be quiesced or use built-in snapshot tools.
- Methods:
  - **Filesystem snapshot with freeze**: flush database to disk, freeze writes, take LVM/Btrfs snapshot, unfreeze.
  - **Database-native**: PostgreSQL `pg_basebackup`, MySQL `mysqldump --single-transaction`, MongoDB `mongodump`.
  - **Cloud-managed**: RDS automated snapshots, Azure SQL backup.
- Consistency is critical: a filesystem snapshot during active writes may capture a corrupted database state.
- Database snapshots: must quiesce/freeze writes for consistency.

```bash
# PostgreSQL: consistent snapshot via filesystem
psql -c "SELECT pg_start_backup('snap');"
lvcreate --size 5G --snapshot --name dbsnap /dev/vg0/pgdata
psql -c "SELECT pg_stop_backup();"

# MySQL: consistent dump
mysqldump --single-transaction --all-databases > backup.sql

# MongoDB: filesystem snapshot
db.fsyncLock()
# take LVM/EBS snapshot
db.fsyncUnlock()
```

Related notes: [006-disk](./006-disk.md)
