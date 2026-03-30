# Disk, Storage, and LVM

# Overview
- **Why it exists** —
- **What it is** —
- **One-liner** —

<!-- Your original notes below — reorganize into subsections -->

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
- `-f` → force
- `-n` it treats the symlink itself as a normal file and replaces it. With not it may try to modify what it point to.

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

- see the following [resize-existing](../Shell-script/Disk/resize-existing-lvm.sh)

# Raid
- Redandant Array of Independent Disks (RAID) way to combine multiple physical disk to get more perfomance or more high aviability

### RAID 0

- Combine Disk A and Disk B `Disk A | Disk B`write data in 2 disk independently to get more speed.
- Data is striped across disks (split into blocks and written in parallel).
- Tolerate 0 disk fail.
- 100% of total disk space.
- Performance: Very high read/write performance.
- No redundancy.

### RAID 1

- Mirror Disk A and Disk B `Disk A = Disk B` write same data on 2 disk to get more high aviability.
- Tolerate 1 disk fail.
- 50% usable of total disk space.
- Write performance: Similar to single disk.
- High availability, simple design.

### RAID 5

- Single parity block (3 disk minumum)
- Tolerate 1 disk fail
- Uses block-level striping with distributed parity
- (N − 1) usable of total disk space 

| Disk 1 | Disk 2 | Disk 3 | Data write |
| :----: | :----: | :----: | :--------: |
|   A    |   B    |   P    |  1 write   |
|   C    |   P    |   D    |  2 write   |
|   P    |   E    |   F    |  3 write   |

- A, B, C, D, E, F Are real data block
- P is parity block
- `P = A xor B` if A missing can get back from `A = P xor B`
- Write performance is slower than RAID 0/1 (parity calculation required).
- Rebuild time can be long on large disks.

### RAID 6

- Two independent parity block (4 disk minimum).
- Tolerate 2 disk fail.
- (N − 2) usable of total disk space.

| Disk 1 | Disk 2 | Disk 3 | Disk 4 | Data write |
| :----: | :----: | :----: | :----: | :--------: |
|   A    |   B    |   P    |   Q    |  1 write   |
|   C    |   P    |   Q    |   D    |  2 write   |
|   P    |   Q    |   E    |   F    |  3 write   |

- P, Q are two independent parity block
- Use more advance math
- Slower writes than RAID 5.
- Better protection for large disk arrays.

### RAID 10

- Combine and mirror `(Disk A = Disk B) | (Disk C = Disk D)` to get more high aviability and more speed(4 disk minumum).
- each pair can fail 1 disk.
- 50% usable of total disk space.

### Summary Table

| RAID  | Min Disks | Fault Tolerance | Usable Capacity | Performance |
| :---: | :-------: | :-------------: | :-------------: | :---------: |
|   0   |     2     |        0        |      100%       |  Very High  |
|   1   |     2     |  1 per mirror   |       50%       |  High Read  |
|   5   |     3     |        1        |       N-1       |  Good Read  |
|   6   |     4     |        2        |       N-2       |  Good Read  |
|  10   |     4     |  1 per mirror   |       50%       |  Very High  |

# How to software RAID in linux

[Software-RAID-linux](../Shell-script/Disk/software-raid.sh)

# Ceph

- Software define storage platform that providers block, object, File storage from cluster of server into one logical storage system.
- Core Concept
  - Ceph turns many physical servers into one combine distributed storage system
  - Data is distributed
  - Data is replicated
  - No single point of failure
  - Scales horizontally (just add more nodes)


# Architecture

# Core Building Blocks

### Partitioning
- **Why it exists** —
- **What it is** —
- **One-liner** —

### Swap
- **Why it exists** —
- **What it is** —
- **One-liner** —

### Links
- **Why it exists** —
- **What it is** —
- **One-liner** —

### Disk Usage
- **Why it exists** —
- **What it is** —
- **One-liner** —

### LVM (Logical Volume Manager)
- **Why it exists** —
- **What it is** —
- **One-liner** —

### RAID
- **Why it exists** —
- **What it is** —
- **One-liner** —

### Ceph (Distributed Storage)
- **Why it exists** —
- **What it is** —
- **One-liner** —
