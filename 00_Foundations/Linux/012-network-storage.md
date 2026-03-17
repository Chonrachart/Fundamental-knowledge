# Network Storage

- Network storage provides access to files or block devices over the network, decoupling compute from storage.
- NFS serves files; SMB/CIFS for Windows interop; iSCSI serves block devices; multipath provides redundancy and performance.
- Key distinction: NAS (file-level via NFS/SMB) vs SAN (block-level via iSCSI), each with different mount and access patterns.

# Architecture

```text
                    Network Storage Infrastructure

+------------------+              +------------------+
| NAS Server       |              | SAN Target       |
| (File-based)     |              | (Block-based)    |
| - NFS exports    |              | - iSCSI LUNs     |
| - SMB shares     |              | - Multiple paths |
+------------------+              +------------------+
        |                                 |
        | NFS/SMB protocols               | iSCSI protocol
        | (mount as filesystem)           | (block device)
        |                                 |
+------------------+              +------------------+
| Linux Client 1   |              | Linux Client 2   |
| /mnt/nas         |              | /dev/mapper/mp0  |
+------------------+              +------------------+
        |                                 |
        | (optional)                      | (optional)
        v                                 v
   autofs daemon              multipath daemon
   (on-demand mount)          (path failover)
```

# Mental Model

```text
NFS (Network File System) flow:
  [1] Server exports directory in /etc/exports
  [2] Client mounts via mount -t nfs server:/exported/path /mnt/nfs
  [3] Client reads/writes files; server handles storage
  [4] Root access controlled via root_squash (client root -> server nobody)

SMB (Samba) flow:
  [1] Server configures shares in smb.conf
  [2] Client mounts via mount -t cifs //server/share /mnt/smb -o credentials=file
  [3] Uses credentials for authentication (Windows-style)

iSCSI (SCSI over IP) flow:
  [1] Target exports LUN (Logical Unit Number) with IQN name
  [2] Initiator discovers target via iscsiadm (port 3260)
  [3] Initiator logs in to LUN; appears as /dev/sd* block device
  [4] Can create LVM/filesystems on iSCSI block device
  [5] Multipath daemon aggregates multiple paths to same LUN
```

Example: NFS mount with fstab
```bash
# /etc/fstab entry
nfs-server.example.com:/export/data  /mnt/nfs  nfs  defaults,vers=4,rsize=1048576,wsize=1048576  0  0

# /etc/exports on server
/export/data  192.168.1.0/24(rw,sync,no_root_squash,no_subtree_check)
```

# Core Building Blocks

### NFS (Network File System)

- NFSv3: stateless protocol, older, simpler; no authentication beyond UID/GID.
- NFSv4: stateful, includes Kerberos auth, ACLs, referrals, better over WAN; preferred on modern systems.
- Server exports directories in `/etc/exports`; format: `<path> <client-spec>(<options>)`.
- Client mounts via `mount -t nfs -o vers=4 server:/path /mnt` or fstab entry.
- Common options:
  - `root_squash` (default): remote root (UID 0) becomes nobody (65534).
  - `no_root_squash`: client root retains UID 0 on server (dangerous).
  - `sync`: server commits to disk before replying (safe); `async` replies before disk write (faster, risky).
  - `vers=4`: use NFSv4 (default if server supports it).
- Commands:
  - `showmount -e <nfs-server>` — list exports.
  - `mount | grep nfs` — show active NFS mounts.
  - `/etc/fstab` entry example: `server:/path /mnt nfs vers=4,rsize=1048576,wsize=1048576,_netdev 0 0`.

Related notes: [005-file-system-mount](./005-file-system-mount.md), [006-disk](./006-disk.md)

### SMB/CIFS (Samba)

- SMB (Server Message Block) is the Windows filesharing protocol; Samba is the Linux implementation.
- Used for Linux-Windows interoperability; also works Linux-to-Linux.
- Server config in `/etc/smb.conf`; defines shares with paths, permissions, guest access.
- Client mounts via `mount -t cifs //server/share /mnt -o username=user,password=pass,uid=1000,gid=1000`.
- Credentials file: store in `~/.cifs_credentials` (mode 600): `username=user\npassword=pass`.
- `/etc/fstab` entry: `//server/share /mnt cifs credentials=~/.cifs_credentials,uid=1000,gid=1000,file_mode=0755,dir_mode=0755 0 0`.
- Permissions: SMB uses ACLs; Linux client maps to Unix ownership via `uid=` and `gid=` options.

Related notes: [005-file-system-mount](./005-file-system-mount.md), [009-service-systemctl-socket](./009-service-systemctl-socket.md)

### iSCSI (Internet Small Computer System Interface)

