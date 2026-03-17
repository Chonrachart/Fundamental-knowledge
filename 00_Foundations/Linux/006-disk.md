# Disk, Storage, and LVM

- Linux storage is abstracted in layers: physical disks → partitions → (optional) LVM logical volumes → filesystem.
- LVM adds a flexible management layer between partitions and filesystems, enabling resize and snapshots without downtime.
- RAID combines multiple disks for performance (RAID 0), redundancy (RAID 1/5/6), or both (RAID 10).


# Storage Abstraction Layers

```text
Application  (read/write files)
        |
        v
Filesystem   (ext4, xfs — organises data)
        |
        v
Block device (LV or raw partition — /dev/mapper/vg-lv or /dev/sdb1)
        |
        v
LVM          (optional: PV → VG → LV)
        |
        v
RAID / mdadm (optional: stripes/mirrors across physical disks)
        |
        v
Physical disk (/dev/sda, /dev/sdb, /dev/nvme0n1)
```

LVM flow: `Disk → pvcreate → vgcreate → lvcreate → mkfs → mount`


# Mental Model: LVM Resize

```text
Need more space on /data (LV)
        |
        v
Add new disk or extend existing VG
        |
        v
pvcreate /dev/sdc1           (prepare new disk as PV)
        |
        v
vgextend vg_data /dev/sdc1   (add PV to volume group)
        |
        v
lvextend -L +20G /dev/vg_data/lv_data   (grow LV)
        |
        v
resize2fs /dev/vg_data/lv_data   (grow ext4 filesystem to fill LV)
OR xfs_growfs /data              (grow xfs filesystem — must be mounted)
        |
        v
df -h /data  →  verify new size
```


# Core Building Blocks

### Swap

```bash
free -h                     # show RAM and swap usage
swapon --show               # show active swap devices

mkswap /dev/sdX1            # prepare partition as swap
swapon /dev/sdX1            # enable swap
swapoff /dev/sdX1           # disable swap
```

- Swap is virtual memory on disk — used when RAM is exhausted.
- Add to `/etc/fstab` for permanent swap: `UUID=... none swap sw 0 0`

### Links

```bash
ln <source> <link_name>         # hard link
ln -s <source> <link_name>      # symbolic (soft) link
ls -li                          # show inode numbers (same inode = hard link)
```

| | Hard link | Soft (symbolic) link |
|---|---|---|
| Inode | Same as source | Own inode; points to path |
| Works if source deleted | Yes | No (becomes broken) |
| Cross-filesystem | No | Yes |
| Link directories | No | Yes |

### Disk Usage

```bash
df -h                       # filesystem usage (space per mount point)
df -i                       # inode usage
du -sh <dir>                # size of directory
du -sh * | sort -rh | head  # top directories by size
```

### LVM (Logical Volume Manager)

```bash
# inspect
pvs                         # physical volumes summary
vgs                         # volume groups summary
lvs                         # logical volumes summary
pvdisplay / vgdisplay / lvdisplay   # detailed view

# create
pvcreate /dev/sdb1          # initialise partition as PV
vgcreate vg_data /dev/sdb1  # create VG from PV
lvcreate -L 10G -n lv_data vg_data  # create 10G LV named lv_data

# extend
vgextend vg_data /dev/sdc1
lvextend -L +5G /dev/vg_data/lv_data
resize2fs /dev/vg_data/lv_data      # ext4
xfs_growfs /mountpoint              # xfs (mounted)

# snapshot
lvcreate -L 2G -s -n snap_data /dev/vg_data/lv_data
```

Related notes:
- [05-file-system-mount](./05-file-system-mount.md) — mkfs and mounting after LVM setup

### RAID

RAID = Redundant Array of Independent Disks — combines disks for performance or redundancy.

| Level | Min Disks | Fault Tolerance | Usable Space | Performance |
|---|---|---|---|---|
| 0 | 2 | 0 disks | 100% | Very high (striping) |
| 1 | 2 | 1 disk | 50% | High read, normal write |
| 5 | 3 | 1 disk | N−1 | Good read, slower write |
| 6 | 4 | 2 disks | N−2 | Good read, slowest write |
| 10 | 4 | 1 per mirror | 50% | Very high both |

RAID 5 parity: data split with distributed parity — `P = A xor B`; reconstruct with `A = P xor B`.

```bash
# software RAID with mdadm
mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdb1 /dev/sdc1
cat /proc/mdstat             # RAID status and rebuild progress
mdadm --detail /dev/md0      # detailed array info
```

### Ceph (Distributed Storage)

- Software-defined storage platform: block + object + file storage from a cluster of servers.
- Core properties: data distributed across nodes, replicated, no single point of failure, scales horizontally.
- Used in cloud environments (OpenStack, Kubernetes persistent volumes).

---

# Troubleshooting Guide

### Disk full — "No space left on device"

1. Which filesystem is full? `df -h`.
2. Find largest directories: `du -sh * | sort -rh | head`.
3. Check inode exhaustion (separate from space): `df -i`.

### LV resize needed

1. Check free space in VG: `vgs`. Yes: `lvextend` directly. No: `pvcreate` + `vgextend` new disk first.
2. After lvextend: `resize2fs` (ext4) or `xfs_growfs` (xfs).

### RAID degraded

1. Identify failed disk: `cat /proc/mdstat`.
2. Replace and rebuild: `mdadm --manage /dev/md0 --add /dev/sdd1`.


# Quick Facts (Revision)

- `df -h` shows space; `df -i` shows inodes — both can independently reach 100%.
- Hard links share the same inode; soft links point to a path and break if the target is removed.
- LVM resize workflow: `pvcreate → vgextend → lvextend → resize2fs/xfs_growfs`.
- `xfs_growfs` requires the filesystem to be mounted; `resize2fs` works unmounted.
- RAID 5 tolerates 1 disk failure; RAID 6 tolerates 2 — prefer RAID 6 for large disk counts.
- RAID is not a backup — it protects against disk failure, not accidental deletion or corruption.
- Swap on SSD is fast but wears the drive — prefer adding RAM over heavy swap usage.
