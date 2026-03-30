# Services, systemctl, and Sockets

# Overview
- **What it is** — systemd is the service manager and initialization system used by most modern Linux distributions. When Linux boots, the kernel starts systemd as `PID 1`. `systemctl` is the main command used to interact with systemd.

- It is responsible for:
  - starting the system during boot
  - managing background services
  - controlling system processes
  - handling logging and system states

# Architecture

# Core Building Blocks

### systemctl Commands

- A service is a background process that runs on a system to provide functionality.
- Services usually start automatically during system boot.
- Examples: web servers, database servers, SSH remote access, monitoring agents

```bash
systemctl status <service>
systemctl start <service>
systemctl stop <service>
systemctl restart <service>
systemctl reload <service>
systemctl enable <service>
systemctl disable <service>
systemctl daemon-reload
systemctl list-unit --type=service
systemctl --failed
systemctl reboot
systemctl poweroff
systemctl suspend
```

- `enable` run this service on boot.
- `systemctl --failed` this check only failed service
- `systemctl daemon-reload` systemd reads unit files and keep them cached in memory use this command to reload cached
  - use when edit a service file
  - create new service file
- `systemctl list-unit --type=service` this list all service

### Unit File Structure

#### Common locations
```bash
# Priority order (highest → lowest):
/etc/systemd/system/        (custom / admin)
/usr/lib/systemd/system/    (package default)
/lib/systemd/system/        (distribution)
```
- These files define:
  - how the service starts
  - what program it runs
  - restart policies.
  - example to create service
    - [install-openvswitch-create-service.sh](../Shell-script/Install/openvswitch/install-openvswitch-create-service.sh)

### Unit Dependencies
- **Why it exists** —
- **What it is** —

### AppArmor (security profiles)
- **Why it exists** — restricts what a program (service or application) is allowed to access on the system.
- **What it is** — AppArmor (Application Armor) is a Linux security framework. It implements Mandatory Access Control (MAC). The system enforces security rules even if a process has normal permissions to access something.

- AppArmor works by applying profiles to programs.
  A profile defines what the program is allowed or not allowed to do.

- Typical restrictions include:
  - Which files the program can read or write
  - Which directories it can access
  - Which network operations it can perform
  - Which capabilities it can use

### Sockets
- **Why it exists** — allows two programs to communicate either over a network or within the same system.
- **What it is** — A socket is a communication endpoint used for data exchange between processes. Widely used in client–server architecture.

#### type of socket
- Network sockets(TCP/UDP)
  - Used for communication between different machines over a network.
- Unix domain socket
  - Used for communication between processes on the same machine.
  - Instead of an IP and port, they use a file path.

```bash
ss -lntpu
```
- `-t` TCP sockets
- `-u` UDP sockets
- `-l` listening sockets
- `-n` numeric addresses
- `-p` show process using the socket