- iSCSI is a network storage protocol that allows a computer to access remote block storage over an IP network.
- SCSI is the protocol your OS uses to talk to local disks (`/dev/sda`). iSCSI wraps those same SCSI commands inside TCP/IP packets so you can access a remote disk over the network as if it were plugged in locally.
- The result: a disk on a server in the data center appears as `/dev/sdb` on your machine. You can partition it, format it, mount it -- exactly like a local drive.

**Key terms:**

| Term | What it is | Analogy |
|------|-----------|---------|
| **Target** | The storage server that exports disk(s) | The USB drive you plug in |
| **Initiator** | Your client machine that connects to the target | The USB port on your laptop |
| **LUN** (Logical Unit Number) | A specific disk/volume exported by the target (LUN 0, LUN 1, ...) | A partition on the USB drive |
| **IQN** (iSCSI Qualified Name) | A globally unique name for each target, like `iqn.2024-03.example.com:storage.lun0` | Like a MAC address for storage |
| **Portal** | The target's IP + port (default 3260) | The network address to connect to |

**How it works step by step:**

```text
Your server (initiator)                    Storage server (target)
        |                                          |
        |  [1] DISCOVER: "what LUNs do you have?"  |
        |  iscsiadm -m discovery -t sendtargets    |
        |  -p 10.0.1.50                            |
        | ---------------------------------------->|
        |                                          |
        |  [2] Target replies: here are my IQNs    |
        |  iqn.2024-03.example.com:storage.lun0    |
        |<---------------------------------------- |
        |                                          |
        |  [3] LOGIN: "I want to use that LUN"     |
        |  iscsiadm -m node -T <IQN> -p 10.0.1.50 -l
        | ---------------------------------------->|
        |                                          |
        |  [4] Target maps LUN to your session     |
        |<---------------------------------------- |
        |                                          |
        |  Now /dev/sdb appears on your machine    |
        |  You can: mkfs.ext4 /dev/sdb             |
        |           mount /dev/sdb /mnt/data       |
        |  Treat it like a local disk.             |
```

**Why use iSCSI instead of NFS?**
- NFS gives you a **folder** (file-level access); iSCSI gives you a **raw disk** (block-level access).
- Databases (MySQL, PostgreSQL) perform better on block devices because they control the filesystem directly.
- You can run LVM, create partitions, or even run a VM disk image on iSCSI -- things you cannot do on an NFS mount.

**Persistent login** (survives reboot):
```bash
# after first login, set startup mode to automatic
iscsiadm -m node -T <IQN> -p <target-ip> --op update -n node.startup -v automatic
# now the LUN reconnects on boot
```

**Common workflow:**
```bash
# 1. install initiator tools
apt install open-iscsi        # Debian/Ubuntu
yum install iscsi-initiator-utils  # RHEL/CentOS

# 2. discover targets
iscsiadm -m discovery -t sendtargets -p 10.0.1.50

# 3. login
iscsiadm -m node -T iqn.2024-03.example.com:storage.lun0 -p 10.0.1.50 -l

# 4. verify -- new block device appears
lsblk   # you'll see a new /dev/sdb (or similar)

# 5. use it like any disk
mkfs.ext4 /dev/sdb
mkdir -p /mnt/iscsi-data
mount /dev/sdb /mnt/iscsi-data

# 6. add to fstab (use _netdev so it waits for network)
echo '/dev/sdb  /mnt/iscsi-data  ext4  _netdev  0  0' >> /etc/fstab
```

Related notes: [006-disk](./006-disk.md), [005-file-system-mount](./005-file-system-mount.md)

### SAN vs NAS

| Aspect          | SAN (Storage Area Network)      | NAS (Network-Attached Storage)     |
| :-------------- | :------------------------------ | :--------------------------------- |
| Protocol        | iSCSI, Fibre Channel (FC)       | NFS, SMB, HTTP                     |
| Access level    | Block (raw disk/LVM)            | File (filesystem)                  |
| Mount point     | `/dev/sd*`, `/dev/mapper/*`     | `/mnt/nfs`, `/mnt/smb`             |
| Filesystem      | Server or client manages        | Server manages; client just accesses |
| Redundancy      | Multipath I/O aggregates paths  | NFS/SMB handles failover; may need VRRP |
| Use case        | Databases, high-performance IO  | General file sharing, VM storage   |
| Complexity      | Higher (must understand LVM)    | Lower (mount and use)              |

Related notes: [006-disk](./006-disk.md)

### Multipath I/O (MPIO)

- Multipath aggregates multiple network paths to a single iSCSI LUN into one logical device.
- Provides redundancy: if one path fails, others continue; transparent to application.
- Provides performance: load-balance I/O across multiple paths.
- Tool: `device-mapper-multipath` (kernel device-mapper + user-space daemon).
- Config file: `/etc/multipath.conf`; defines failover policy (round-robin, service-time, etc.).
- Commands:
  - `multipath -ll` — list all multipath devices (shows paths, status).
  - `multipathd status` — check daemon.
  - `multipathd reconfigure` — reload config.
