# Log

- Log is record of what system or program did.
- Use log to debug, audit, and monitor system.
- Logs are usually text file or systemd journal.

# Where logs stored

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


# Follow log in real time
```bash
sudo tail -f /var/log/syslog
sudo tail -F /var/log/syslog
sudo tail -F /var/log/auth.log
```

- `tail -f` follow new lines. Stop Ctrl + C.
- `tail -F` like `-f` but handle log rotation better.
- Good for watching service while you restart or test.

# journalctl (systemd log)
- On systemd system, many logs go to binary journal instead of only file.
- journalctl is main tool to read this.
```bash
sudo journalctl
sudo journalctl -b
sudo journalctl -p err
sudo journalctl -f
sudo journalctl -n <number>
sudo journalctl -u ssh
sudo journalctl -u nginx
sudo journalctl -k
sudo journalctl --since "10 minutes ago"
sudo journalctl --since "2025-02-28 10:00" --until "2025-02-28 12:00"
```
- journalctl show all journal.
- `-b` only current boot.
  - `-b -1` previous boot
- `-p eer` show only error
- `-f` follow new entries (like tail -f).
- `-u <service>` filter by systemd unit (service).
- `-k` for kernal log
- `--since`, `--until` filter by time.
### Can conbine like 
```bash
journalctl -u <service> -f
journalctl -u <service> -n -50
journalctl -kf
journalctl -u <service> -p err
```

# Log rotation (logrotate)
- Log file will grow forever if not rotated.
- `logrotate` rotate, compress and clean old log file.

Config file:
```bash
cat /etc/logrotate.conf
ls /etc/logrotate.d/
```
- `/etc/logrotate.conf` main config.
- `/etc/logrotate.d/*` per‑service config.
Common options you see:
- `daily`, `weekly`, `monthly` – how often rotate.
- `rotate 4` – keep 4 old files.
- `compress` – gzip old logs.
- `size 100M` – rotate when reach 100 MB.
- `missingok` – do not error if file missing.

Run logrotate manually:
```bash
sudo logrotate -d /etc/logrotate.conf   # dry run
sudo logrotate /etc/logrotate.conf      # real run
```
- `-d` show what would happen, but not change file.