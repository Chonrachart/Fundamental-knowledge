# Filesystem and Mounting

- A filesystem defines how data is stored and organised on a block device (disk/partition).
- Linux exposes all storage under one unified root tree `/`; partitions are attached by mounting.
- `/etc/fstab` tells the kernel which filesystems to mount automatically at boot.


# VFS and Mount Architecture

```text
User space: open("/data/file.txt")
        |
        v
VFS (Virtual Filesystem Switch) — kernel abstraction layer
        |
        v
Filesystem driver (ext4 / xfs / zfs / tmpfs / nfs…)
        |
        v
Block device layer  (/dev/sda1, /dev/sdb1, /dev/mapper/vg-lv)
        |
        v
Physical storage (SSD / HDD / NFS server / RAM)

Mount table (kernel):
  /          → /dev/sda1  (ext4)
  /data      → /dev/sdb1  (xfs)
  /tmp       → tmpfs      (RAM)
  /proc      → procfs     (virtual)
```

- VFS allows the same `open/read/write` syscalls to work on any filesystem type.
- A mount point is a directory; the mounted filesystem replaces its contents.


# Mental Model: Boot and Mount Sequence

```text
1. Power on
2. BIOS/UEFI initializes hardware
3. Bootloader (GRUB) loads kernel + initramfs into RAM
4. Kernel starts, loads essential drivers
5. initramfs locates real root filesystem (by UUID or device name)
6. Root (/) mounts read-only first
7. fsck runs (pass= field in fstab controls order)
8. Root remounts read-write
9. Other filesystems mount from /etc/fstab (in listed order)
10. systemd (PID 1) starts targets and services
11. Login prompt ready
```

Root mounts read-only first to allow fsck to check and repair before writes begin.


# Core Building Blocks

### Filesystem Types

| Type | Best For | Notes |
|---|---|---|
| ext4 | General-purpose Linux | Default on most distros; stable, widely supported |
| xfs | Large files, high I/O | Default on RHEL; grows online; good for databases |
| zfs | Data integrity, backups | Built-in RAID + checksums + snapshots; high RAM usage |
| tmpfs | Temp data in RAM | Fast; data lost on reboot; used for `/tmp`, `/run` |
| nfs | Network-shared storage | Remote filesystem over network |

### Disk Partitions

```bash
lsblk               # show disks and partitions in tree view
lsblk -f            # include filesystem type and UUID
fdisk -l            # list all disks and partitions (MBR)
parted -l           # list all disks (MBR + GPT)
blkid               # show UUID and filesystem type per device
```

Partition table types:
- **MBR** — max 4 primary partitions, max 2 TB disk.
- **GPT** — unlimited partitions, supports disks >2 TB; modern standard.

### Create Filesystem

```bash
mkfs.ext4 /dev/sdb1         # format partition as ext4
mkfs.xfs  /dev/sdb1         # format partition as xfs
mkfs -t ext4 /dev/sdb1      # generic form
```

- Formatting destroys existing data on the partition — confirm device name first.

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

### Permanent Mounting (/etc/fstab)

```bash
# Format:
<device>  <mount_point>  <fs_type>  <options>  <dump>  <pass>

# Examples:
UUID=abcd-1234   /data   ext4   defaults   0   2
/dev/sdb1        /data   xfs    defaults   0   2
tmpfs            /tmp    tmpfs  defaults   0   0
```

- Use **UUID** (not `/dev/sdX`) — device names can change after reboot.
- Find UUID with: `blkid /dev/sdb1`

`<dump>` — backup flag (almost always `0`).
`<pass>` — fsck order: `1` = root, `2` = other local fs, `0` = skip.

Common mount options:

| Option | Meaning |
|---|---|
| `defaults` | rw, suid, dev, exec, auto, nouser, async |
| `ro` | read-only |
| `noexec` | prevent execution of binaries |
| `noatime` | don't update access time (performance) |
| `nofail` | don't fail boot if device is missing |

**After editing fstab — always test before reboot:**

```bash
mount -a        # mount all fstab entries; errors show immediately
findmnt --verify
```

Related notes:
- [06-disk](./06-disk.md) — LVM, RAID, swap
- [09-service-systemctl-socket](./09-service-systemctl-socket.md) — systemd mounts as units

---

# Troubleshooting Guide

```text
Problem: Mount fails with "wrong fs type" or "can't read superblock"
    |
    v
[1] lsblk -f  →  confirm filesystem type matches what you're mounting
    |
    v
[2] blkid /dev/sdX  →  verify UUID and fs type

---

Problem: "Device is busy" on umount
    |
    v
[1] lsof +D <mountpoint>  or  fuser -m <mountpoint>  →  find blocking process

---

Problem: System drops into emergency mode on boot
    |
    v
[1] fstab error — boot with root read-only, edit /etc/fstab, run mount -a to test

---

Problem: df -h shows 100% disk usage
    |
    v
[1] du -sh /* | sort -rh | head  →  find large directories
    |
    v
[2] df -i  →  check if inode exhaustion (not disk space) is the real issue
```


# Quick Facts (Revision)

- Use UUID in fstab, not `/dev/sdX` — device names are not stable across reboots.
- After editing fstab, always run `mount -a` to validate before rebooting.
- A wrong fstab entry can drop the system into emergency mode at boot.
- `tmpfs` mounts live in RAM — data is lost on reboot (correct for `/tmp`).
- `df -h` shows space usage; `df -i` shows inode usage — both can hit 100%.
- Root mounts read-only at boot first to allow fsck to check for corruption.
- `nofail` in fstab options prevents boot failure if a non-critical device is missing.
