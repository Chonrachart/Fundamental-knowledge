
g- Log is record of what system or program did.- Use log to debug, audit, and monitor system.- Logs are usually text file or systemd journal.# Where logs stored- Classic log files in `/var/log`  - `/var/log/syslog` (Debian/Ubuntu) – main system log.  - `/var/log/messages` (RHEL/CentOS) – similar to syslog.  - `/var/log/auth.log` or `/var/log/secure` – login / sudo / ssh.  - `/var/log/kern.log` – kernel messages.  - `/var/log/dmesg` – boot + kernel ring buffer dump.  - Service logs    - `/var/log/nginx/*.log`    - `/var/log/apache2/*.log`- Many files need `sudo` to read.
bash
ls /var/log
sudo ls /var/log
sudo less /var/log/syslog
# Basic command to view log file
bash
cat /var/log/syslog
less /var/log/syslog
head -n 20 /var/log/syslog
tail -n 50 /var/log/syslog
- `cat` show whole file (useful for small log).- `less` scroll, search `/keyword`, quit with `q`.- `head` show first lines.- `tail` show last lines (usually most recent).# Follow log in real timesudo tail -f /var/log/syslogsudo tail -F /var/log/syslogsudo tail -F /var/log/auth.log
tail -f follow new lines. Stop Ctrl + C.
tail -F like -f but handle log rotation better.
Good for watching service while you restart or test.
Filter log with grep
grep "error" /var/log/sysloggrep -i "failed" /var/log/auth.loggrep -n "timeout" /var/log/sysloggrep -C 3 "timeout" /var/log/syslogsudo tail -F /var/log/syslog | grep -i "error"
grep search line that match pattern.
-i ignore case.
-n show line number.
-C 3 show 3 lines before/after match (context).
Combine tail -F + grep to watch only interesting line.
journalctl (systemd log)
On systemd system, many logs go to binary journal instead of only file.
journalctl is main tool to read this.
sudo journalctlsudo journalctl -bsudo journalctl -fsudo journalctl -u sshsudo journalctl -u nginxsudo journalctl --since "10 minutes ago"sudo journalctl --since "2025-02-28 10:00" --until "2025-02-28 12:00"
journalctl show all journal.
-b only current boot.
-f follow new entries (like tail -f).
-u <service> filter by systemd unit (service).
--since, --until filter by time.
Log rotation (logrotate)
Log file will grow forever if not rotated.
logrotate rotate, compress and clean old log file.
Config file:
cat /etc/logrotate.confls /etc/logrotate.d/
/etc/logrotate.conf main config.
/etc/logrotate.d/* per‑service config.
Common options you see:
daily, weekly, monthly – how often rotate.
rotate 4 – keep 4 old files.
compress – gzip old logs.
size 100M – rotate when reach 100 MB.
missingok – do not error if file missing.
Run logrotate manually:
sudo logrotate -d /etc/logrotate.conf   # dry runsudo logrotate /etc/logrotate.conf      # real run
-d show what would happen, but not change file.
Useful log recipes
Check last boots and shutdowns
last -x | head
See ssh login failure
sudo grep -i "failed password" /var/log/auth.log
Watch kernel messages live
sudo dmesg -w
Debug systemd service failure
systemctl status <service-name>journalctl -u <service-name> --since "15 minutes ago"

