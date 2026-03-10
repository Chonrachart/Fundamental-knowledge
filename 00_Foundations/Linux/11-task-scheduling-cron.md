# Task Scheduling with Cron

- `cron` is a time-based job scheduler on Linux.
- Use cron to run command or script automatically at specific time.
- `crond` (daemon) reads cron tables and executes jobs.

# Check cron service

```bash
systemctl status cron      # Debian/Ubuntu
systemctl status crond     # RHEL/CentOS/Fedora
```

- Service name can be `cron` or `crond` depending on distro.
- If service is not running, scheduled jobs will not run.

# Crontab basics

```bash
crontab -e
crontab -l
crontab -r
```

- `crontab -e` edit current user's cron jobs.
- `crontab -l` list current user's cron jobs.
- `crontab -r` remove current user's cron jobs.

### Cron line format

```text
* * * * * command_to_run
- - - - -
| | | | |
| | | | +---- day of week (0-7) (0 and 7 = Sunday)
| | | +------ month (1-12)
| | +-------- day of month (1-31)
| +---------- hour (0-23)
+------------ minute (0-59)
```

# Common schedule examples

```bash
# Every minute
* * * * * /path/to/script.sh

# Every day at 02:30
30 2 * * * /path/to/backup.sh

# Every Monday at 09:00
0 9 * * 1 /path/to/report.sh

# Every 5 minutes
*/5 * * * * /path/to/check.sh

# At 00:00 on day 1 of every month
0 0 1 * * /path/to/monthly.sh
```

# Special strings

```bash
@reboot /path/to/startup.sh
@hourly /path/to/hourly.sh
@daily /path/to/daily.sh
@weekly /path/to/weekly.sh
@monthly /path/to/monthly.sh
@yearly /path/to/yearly.sh
```

- `@reboot` runs after system boot.
- Useful for startup scripts that do not need full systemd unit.

# System cron files

```bash
cat /etc/crontab
ls /etc/cron.d/
ls /etc/cron.daily/
ls /etc/cron.weekly/
ls /etc/cron.monthly/
```

- `/etc/crontab` includes an extra `user` field.
- `/etc/cron.d/*` for package/admin managed cron entries.
- `/etc/cron.daily` etc. run via `run-parts`.

### Difference: user crontab vs /etc/crontab

- User crontab format:
  - `* * * * * command`
- `/etc/crontab` format:
  - `* * * * * user command`

# Environment in cron (important)

- Cron uses limited environment.
- `PATH` is often minimal.
- Use absolute path in commands and scripts.

```bash
* * * * * /usr/bin/bash /home/user/job.sh
```

You can set variables at top of crontab:

```bash
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

# Logging and troubleshooting

```bash
journalctl -u cron -f
journalctl -u crond -f
grep CRON /var/log/syslog
```

- Check service log first if job not running.
- Redirect stdout/stderr to log file for debugging:

```bash
*/5 * * * * /path/to/job.sh >> /var/log/job.log 2>&1
```

### Quick checklist when cron job fails

- Confirm cron service is running.
- Confirm schedule expression is correct.
- Confirm script is executable (`chmod +x script.sh`).
- Confirm absolute paths are used.
- Confirm script works manually with same user.
- Confirm permissions for output/log directories.

# Security and good practice

- Do not put plain-text secrets directly in crontab.
- Prefer small wrapper script and secure permission (`chmod 700`).
- Use lock mechanism to avoid overlapping jobs.

Example with `flock`:

```bash
*/5 * * * * flock -n /tmp/myjob.lock /path/to/job.sh
```

# Cron vs systemd timer

- Cron is simple and widely available.
- `systemd timer` is better for dependency control, persistent missed-run handling, and richer logging.
- For simple periodic jobs, cron is usually enough.

# Related notes

- [07-process-stat](./07-process-stat.md)
- [08-log](./08-log.md)
- [09-service-systemctl-socket](./09-service-systemctl-socket.md)
