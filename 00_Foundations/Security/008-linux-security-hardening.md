# Linux Security Hardening

- Linux hardening reduces the attack surface by disabling unnecessary services, enforcing access controls, and monitoring system activity
- It spans multiple layers: SSH access, mandatory access control (SELinux/AppArmor), kernel parameters, file permissions, and audit logging
- A hardened system follows the principle of least privilege at every level — network, process, user, and filesystem

## Architecture

```text
  ┌─────────────────────────────────────────────────────────┐
  │                    Attack Surface                       │
  └─────────────────────────────────────────────────────────┘
           │
  ┌────────┴────────────────────────────────────────────────┐
  │  Layer 1: Network / SSH                                 │
  │  ┌────────────┐  ┌────────────┐  ┌────────────────────┐│
  │  │ SSH Harden │  │ Fail2ban   │  │ Firewall (iptables)││
  │  │ key-only   │  │ brute-force│  │ nftables           ││
  │  │ no root    │  │ protection │  │                    ││
  │  └────────────┘  └────────────┘  └────────────────────┘│
  ├─────────────────────────────────────────────────────────┤
  │  Layer 2: Mandatory Access Control                      │
  │  ┌──────────────────┐  ┌──────────────────┐            │
  │  │ SELinux           │  │ AppArmor         │            │
  │  │ (RHEL/CentOS)     │  │ (Ubuntu/SUSE)    │            │
  │  │ label-based       │  │ path-based       │            │
  │  └──────────────────┘  └──────────────────┘            │
  ├─────────────────────────────────────────────────────────┤
  │  Layer 3: Kernel / Sysctl                               │
  │  ASLR, rp_filter, ip_forward, SUID controls            │
  ├─────────────────────────────────────────────────────────┤
  │  Layer 4: Audit & Integrity                             │
  │  ┌──────────────┐  ┌──────────────┐                    │
  │  │ auditd       │  │ AIDE         │                    │
  │  │ syscall/file │  │ file         │                    │
  │  │ monitoring   │  │ integrity    │                    │
  │  └──────────────┘  └──────────────┘                    │
  └─────────────────────────────────────────────────────────┘
```

## Mental Model

```text
  Identify         Reduce           Enforce          Monitor
  attack surface   exposure         access control   activity
  ─────────────► ──────────────► ──────────────► ──────────────►

  1. Audit open    2. Disable       3. SELinux /     4. auditd
     ports, SUID      unused          AppArmor         rules,
     binaries,        services,       in enforcing     AIDE
     running          root login,     mode; sysctl     checks,
     services         password auth   hardening        log review
```

Example: harden SSH on a fresh server.

```bash
# Backup original config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Apply hardening settings
sudo tee -a /etc/ssh/sshd_config.d/hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
Port 2222
AllowUsers deploy admin
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
EOF

# Restart SSH
sudo systemctl restart sshd
```

## Core Building Blocks

### SSH Hardening

- **Disable root login** — `PermitRootLogin no` in sshd_config; use sudo for privilege escalation
- **Disable password auth** — `PasswordAuthentication no`; forces key-based authentication
- **Key-based auth only** — `PubkeyAuthentication yes`; deploy public keys to `~/.ssh/authorized_keys`
- **Change default port** — `Port 2222` (reduces automated scans; not a security measure by itself)
- **Restrict users** — `AllowUsers user1 user2` or `AllowGroups sshusers`; whitelist approach
- **Limit auth attempts** — `MaxAuthTries 3`
- **Fail2ban** — monitors auth logs and bans IPs after repeated failures

```bash
# Install and enable fail2ban
sudo apt install fail2ban
sudo systemctl enable --now fail2ban

# Custom SSH jail: /etc/fail2ban/jail.local
# [sshd]
# enabled = true
# port = 2222
# maxretry = 3
# bantime = 3600
# findtime = 600

# Check banned IPs
sudo fail2ban-client status sshd
```

Related notes: [004-authentication](./004-authentication.md)

### SELinux

- **Mandatory Access Control (MAC)** — enforces policies beyond traditional DAC (user/group/other)
- Uses **security contexts** (labels): `user:role:type:level` applied to every file, process, port
- **Type enforcement** is the primary mechanism — rules define which types can access which types

| Mode | Behavior |
|------|----------|
| Enforcing | Policies enforced; violations denied and logged |
| Permissive | Policies not enforced; violations only logged (for testing) |
| Disabled | SELinux completely off (requires reboot to re-enable) |

