# Services, systemctl, and Sockets

- systemd is PID 1 on modern Linux — it manages the boot sequence, services, and system state.
- A service is a background process (daemon) defined by a unit file; systemctl is the tool to control it.
- Sockets are communication endpoints — network sockets (IP:port) and Unix domain sockets (file path).


# systemd Architecture

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


# Mental Model: Service Start

```text
systemctl start nginx
        |
        v
systemd reads nginx.service unit file
        |
        v
Checks After= / Requires= dependencies are met
        |
        v
Forks child process → loads nginx binary → nginx starts
        |
        v
stdout/stderr captured by journald
        |
        v
Service state: activating → active (running)
        |
        v
cgroup created: /sys/fs/cgroup/system.slice/nginx.service
        |
        v
systemctl status nginx  →  shows state + recent log lines
```


# Core Building Blocks

### systemctl Commands

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

| Directive | Meaning |
|---|---|
| `After=` | Ordering only — this unit starts after listed units |
| `Requires=` | Strong — if required unit fails, this unit fails too |
| `Wants=` | Weak — best effort; this unit starts regardless |
| `Before=` | This unit starts before listed units |
| `BindsTo=` | Very strong — if bound unit stops, this unit stops too |
- `After=` is ordering only; use `Requires=` or `Wants=` for actual dependency declarations.

### AppArmor (security profiles)

- AppArmor restricts what a process can access (files, network, capabilities) via Mandatory Access Control.
- Profiles are per-executable and loaded at service start.

```bash
aa-status                           # show loaded profiles and mode
aa-complain /usr/sbin/nginx         # complain mode: log violations, don't block
aa-enforce /usr/sbin/nginx          # enforce mode: block violations
```

### Sockets

```bash
ss -tlnp            # TCP listening sockets with process names
ss -ulnp            # UDP listening sockets
ss -tlnp sport = :80  # filter by port
ss -s               # socket summary statistics
```

Socket types:
- **Network socket** (TCP/UDP) — IP address + port; used for cross-machine communication.
- **Unix domain socket** — file path (e.g. `/run/nginx.sock`); used for local IPC; faster than TCP loopback.

`ss` option reference: `-t` TCP · `-u` UDP · `-l` listening · `-n` numeric · `-p` show process
- Unix domain sockets are faster than TCP loopback for local IPC (no TCP/IP stack overhead).

Related notes:
- [07-process-stat](./07-process-stat.md) — processes and signals
- [08-log](./08-log.md) — journalctl for service logs