- Device naming: `/dev/mapper/mpath*` (logical), `/dev/sd*` (underlying paths hidden).

Related notes: [006-disk](./006-disk.md)

### autofs (Automounter)

- autofs mounts filesystems on-demand: resource is mounted only when accessed, unmounted when idle (timeout).
- More efficient than static fstab: avoids mounting at boot if never used; unmounts to free resources.
- Components: `auto.master` (master map) + service maps (`auto.nfs`, `auto.smb`, etc.).
- Format example:
  ```
  /mnt/auto/nfs  /etc/auto.nfs  --timeout=300
  /mnt/auto/smb  /etc/auto.smb  --timeout=300
  ```
- Service map (`/etc/auto.nfs`): `<dirname> -fstype=nfs,vers=4 <server>:<path>`
- Wildcard map example: `*  -fstype=nfs,vers=4  nfs-server:/exports/&` (mounts `/mnt/auto/nfs/<dirname>` to `/exports/<dirname>`).
- Reload: `systemctl reload autofs`.
- Logs: `journalctl -u autofs -n 50`.

Related notes: [005-file-system-mount](./005-file-system-mount.md)

### LVM on Network Storage

- LVM (Logical Volume Manager) can run on iSCSI block devices as if they were local disks.
- Workflow:
  - iSCSI initiator logs in; LUN appears as `/dev/sd*`.
  - Create physical volume: `pvcreate /dev/sd*`.
  - Create volume group: `vgcreate vg_network /dev/sd*`.
  - Create logical volumes: `lvcreate -L 100G -n lv_data vg_network`.
  - Create filesystem: `mkfs.ext4 /dev/vg_network/lv_data`.
- Thin provisioning: allocated space is virtual; actual disk space grows on-demand (saving space, but risk overrun).
- Extend volume: `lvextend -L +50G /dev/vg_network/lv_data` (grow LV), then `resize2fs /dev/vg_network/lv_data` (grow filesystem).
- Snapshots: useful for backups without downtime (read-only or read-write copy).

Related notes: [006-disk](./006-disk.md)

---

# Practical Command Set (Core)

```bash
# NFS
showmount -e <nfs-server>                                  # list server exports
mount -t nfs -o vers=4,rsize=1m,wsize=1m <server>:/path /mnt  # mount NFS
umount /mnt                                                # unmount
mount | grep nfs                                           # show NFS mounts
exportfs -ra                                               # reload /etc/exports on server

# SMB/CIFS
mount -t cifs //<server>/<share> /mnt -o username=user,password=pass
mount -t cifs //<server>/<share> /mnt -o credentials=~/.cifs_credentials,uid=1000,gid=1000
umount /mnt

# iSCSI
iscsiadm -m discovery -t sendtargets -p <target-ip>      # discover targets
iscsiadm -m node -L all                                    # list discovered nodes
iscsiadm -m node -T <IQN> -p <target-ip> -l               # login to target
iscsiadm -m node -T <IQN> -p <target-ip> -u               # logout
iscsiadm -m session -P 3                                   # show active sessions (verbose)
lsblk | grep iscsi                                         # list iSCSI block devices

# Multipath
multipath -ll                                              # list all multipath devices + paths
multipath -a <device>                                      # add device to multipath
multipathd status                                          # daemon status
multipathd reconfigure                                     # reload /etc/multipath.conf

# autofs
systemctl status autofs                                    # check autofs daemon
systemctl reload autofs                                    # reload /etc/auto.master
journalctl -u autofs -n 50 --no-pager                     # autofs logs

# LVM (on network storage)
pvcreate /dev/sd*                                          # initialize physical volume
vgcreate <vg-name> /dev/sd*                                # create volume group
lvcreate -L 100G -n <lv-name> <vg-name>                    # create logical volume
lvextend -L +50G /dev/vg/<lv-name>                         # extend LV
resize2fs /dev/vg/<lv-name>                                # grow ext4 filesystem
lvs / vgs / pvs                                            # list volumes / groups / physical
```

# Troubleshooting Guide

```text
Problem: NFS mount fails with "mount.nfs: Permission denied"
    |
    v
[1] Is the NFS server exporting to your client?
    showmount -e <nfs-server>
    |
    +-- /export/path not listed --> add to /etc/exports, run exportfs -ra
    |
    v
[2] Does the export rule match your client IP?
    /etc/exports: /export/path  192.168.1.0/24(rw)
    |
    +-- no match --> update /etc/exports, run exportfs -ra
    |
    v
[3] Is the NFS server listening?
    ss -tulnp | grep :2049
    |
    +-- not listening --> systemctl start nfs-server
    |
    v
[4] Check firewall (port 111, 2049)
    firewall-cmd --list-all
    |
    +-- ports blocked --> open ports on server firewall
```

