# Linux Core Overview

- Linux is a Unix-like operating system centered around the Linux kernel.
- The kernel is the core layer that controls CPU, memory, devices, filesystem, networking, and process isolation.
- User space tools (shell, systemd, package managers, utilities) interact with the kernel via system calls.


# Linux System Architecture

![linux-architecture](./pic/linux_architecture.PNG)

```text
User Applications (bash, nginx, python, vim)
                    |
                    v
Shell / Service Manager (bash, systemd)
                    |
                    v
System Libraries (glibc)
                    |
                    v
System Calls (open, read, write, fork, execve)
                    |
                    v
Linux Kernel
                    |
                    v
Hardware (CPU, RAM, Disk, NIC)
```

- User space cannot directly touch hardware; it requests the kernel to do it.
- This separation provides stability, isolation, and security.

# User Space vs Kernel Space

- **User space**: where normal applications run with limited privileges.
- **Kernel space**: where kernel code runs with full hardware/system access.
- Applications switch to kernel space via system calls (`open`, `read`, `write`, `fork`, `execve`).
- This isolation prevents one app from directly corrupting the whole system.

# Kernel Responsibilities

- Process scheduling (which process runs, and when).
- Memory management (virtual memory, paging, cache).
- Filesystem management (inodes, mounts, permissions).
- Device drivers (disk, NIC, keyboard, GPU).
- Networking stack (TCP/IP, routing, sockets, firewall hooks).
- Security model (users, groups, capabilities, namespaces, cgroups).

# Linux Mental Model

```text
User runs command
    |
    v
Shell parses command
    |
    v
Program calls system calls
    |
    v
Kernel performs operation
    |
    v
Result returns to stdout/stderr or file/network/device
```

Example:

```bash
cat /etc/hostname
```

- Shell starts `cat` process.
- `cat` calls `open()` + `read()`.
- Kernel reads bytes from filesystem cache/disk.
- `cat` writes output to stdout.


# Core Building Blocks

### Filesystem and Storage

- Linux treats many resources as files (`/dev`, `/proc`, `/sys`).
- Data lives on mounted filesystems under one root tree `/`.
- Important paths:
  - `/etc` config files
  - `/var` variable data (logs, spool, cache)
  - `/home` user data
  - `/proc` process and kernel runtime info
  - `/dev` device files

Related notes:
- [05-file-system-mount](./05-file-system-mount.md)
- [06-disk](./06-disk.md)

### Process Model

- Every running program is a process with a PID.
- Parent/child relation is created by `fork()` and `execve()`.
- Foreground/background jobs are shell-level control.
- `systemd` is usually PID 1 and manages system services.

Related notes:
- [07-process-stat](./07-process-stat.md)
- [09-service-systemctl-socket](./09-service-systemctl-socket.md)

### Users, Groups, and Permissions

- Access control starts with UID, GID, and mode bits (`rwx`).
- Standard classes: owner, group, others.
- Elevated operations use `sudo` (or root).

Related notes:
- [03-user-group-permission](./03-user-group-permission.md)

### Networking Fundamentals

- Applications communicate through sockets.
- Kernel networking chooses routes and interfaces.
- Name resolution flow depends on `/etc/nsswitch.conf` and DNS resolver setup.

Related notes:
- [Networking/000-core](./Networking/000-core.md)
- [Networking/005-dns-resolution-linux](./Networking/005-dns-resolution-linux.md)

### Software and Package Management

- Software is typically installed via distro package manager.
- Package sources, signatures, and dependencies matter for reliability.

Related notes:
- [04-software-distributed](./04-software-distributed.md)

### Observability and Logs

- System behavior is inspected from process stats, logs, and service states.
- Core tools: `ps`, `top`, `journalctl`, `dmesg`, `ss`, `df`, `free`.

Related notes:
- [08-log](./08-log.md)

---

# Practical Command Set (Core)

```bash
# system
uname -a
uptime

# cpu/memory/process
ps aux
top
free -h

# filesystem/disk
lsblk
df -h
mount
/etc/fstab

# networking
ip a
ip r
ss -tulpen

# services/logs
systemctl status <service>
journalctl -u <service> -n 100 --no-pager
```

- These commands cover most first-pass Linux troubleshooting.

# Troubleshooting Guide

```text
Problem: Symptom appears — general diagnostic sequence
    |
    v
[1] Check service state (systemctl)
    |
    v
[2] Check logs (journalctl / log files)
    |
    v
[3] Check process/resources (ps, top, free, df)
    |
    v
[4] Check network/listening ports (ip, ss, route, dns)
    |
    v
[5] Apply fix and verify
```

# Quick Facts (Revision)

- PID 1 is usually `systemd`.
- Exit code `0` means success; non-zero means failure.
- Use `SIGTERM` first, `SIGKILL` only when needed.
- After editing `/etc/fstab`, run `mount -a` before reboot.

# Topic Map

- [001-Basic-file-and-text-manipulation](./001-Basic-file-and-text-manipulation.md) -- ls, cp, mv, rm, cat, grep, find, file operations
- [002-Advance-text-manipulation](./002-Advance-text-manipulation%20copy.md) -- sed, awk, cut, sort, uniq, tr, text processing pipelines
- [003-user-group-permission](./003-user-group-permission.md) -- Users, groups, chmod, chown, sudo, /etc/passwd, /etc/shadow
- [004-software-distributed](./004-software-distributed.md) -- apt, dpkg, yum, tar, wget, package management layers
- [005-file-system-mount](./005-file-system-mount.md) -- Filesystem types, mount, fstab, /proc, /sys, directory hierarchy
- [006-disk](./006-disk.md) -- Partitions, LVM, RAID, fdisk, lsblk, df, du, disk management
- [007-process-stat](./007-process-stat.md) -- ps, top, htop, kill, signals, foreground/background, /proc
- [008-log](./008-log.md) -- journalctl, syslog, /var/log, log rotation, dmesg
- [009-service-systemctl-socket](./009-service-systemctl-socket.md) -- systemd, systemctl, unit files, socket activation, targets
- [010-shell-environment-and-path](./010-shell-environment-and-path.md) -- PATH, env variables, .bashrc, .profile, login vs non-login shells
- [011-task-scheduling-cron](./011-task-scheduling-cron.md) -- cron, crontab, at, systemd timers, scheduled jobs
- [012-network-storage](./012-network-storage.md) -- NFS, iSCSI, SMB/CIFS, SAN vs NAS, multipath, autofs
- [Networking/000-core](./Networking/000-core.md) -- Linux networking: interfaces, ip, routes, sockets, DNS, firewall, namespaces