```bash
# Check current mode
getenforce                                    # returns Enforcing/Permissive/Disabled
sestatus                                      # detailed status

# Switch modes (runtime, non-persistent)
sudo setenforce 1                             # set enforcing
sudo setenforce 0                             # set permissive
# Persistent: edit /etc/selinux/config → SELINUX=enforcing

# View file context
ls -Z /var/www/html/
# -rw-r--r--. root root unconfined_u:object_r:httpd_sys_content_t:s0 index.html

# Restore default context
sudo restorecon -Rv /var/www/html/

# Manage contexts
sudo semanage fcontext -a -t httpd_sys_content_t "/web(/.*)?"
sudo restorecon -Rv /web

# Manage ports
sudo semanage port -a -t http_port_t -p tcp 8080

# Booleans (toggle features)
getsebool -a | grep httpd                    # list httpd booleans
sudo setsebool -P httpd_can_network_connect on   # -P = persistent

# Troubleshoot denials
sudo ausearch -m avc -ts recent              # find recent denials
sudo sealert -a /var/log/audit/audit.log     # human-readable analysis
```

Related notes: [005-authorization](./005-authorization.md), [003-user-group-permission](../Linux/003-user-group-permission.md)

### AppArmor

- Path-based MAC system (as opposed to SELinux's label-based approach)
- Profiles define what files, capabilities, and network access a program can use
- Simpler than SELinux; default on Ubuntu and SUSE distributions

| Mode | Behavior |
|------|----------|
| Enforce | Violations denied and logged |
| Complain | Violations only logged (for profile development) |
| Disabled | Profile not loaded |

```bash
# Check status
sudo aa-status                               # list loaded profiles and modes

# Profile management
sudo aa-enforce /etc/apparmor.d/usr.sbin.nginx    # set enforce
sudo aa-complain /etc/apparmor.d/usr.sbin.nginx   # set complain
sudo aa-disable /etc/apparmor.d/usr.sbin.nginx    # disable profile

# Reload all profiles
sudo systemctl reload apparmor

# Generate profile (interactive)
sudo aa-genprof /usr/bin/myapp

# Profile location: /etc/apparmor.d/
# Log location: /var/log/syslog or journalctl
```

Related notes: [005-authorization](./005-authorization.md)

### Auditd

- Linux audit framework — tracks security-relevant events at the kernel level
- Records syscalls, file access, user commands, authentication events
- Config: `/etc/audit/auditd.conf` (daemon settings), `/etc/audit/rules.d/` (rules)

```bash
# Install and enable
sudo apt install auditd    # Debian/Ubuntu
sudo systemctl enable --now auditd

# --- Common audit rules ---
# Watch a file for changes (write, attribute change)
sudo auditctl -w /etc/passwd -p wa -k passwd_changes

# Watch a directory
sudo auditctl -w /etc/ssh/ -p wa -k ssh_config

# Monitor all commands run by a user (uid 1000)
sudo auditctl -a always,exit -F arch=b64 -S execve -F uid=1000 -k user_commands

# Monitor privilege escalation
sudo auditctl -a always,exit -F arch=b64 -S execve -F euid=0 -F uid!=0 -k privilege_escalation

# List active rules
sudo auditctl -l

# Make rules persistent: add to /etc/audit/rules.d/custom.rules

# --- Search and report ---
sudo ausearch -k passwd_changes                # search by key
sudo ausearch -m USER_LOGIN --start today      # search by event type
sudo aureport --auth                           # authentication report
sudo aureport --summary                        # overall summary
sudo aureport --file --summary                 # file access summary
```

Related notes: [003-user-group-permission](../Linux/003-user-group-permission.md)

### Sysctl Security Hardening

- Kernel parameters tuned via `sysctl` to reduce attack surface
- Persistent config: `/etc/sysctl.d/99-security.conf`

```bash
# Apply all settings from config
sudo sysctl --system

# Recommended security settings
sudo tee /etc/sysctl.d/99-security.conf <<'EOF'
# Disable IP forwarding (unless acting as router)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Reverse path filtering (drop spoofed packets)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests (smurf attack)
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bogus ICMP errors
net.ipv4.icmp_ignore_bogus_error_responses = 1

# SYN flood protection
net.ipv4.tcp_syncookies = 1

# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# Enable ASLR (Address Space Layout Randomization)
kernel.randomize_va_space = 2

# Restrict core dumps for SUID binaries
fs.suid_dumpable = 0

# Restrict kernel pointer exposure
kernel.kptr_restrict = 2

# Restrict dmesg access
kernel.dmesg_restrict = 1
EOF

sudo sysctl --system
```

Related notes: [firewall-iptables-nftable](../Linux/Networking/006-firewall-iptables-nftable.md)

### SUID/SGID Audit

- SUID (Set User ID): file executes with owner's privileges regardless of who runs it
- SGID (Set Group ID): file executes with group's privileges; on directories, new files inherit the group
- Unnecessary SUID/SGID binaries are privilege escalation vectors

```bash
# Find all SUID files
sudo find / -perm -4000 -type f -ls 2>/dev/null

# Find all SGID files
sudo find / -perm -2000 -type f -ls 2>/dev/null

# Find world-writable files (potential risk)
sudo find / -perm -o+w -type f -not -path "/proc/*" -not -path "/sys/*" 2>/dev/null

# Find files with no owner
sudo find / -nouser -o -nogroup 2>/dev/null

# Remove SUID from a binary
sudo chmod u-s /path/to/binary

# Common legitimate SUID binaries: passwd, sudo, ping, su, mount, umount
# Investigate any unfamiliar SUID binary
```

Related notes: [003-user-group-permission](../Linux/003-user-group-permission.md)

### File Integrity Monitoring (AIDE)

- AIDE (Advanced Intrusion Detection Environment) — creates a database of file hashes and attributes
- Detects unauthorized changes to system files by comparing current state against the baseline
- Alternative to commercial tools like Tripwire

```bash
# Install
sudo apt install aide         # Debian/Ubuntu
sudo yum install aide         # RHEL/CentOS

# Initialize baseline database
sudo aide --init
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Check for changes against baseline
sudo aide --check

# Update database after legitimate changes
sudo aide --update
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Config: /etc/aide/aide.conf
# Define what to monitor:
#   /etc    p+i+u+g+sha256
#   /bin    p+i+u+g+sha256
#   /sbin   p+i+u+g+sha256

# Automate daily checks via cron
# 0 3 * * * /usr/bin/aide --check | mail -s "AIDE Report" admin@example.com
```

Related notes: [004-authentication](./004-authentication.md)

---

## Troubleshooting Flow (Quick)

```text
  Security issue?
    │
    ├─ SSH login fails after hardening
    │    └─► check sshd_config syntax: sshd -t
    │         ├─► verify AllowUsers includes your user
    │         ├─► verify key permissions: ~/.ssh/ (700), authorized_keys (600)
    │         └─► check fail2ban: sudo fail2ban-client status sshd
    │              └─► unban: sudo fail2ban-client set sshd unbanip <IP>
    │
    ├─ SELinux denial (AVC)
    │    └─► check denial: sudo ausearch -m avc -ts recent
    │         ├─► context mismatch → restorecon -Rv /path
    │         ├─► boolean needed → setsebool -P <bool> on
    │         └─► custom policy → audit2allow -a -M mypolicy
    │
    ├─ AppArmor blocking app
    │    └─► check logs: journalctl | grep apparmor
    │         ├─► set to complain: aa-complain /etc/apparmor.d/<profile>
    │         └─► update profile, then re-enforce
    │
    ├─ Suspicious file changes detected
    │    └─► run: sudo aide --check
    │         ├─► legitimate change → sudo aide --update
    │         └─► unauthorized change → investigate, restore from backup
    │
    └─ Unexpected SUID binary found
         └─► identify: file /path/to/binary; rpm -qf /path (RHEL)
              ├─► known package → verify: rpm -V <package>
              └─► unknown → quarantine, investigate, remove SUID bit
```

## Quick Facts (Revision)

- SSH hardening minimum: `PermitRootLogin no`, `PasswordAuthentication no`, key-based auth only
- Fail2ban reads auth logs and creates firewall rules to ban IPs after repeated failures
- SELinux uses labels (contexts) on every object; AppArmor uses filesystem paths — choose based on distro
- `setenforce 0` sets permissive at runtime; to persist, edit `/etc/selinux/config`
- `kernel.randomize_va_space=2` enables full ASLR — randomizes stack, heap, mmap, and VDSO
- SUID binaries execute with the file owner's privileges — audit regularly with `find / -perm -4000`
- AIDE baseline must be updated after every legitimate system change, or future checks produce false positives
- Sysctl changes are non-persistent unless written to `/etc/sysctl.d/`; apply with `sysctl --system`