```text
Problem: SMB/CIFS mount fails with "Permission denied" or "Bad password"
    |
    v
[1] Test credentials locally on server
    smbclient -L //<server>/ -U <user>
    |
    +-- fails --> user/password wrong or server not running
    |
    v
[2] Check Samba is running on server
    systemctl status smbd
    |
    +-- not running --> systemctl start smbd
    |
    v
[3] Check share exists in /etc/smb.conf
    grep -A5 '\[<share>\]' /etc/smb.conf
    |
    +-- not found --> add share, run testparm, systemctl reload smbd
    |
    v
[4] Verify credentials file (mode 600) or inline -o options
    ls -la ~/.cifs_credentials
    |
    +-- wrong mode --> chmod 600 ~/.cifs_credentials
```

```text
Problem: iSCSI target not discovered or login fails
    |
    v
[1] Can you reach the target IP?
    ping <target-ip>
    |
    +-- no response --> check network, firewall, target IP
    |
    v
[2] Is iSCSI port 3260 open?
    nc -zv <target-ip> 3260
    |
    +-- timeout/refused --> firewall or target not listening
    |
    v
[3] Run discovery again
    iscsiadm -m discovery -t sendtargets -p <target-ip>
    |
    +-- no targets found --> check target service on server
    |
    v
[4] Check iscsid daemon
    systemctl status iscsid
    |
    +-- not running --> systemctl start iscsid
    |
    v
[5] Manually login to node
    iscsiadm -m node -T <IQN> -p <target-ip> -l
    |
    +-- login error --> check target logs, authentication
```

```text
Problem: Multipath device not created or paths not showing
    |
    v
[1] Are iSCSI initiators logged in?
    iscsiadm -m session -P 3 | grep "Attached scsi"
    |
    +-- no sessions --> login to targets first
    |
    v
[2] Are underlying sd* devices visible?
    lsblk | grep -E "^sd"
    |
    +-- no sd devices --> iSCSI login missing
    |
    v
[3] Is multipathd running?
    systemctl status multipathd
    |
    +-- not running --> systemctl start multipathd
    |
    v
[4] Reload multipath config
    multipath -r
    multipath -ll
    |
    +-- still no devices --> check /etc/multipath.conf (wwn matching rules)
```

```text
Problem: autofs mount on-demand not working
    |
    v
[1] Is autofs daemon running?
    systemctl status autofs
    |
    +-- not running --> systemctl start autofs
    |
    v
[2] Check /etc/auto.master syntax
    cat /etc/auto.master
    |
    +-- error in format --> fix format: <mount-point> <service-map-file> <options>
    |
    v
[3] Check service map (/etc/auto.nfs)
    cat /etc/auto.nfs
    |
    +-- unreachable paths --> test NFS mount manually
    |
    v
[4] Reload autofs and test
    systemctl reload autofs
    ls /mnt/auto/nfs/<dirname>  (should trigger mount)
    mount | grep autofs
    |
    +-- not mounted --> check journalctl -u autofs for errors
```

```text
Problem: LVM extend fails on iSCSI LUN
    |
    v
[1] Is the iSCSI device still connected?
    iscsiadm -m session -P 3
    lsblk | grep iscsi
    |
    +-- disconnected --> login to target again
    |
    v
[2] Is there free space in the volume group?
    vgs -o vg_name,size,free
    |
    +-- no free space --> extend underlying iSCSI LUN on target side first
    |
    v
[3] Rescan iSCSI device for new size
    echo 1 > /sys/class/scsi_device/<device:bus:target:lun>/device/rescan
    |
    v
[4] Extend logical volume
    lvextend -L +50G /dev/vg/<lv-name>
    |
    v
[5] Grow filesystem
    resize2fs /dev/vg/<lv-name>
    df -h /mnt
    |
    +-- size unchanged --> check filesystem, may need fsck
```

# Quick Facts (Revision)

- NFS: stateless file protocol; NFSv4 preferred; `root_squash` prevents client root from being server root.
- SMB/CIFS: Windows file-sharing protocol; needs credentials (username/password); common on Linux-Windows networks.
- iSCSI: block storage over TCP/IP; LUN = numbered export; IQN = unique name; requires initiator login.
- SAN (iSCSI) = block storage; NAS (NFS/SMB) = file storage; SAN more complex, NAS easier.
- Multipath aggregates multiple paths to same iSCSI LUN; provides redundancy and load-balance.
- autofs mounts on-demand with timeout; more efficient than static fstab if mounts rarely used.
- LVM on iSCSI works like local LVM; can extend LUN and resize LV/filesystem online.
- fstab mount options: `_netdev` tells kernel to mount after networking is ready (critical for network storage).
