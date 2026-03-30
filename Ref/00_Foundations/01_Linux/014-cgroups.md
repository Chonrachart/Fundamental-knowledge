# Cgroups (Control Groups)

- Cgroups are a Linux kernel feature that organises processes into hierarchical groups and enforces per-group resource limits (CPU, memory, I/O, PIDs).
- They exist so the kernel can partition hardware resources among workloads, preventing any single process group from starving others.
- Key property: cgroups are hierarchical — child groups inherit and are further constrained by the limits of their parent group.


# Architecture

```text
/sys/fs/cgroup/                         <-- cgroup v2 unified mount point
├── cgroup.controllers                  <-- available controllers (cpu, memory, io, pids, ...)
├── cgroup.subtree_control              <-- controllers enabled for children
├── system.slice/                       <-- systemd services
│   ├── nginx.service/
│   │   ├── cgroup.procs                <-- PIDs in this cgroup
│   │   ├── cpu.max                     <-- CPU bandwidth limit
│   │   ├── memory.max                  <-- hard memory limit
│   │   ├── memory.current              <-- current memory usage
│   │   ├── io.max                      <-- I/O bandwidth limit
│   │   └── pids.max                    <-- max number of processes
│   └── sshd.service/
│       └── ...
├── user.slice/                         <-- user sessions
│   └── user-1000.slice/
│       └── ...
└── my-custom-group/                    <-- manually created cgroup
    ├── cgroup.procs
    ├── cpu.max
    └── memory.max
```

- Each directory under `/sys/fs/cgroup/` is a cgroup; the files inside are controller interfaces.
- systemd automatically creates slices (`system.slice`, `user.slice`) and places services into them.


# Mental Model

```text
1. Admin creates cgroup directory
   mkdir /sys/fs/cgroup/my-app
              |
              v
2. Enable controllers for the new cgroup
   echo "+cpu +memory" > /sys/fs/cgroup/cgroup.subtree_control
              |
              v
3. Set resource limits via controller files
   echo "100000 100000" > /sys/fs/cgroup/my-app/cpu.max      (100% of 1 CPU)
   echo "512M"          > /sys/fs/cgroup/my-app/memory.max    (512 MB RAM cap)
              |
              v
4. Move process into the cgroup
   echo 1234 > /sys/fs/cgroup/my-app/cgroup.procs
              |
              v
5. Kernel enforces limits
   - Process 1234 cannot exceed 1 CPU or 512 MB
   - If memory.max is hit → OOM kill within this cgroup
   - Child processes inherit the same cgroup (and its limits)
```


# Core Building Blocks

### What Are Cgroups

- A cgroup is a named group of processes managed as a unit for resource accounting and limiting.
- Resource controllers (cpu, memory, io, pids) are kernel subsystems that enforce limits on cgroups.
- Every process belongs to exactly one cgroup; the mapping is visible at `/proc/<PID>/cgroup`.
- cgroups provide three capabilities:
  - **Resource limiting** — cap CPU time, memory, I/O bandwidth, process count
  - **Prioritisation** — weight-based sharing (e.g., `cpu.weight`)
  - **Accounting** — track resource consumption per group (`memory.current`, `cpu.stat`)

Related notes:
- [007-process-stat](./007-process-stat.md) — process states, `/proc/<PID>/` files, and basic cgroup overview


### cgroup v2 (Unified Hierarchy)

- cgroup v2 uses a single hierarchy mounted at `/sys/fs/cgroup/` (unlike v1 which had separate trees per controller).
- Controllers are enabled per-subtree by writing to `cgroup.subtree_control` in the parent directory.
- Only leaf cgroups (those with no children) can have processes — this prevents ambiguous resource accounting.
- Check if cgroup v2 is active: `mount | grep cgroup2` or `stat -fc %T /sys/fs/cgroup/` (returns `cgroup2fs`).

```bash
# See which controllers are available
cat /sys/fs/cgroup/cgroup.controllers

# Enable cpu and memory controllers for child cgroups
echo "+cpu +memory +io +pids" > /sys/fs/cgroup/cgroup.subtree_control

# Verify enabled controllers
cat /sys/fs/cgroup/cgroup.subtree_control
```

- Controller delegation: non-root users can manage cgroups if the parent cgroup delegates control via `cgroup.subtree_control` and file ownership.

Related notes:
- [007-process-stat](./007-process-stat.md) — `/proc/self/cgroup` shows which cgroup the current process belongs to


### Key Controllers

**cpu** — limits CPU time and sets scheduling weights.

| File | Purpose | Example |
|------|---------|---------|
| `cpu.max` | Bandwidth limit: `QUOTA PERIOD` (microseconds) | `50000 100000` = 50% of 1 CPU |
| `cpu.weight` | Proportional share (1-10000, default 100) | `200` = double the default share |
| `cpu.stat` | Usage statistics (usage_usec, etc.) | read-only |

```bash
# Limit to 50% of one CPU core
echo "50000 100000" > /sys/fs/cgroup/my-app/cpu.max

# Give this group twice the default CPU weight
echo 200 > /sys/fs/cgroup/my-app/cpu.weight
```

