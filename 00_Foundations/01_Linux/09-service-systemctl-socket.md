# Services, systemctl, and Sockets

# Overview
- systemd is PID 1 on modern Linux — it manages the boot sequence, services, and system state.
  - It is responsible for:
    - starting the system during boot
    - managing background services
    - controlling system processes
    - handling logging and system states
- A service is a background process (daemon) defined by a unit file; systemctl is the tool to control it.
- Sockets are communication endpoints — network sockets (IP:port) and Unix domain sockets (file path).



# Architecture

```text
Kernel starts → systemd (PID 1)
        |
        v
Reads unit files (highest → lowest priority):
  /etc/systemd/system/          (admin / custom overrides)
  /usr/lib/systemd/system/      (package defaults)
  /lib/systemd/system/          (distribution defaults)
        |
        v
Resolves unit dependencies (After=, Requires=, Wants=)
        |
        v
Activates targets in order:
  sysinit.target → basic.target → multi-user.target → graphical.target
        |
        v
Services, timers, sockets, mounts start under their target
        |
        v
All output captured by journald → readable via journalctl
```

# Core Building Blocks

### systemctl Commands

- A service is a background process that runs on a system to provide functionality.
- Services usually start automatically during system boot.
- Examples: web servers, database servers, SSH remote access, monitoring agents

```bash
# service lifecycle
systemctl start   <service>         # start now
systemctl stop    <service>         # stop now
systemctl restart <service>         # stop then start
systemctl reload  <service>         # reload config without restart (if supported)
systemctl status  <service>         # show state + last log lines

# boot behaviour
systemctl enable  <service>         # start on boot (creates symlink in target.wants/)
systemctl disable <service>         # don't start on boot
systemctl is-enabled <service>      # check if enabled
# note: systemctl enable creates a symlink; it does NOT start the service immediately — combine with start

# unit file management
systemctl daemon-reload             # reload unit files after create or edit
systemctl cat <service>             # show effective unit file content
systemctl edit <service>            # create override drop-in file
systemctl show <service> -p After -p Requires -p Wants   # inspect dependencies

# inspect system state
systemctl list-units --type=service         # all loaded service units
systemctl list-units --type=service --failed
systemctl --failed                          # shortcut for failed units

# power management
systemctl reboot
systemctl poweroff
systemctl suspend
```

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
  
### Unit File Structure

```ini
[Unit]
Description=My Application
After=network-online.target        # start ordering only
Wants=network-online.target        # weak dependency (best effort)
Requires=postgresql.service        # strong dependency (fail if postgres fails)

[Service]
Type=simple                        # process stays in foreground (default)
ExecStart=/usr/bin/myapp --config /etc/myapp/config.yml
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure                 # restart if process exits non-zero
RestartSec=5                       # wait 5s before restart attempt
User=myapp                         # run as this user (not root)
WorkingDirectory=/opt/myapp

[Install]
WantedBy=multi-user.target         # activate for multi-user boot target
```

After creating or editing a unit file:

```bash
systemctl daemon-reload
systemctl restart <service>
```
- `systemctl daemon-reload` is required after any unit file change — without it changes are ignored.
- `Type=simple` (default): service is considered started when ExecStart process begins (not when ready).
- `Restart=on-failure` restarts only on non-zero exit; `Restart=always` restarts even on clean exit.
- `systemctl edit` creates a drop-in override — safer than modifying the package-provided unit file directly.

### Unit Dependencies

| Directive   | Meaning                                                |
| ----------- | ------------------------------------------------------ |
| `After=`    | Ordering only — this unit starts after listed units    |
| `Requires=` | Strong — if required unit fails, this unit fails too   |
| `Wants=`    | Weak — best effort; this unit starts regardless        |
| `Before=`   | This unit starts before listed units                   |
| `BindsTo=`  | Very strong — if bound unit stops, this unit stops too |
- `After=` is ordering only; use `Requires=` or `Wants=` for actual dependency declarations.

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
- **Network sockets(TCP/UDP)**
  - Used for communication between different machines over a network.
- **Unix domain socket**
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
