# Filesystem and Mounting

# Overview
- **What it is** — File system is the method used by Linux to store and organize data on disk. Different file systems provide different features, performance, and reliability.

# Architecture

```
Boot step
1. Power On
2️. BIOS / UEFI initializes hardware
→ Initializes CPU, RAM, storage, selects boot device
3️. Bootloader loads (GRUB)
→ Loads Linux kernel and passes boot parameters
4️. Kernel loads into memory
→ Kernel initializes core system functions and drivers
5️. initramfs loads
→ Temporary minimal filesystem prepares real root filesystem
6️. Root filesystem mounted as read-only (ro)
→ Root mounted safely to prevent corruption before check
7️. fsck runs (based on fstab pass value)
→ Check root filesystem integrity
8️. If root OK → remount root as read-write (rw)
→ Switch root to writable mode after successful check
9️. Other filesystems (pass=2) checked
→ Check other filesystems listed in fstab
10. Other filesystems mounted
→ Attach /home, /data, etc. to directory tree
11. Start init system (systemd)
→ System manager takes control of startup process
12. systemd starts services
→ Launch networking, SSH, logging, cron, etc.
13. Login prompt appears
```

# Core Building Blocks

### Filesystem Types

#### ext4

- Default file system for most Linux distributions.
- Stable and widely supported.
- Good balance between performance and reliability.
- Common usage: Root (/) partition, General Linux servers

#### XFS

- Designed for large files and high I/O workloads.
- Online resizing (can grow while mounted).
- Common usage: Database servers

#### ZFS

- Combines file system + RAID management.
- Focus on data integrity and reliability.
- Snapshots and cloning.
- Data integrity verification (checksums).
- Common usage: Backup servers, Storage servers

| Type  | Best For                | Notes                                                 |
| ----- | ----------------------- | ----------------------------------------------------- |
| ext4  | General-purpose Linux   | Default on most distros; stable, widely supported     |
| xfs   | Large files, high I/O   | Default on RHEL; grows online; good for databases     |
| zfs   | Data integrity, backups | Built-in RAID + checksums + snapshots; high RAM usage |
| tmpfs | Temp data in RAM        | Fast; data lost on reboot; used for `/tmp`, `/run`    |
| nfs   | Network-shared storage  | Remote filesystem over network                        |

- `tmpfs` mounts live in RAM — data is lost on reboot (correct for `/tmp`).
- Root mounts read-only at boot first to allow fsck to check for corruption.


### Disk Partitions
- **What it is** — Partition divides a physical disk into logical sections. Each partition can contain its own file system. Partitioning is required before formatting and mounting.

```bash
lsblk               # show disks and partitions in tree view
lsblk -f            # include filesystem type and UUID
fdisk -l            # list all disks and partitions (MBR)
parted -l           # list all disks (MBR + GPT)
blkid               # show UUID and filesystem type per device
```

#### Partition Table Types

- MBR (Master Boot Record)
  - Up to 4 primary partitions.
  - Maximum 2TB disk size.
- GPT (GUID Partition Table)
  - Supports many partitions.
  - Supports disks larger than 2TB.
  - Modern standard.

### Create Filesystem

```bash
mkfs.ext4 /dev/sdb1         # format partition as ext4
mkfs.xfs  /dev/sdb1         # format partition as xfs
mkfs -t ext4 /dev/sdb1      # generic form
```

- Formatting destroys existing data on the partition — confirm device name first.

### Mounting
- **Why it exists** — Without mounting, the partition cannot be accessed.
- **What it is** — Mount attaches a file system to a directory. The directory used is called a mount point.

### Mounting

```bash
mount /dev/sdb1 /mnt            # mount partition to /mnt
mount -t xfs /dev/sdb1 /data    # specify filesystem type explicitly
umount /mnt                     # unmount (fails if anything is using it)
findmnt                         # show all currently mounted filesystems
df -h                           # show mounted filesystem usage
```

- Mount point directory must exist before mounting.
- `umount` fails if the mount point is busy — find the process with `lsof +D /mnt`.
- `df -h` shows space usage; `df -i` shows inode usage — both can hit 100%.

### Permanent Mounting (/etc/fstab)
- **Why it exists** — To mount **automatically after reboot**.
- **What it is** — fstab = file system table. System reads this file during boot.

```bash
configure in /etc/fstab
```

- add this format

```bash
# Format:
<device> <mount_point> <filesystem_type> <options> <dump> <pass>

# Examples:
/dev/sdb1   /data   ext4   defaults   0   2
UUID=abcd-1234   /data   ext4   defaults   0   2
```

- Recommended Use UUID instead of `/dev/sdX` to prevent name change.
  - see UUID use `blkid`

- `<dump>` → Backup flag (usually 0)
- `<pass>` → This controls filesystem check order at boot using fsck.
  - 0 → no check (temporary mount)
  - 1 → root partition
  - 2 → other partitions

- Common Mount Options
  - defaults → rw, suid, dev, exec, auto, nouser, async
  - ro → read-only
  - rw → read-write
  - noexec → prevent execution

#### Test fstab (Important)
- After editing:
  
```bash
mount -a        # mount all fstab entries; errors show immediately
findmnt --verify
```

- If no error → configuration is correct.
- If error → fix before reboot.
