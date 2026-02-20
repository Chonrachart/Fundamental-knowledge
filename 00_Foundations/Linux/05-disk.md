# Swap
Swap is virtual memory on disk.
Used when RAM is full. Slower than RAM.

```bash
free -h
swapon --show
```

- `free -h` show RAM and swap usage.
- `swapon --show` show active swap.

### Create and Disable Swap

```bash
mkswap /dev/sdX1
swapon /dev/sdX1
```
- `mkswap` prepare partition as swap.
- `swapon` enable swap.

```bash
swapoff /dev/sdX1
```
- `swapoff` disable swap.

# Link

- Link creates another reference to a file.
- Two types:
  - Hard Link
  - Soft Link (Symbolic Link)

![soft-link-vs-hard-link](./pic/soft_link_vs_hard_link.png)
### Hard link

```bash
ln <source_file> <hard_link_name>
```
- Creates another name for the same file.
- Shares the same inode.
- If original file is deleted, hard link still works.
- Use `ls -li` to check innode(number in first column). If inode number is same → hard link.
- Cannot link directories.

### Soft link

```bash
ln -s <source_file> <hard_link_name>
```
- Creates a shortcut to the original file.
- Has different inode.
- Points to file path, not inode.
- If original file is deleted, link becomes broken.


# Disk Usage

```bash
du -h [dir]
df -h
```
- `du -h [dir]` check disk usage of directory.
- `df -h` check free disk space.

# LVM (Logical Volume Manager)

- LVM is a storage management system in Linux.
- Abstracts physical disks into logical storage.
- It allows flexible disk management.

### Why Use LVM
- Resize partitions easily.
- Combine multiple disks into one volume.
- Take snapshots.
- Better flexibility than traditional partitions.

### Components of LVM
- LVM has 3 main layers
- Physical Volume (PV) Physical disk or partition prepared for LVM.
  - Volume Group (VG) Pool of storage created from one or more PVs.
  - Logical Volume (LV) Virtual partition created from VG.This is what you
    format and mount.

![LVM](./pic/LVM.png)

- Flow `Disk → PV → VG → LV → mkfs → mount`

### How to Check LVM
```bash
pvs
vgs
lvs
```
- `pvs` show physical volumes
- `vgs` show volume groups
- `lvs` show logical volumes

Detailed view:
```bash
pvdisplay
vgdisplay
lvdisplay
```

### Create LVM
```bash
pvcreate [partition-prepare-for-LVM]
vgcreate [vg-name] [partiion]
lvcreate -L 5G -n [lv_name] [vg_name]
```
- `-L` size
- `-n` name

### To resize the existing LVM disk

- see the following [resize-existing] 

# Raid
# Ceph