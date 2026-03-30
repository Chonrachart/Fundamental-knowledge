# Logging

# Overview
- **What it is** — Log is record of what system or program did. Use log to debug, audit, and monitor system. Logs are usually text file or systemd journal.
- Modern Linux uses two parallel systems: classic text files in `/var/log/` and the systemd binary journal (read via `journalctl`).
- Log rotation (`logrotate`) prevents logs from filling the disk.

# Architecture

```text
Something broke — where is the log?
        |
        v
Is it a systemd service? (systemctl status <service> shows recent lines)
  → yes: journalctl -u <service> -n 100
        |
        v
Is there a /var/log/<service>/ directory?
  → yes: tail -f /var/log/<service>/error.log
        |
        v
Kernel / hardware issue?
  → dmesg -T | tail -50
  → journalctl -k -b
        |
        v
Auth / SSH / sudo events?
  → /var/log/auth.log (Ubuntu) or /var/log/secure (RHEL)
        |
        v
General system events?
  → /var/log/syslog (Ubuntu) or /var/log/messages (RHEL)
```
# Core Building Blocks

### Log File Locations

- Classic log files in `/var/log`
  - `/var/log/syslog` (Debian/Ubuntu) – main system log.
  - `/var/log/messages` (RHEL/CentOS) – similar to syslog.
  - `/var/log/auth.log` or `/var/log/secure` – login / sudo / ssh.
  - `/var/log/kern.log` – kernel messages.
  - `/var/log/dmesg` – boot + kernel ring buffer dump.
  - Service logs
    - `/var/log/nginx/*.log`
    - `/var/log/apache2/*.log`
- Many files need `sudo` to read.

### Following Logs in Real Time

```bash
sudo tail -f /var/log/syslog
sudo tail -F /var/log/syslog
sudo tail -F /var/log/auth.log
```

- `tail -f` follow new lines. Stop Ctrl + C.
- `tail -F` like `-f` but handle log rotation better.
- Good for watching service while you restart or test.

### journalctl (systemd journal)
- **What it is** — On systemd system, many logs go to binary journal instead of only file. journalctl is main tool to read this.

```bash
sudo journalctl
sudo journalctl -b
sudo journalctl -p err
sudo journalctl -f
sudo journalctl -n <number>
sudo journalctl -u ssh
sudo journalctl -k
sudo journalctl --since "10 minutes ago"
sudo journalctl --since "2025-02-28 10:00" --until "2025-02-28 12:00"
```
- `-b` only current boot. `-b -1` previous boot
- `-p err` show only error
- `-f` follow new entries (like tail -f).
- `-u <service>` filter by systemd unit (service).
- `-k` for kernal log
- `--since`, `--until` filter by time.

#### Can combine like
```bash
journalctl -u <service> -f
journalctl -u <service> -n 50
journalctl -kf
journalctl -u <service> -p err
```

### Time and Timezone

```bash
timedatectl                         # show current time, timezone, NTP status
timedatectl set-timezone Asia/Bangkok
timedatectl set-ntp true            # enable NTP sync
```

- Wrong timezone makes log timestamps misleading and breaks TLS/auth cert validation.
- Keep NTP enabled; all servers in a cluster must be time-synced for log correlation.
- Always check timezone with `timedatectl` when logs seem to be from the wrong time.

### Log Rotation (logrotate)
- **What it is** — `logrotate` rotate, compress and clean old log file. Log file will grow forever if not rotated.

Config file:

```bash
cat /etc/logrotate.conf
ls /etc/logrotate.d/
```
- `/etc/logrotate.conf` main config.
- `/etc/logrotate.d/*` per‑service config.

Common options:
- `daily`, `weekly`, `monthly` – how often rotate.
- `rotate 4` – keep 4 old files.
- `compress` – gzip old logs.
- `size 100M` – rotate when reach 100 MB.
- `missingok` – do not error if file missing.

```bash
sudo logrotate -d /etc/logrotate.conf   # dry run
sudo logrotate /etc/logrotate.conf      # real run
```
