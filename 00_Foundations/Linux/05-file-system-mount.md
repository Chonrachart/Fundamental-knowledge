# File System Type

- File system is the method used by Linux to store and organize data on disk.
- Different file systems provide different features, performance, and reliability.

### ext4 

- Default file system for most Linux distributions.
- Stable and widely supported.
- Good general-purpose file system.
- Good balance between performance and reliability.
- Common usage
  - Root (/) partition
  - General Linux servers

### XFS

- Designed for large files and high I/O workloads.
- Good for large storage systems.
- Online resizing (can grow while mounted).
- Common usage:
  - Database servers

### ZFS

- Combines file system + RAID management.
- Focus on data integrity and reliability.
- Snapshots and cloning.
- Data integrity verification (checksums).
- Common usage:
  - Backup servers
  - Storage servers

# Disk partition

- Partition divides a physical disk into logical sections.
- Each partition can contain its own file system.
- Partitioning is required before formatting and mounting.

```bash
lsblk
fdisk /dev/sdX
parted /dev/sdX
```

- `lsblk` Show disks and partitions.
- `lsblk -f` Show file system type.
- `fdisk` Create or manage partitions (MBR).
- `fdisk -l` list all disk and their partitions.
- `parted` Advanced partition tool (supports GPT).
  
### Partition Table Types

- MBR (Master Boot Record)
  - Up to 4 primary partitions.
  - Maximum 2TB disk size.
- GPT (GUID Partition Table)
  - Supports many partitions.
  - Supports disks larger than 2TB.
  - Modern standard.

# Create file system format

```bash
mkfs -t <type> <partition>
or
mkfs.ext4 <partition>
mkfs.xfs <partition>
```

- `mkfs` make file system.
- `<type>` specify file system type (ext4, xfs, etc.).
- `<partition>` example: `/dev/sdb1`

# Mounting

- Mount attaches a file system to a directory.
- Without mounting, the partition cannot be accessed.
- The directory used is called a mount point.

```bash
mount <partition> <mount_point>
umount <mount_point>
```
Example:

```bash
mount /dev/sdb1 /mnt
```

- `/dev/sdb1` → partition
- `/mnt` → mount point or path that want to mount (must already exist)

# Permanent Mounting

- To mount **automatically after reboot**, configure /etc/fstab.
- fstab = file system table.
- System reads this file during boot.

```bash
configure in /etc/fstab
```

- add this format

```bash
<device> <mount_point> <filesystem_type> <options> <dump> <pass>
Example
/dev/sdb1   /data   ext4   defaults   0   2
UUID=abcd-1234   /data   ext4   defaults   0   2
```

- Recommended Use UUID instead of `/dev/sdX` to prevent name change.
  - see UUID use `blkid`

- `<dump>` → Backup flag (usually 0)
- `<pass>` → This controls filesystem check order at boot using fsck.
  - `pass=1` usually root filesystem.
  - `pass=2` other local filesystems.
  - `pass=0` skip fsck check on boot.

- Common Mount Options
  - defaults → rw, suid, dev, exec, auto, nouser, async
  - ro → read-only
  - rw → read-write
  - noexec → prevent execution

### If fstab is wrong **(Important)**

- System may drop into emergency mode during boot.
- Best practice after editing fstab:
  
```bash
mount -a
```
- If no error → configuration is correct.
- If error → fix before reboot.

# Boot Flow and Filesystem Mount

- Boot and mount are tightly related because Linux cannot continue without mounting root filesystem.

```text
1) Power on
2) BIOS/UEFI initializes hardware
3) Bootloader (GRUB) loads kernel + initramfs
4) Kernel starts, loads essential drivers
5) initramfs finds real root filesystem
6) Root (/) mounts read-only first
7) fsck may run (fstab pass)
8) Root remounts read-write
9) Other filesystems mount from /etc/fstab
10) systemd (PID 1) starts targets and services
11) Login prompt / multi-user system ready
```

### Why root mounts read-only first

- To reduce corruption risk before filesystem check and recovery.
- After checks pass, system remounts root as read-write.

### Boot / mount debug commands

```bash
findmnt
findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS /
cat /proc/cmdline
journalctl -b -p err
systemd-analyze critical-chain
```