**memory** — limits RAM and swap usage, triggers OOM within the cgroup.

| File | Purpose | Example |
|------|---------|---------|
| `memory.max` | Hard memory limit (bytes, or suffixes K/M/G) | `536870912` or `512M` |
| `memory.current` | Current usage (read-only) | |
| `memory.high` | Throttle threshold (soft limit) | `256M` |
| `memory.swap.max` | Swap limit | `0` = no swap |
| `memory.events` | OOM, OOM kill counts (read-only) | |

```bash
# Set hard memory limit to 512 MB, no swap
echo 512M > /sys/fs/cgroup/my-app/memory.max
echo 0    > /sys/fs/cgroup/my-app/memory.swap.max

# Check current memory usage
cat /sys/fs/cgroup/my-app/memory.current
```

**io** — limits block I/O bandwidth per device.

| File | Purpose | Example |
|------|---------|---------|
| `io.max` | Per-device BW cap: `MAJ:MIN rbps=X wbps=X` | `8:0 rbps=10485760 wbps=5242880` |
| `io.weight` | Proportional I/O share (1-10000) | `500` |
| `io.stat` | Per-device I/O statistics (read-only) | |

```bash
# Limit device 8:0 (sda) to 10 MB/s read, 5 MB/s write
echo "8:0 rbps=10485760 wbps=5242880" > /sys/fs/cgroup/my-app/io.max

# Find device major:minor number
lsblk -o NAME,MAJ:MIN
```

**pids** — limits the number of processes/threads in a cgroup.

| File | Purpose | Example |
|------|---------|---------|
| `pids.max` | Maximum number of PIDs | `100` |
| `pids.current` | Current PID count (read-only) | |

```bash
# Limit to 100 processes
echo 100 > /sys/fs/cgroup/my-app/pids.max
```

Related notes:
- [007-process-stat](./007-process-stat.md) — process resource limits, `/proc/<PID>/limits`, ulimit


### Managing Cgroups

**Creating and assigning cgroups manually:**

```bash
# Create a new cgroup
mkdir /sys/fs/cgroup/my-app

# Enable controllers (from parent)
echo "+cpu +memory" > /sys/fs/cgroup/cgroup.subtree_control

# Set limits
echo "50000 100000" > /sys/fs/cgroup/my-app/cpu.max
echo 256M           > /sys/fs/cgroup/my-app/memory.max

# Move a running process into the cgroup
echo 1234 > /sys/fs/cgroup/my-app/cgroup.procs

# Remove a cgroup (must be empty — no processes, no children)
rmdir /sys/fs/cgroup/my-app
```

**Inspection commands:**

```bash
# Show cgroup for a specific process
cat /proc/<PID>/cgroup

# Show cgroup for the current shell
cat /proc/self/cgroup

# List all processes in a cgroup
cat /sys/fs/cgroup/system.slice/nginx.service/cgroup.procs

# Tree view of all cgroups and their processes
systemd-cgls

# Real-time resource usage per cgroup (like top for cgroups)
systemd-cgtop

# Show systemd slice/cgroup for a service
systemctl show nginx.service | grep -E 'Slice|ControlGroup'
```

Related notes:
- [009-service-systemctl-socket](./009-service-systemctl-socket.md) — systemd service units and cgroup slices


### cgroup v1 vs v2 Comparison

| Aspect | cgroup v1 | cgroup v2 |
|--------|-----------|-----------|
| Hierarchy | Multiple (one per controller) | Single unified tree |
| Mount point | `/sys/fs/cgroup/<controller>/` | `/sys/fs/cgroup/` |
| Controller activation | Per-mount (each controller has own tree) | `cgroup.subtree_control` in parent dir |
| Process placement | Processes in any node | Processes only in leaf nodes |
| Thread-level control | Limited | `cgroup.type threaded` for per-thread control |
| Delegation | Difficult, inconsistent | Clean ownership model |
| Hybrid mode | N/A | Possible (v1 + v2 coexist during migration) |
| Adoption | Legacy, still default on older distros | Default on RHEL 9+, Ubuntu 22.04+, Fedora 31+ |

- Check which version is active: `stat -fc %T /sys/fs/cgroup/` returns `cgroup2fs` (v2) or `tmpfs` (v1).
- Hybrid mode: some controllers on v1, others on v2 — common during migration periods.


### Cgroups and Containers

- Docker, Podman, and Kubernetes all use cgroups under the hood to enforce resource limits on containers.
- Container runtime flags map directly to cgroup controller files:
  - `docker run --memory=512m` writes to `memory.max`
  - `docker run --cpus=1.5` writes to `cpu.max` (150000 100000)
  - `docker run --pids-limit=100` writes to `pids.max`
- In Kubernetes, `resources.limits.memory` and `resources.limits.cpu` in a Pod spec translate to cgroup limits applied by the container runtime (containerd/CRI-O).

Related notes:
- [007-process-stat](./007-process-stat.md) — cgroups as process resource boundaries
