# Task Scheduling with Cron

- `cron` is a time-based job scheduler: `crond` (daemon) reads crontab files and executes commands at defined times.
- Cron uses a minimal environment — always use absolute paths in commands and scripts.
- For complex scheduling with dependencies and logging, prefer `systemd timers`; for simple periodic jobs, cron is sufficient.


# How Cron Works

```text
System boot
        |
        v
crond starts (systemd service: cron / crond)
        |
        v
Reads all crontab sources:
  /var/spool/cron/crontabs/<user>   (per-user crontabs via crontab -e)
  /etc/crontab                      (system crontab with extra user field)
  /etc/cron.d/*                     (package / admin drop-in files)
  /etc/cron.daily|weekly|monthly/   (scripts run via run-parts)
        |
        v
Every minute: check if any job matches current time
        |
        v
Fork and execute matching commands
        |
        v
Output (stdout/stderr) emailed to user (if mail configured)
or redirected to file if >> /path/to/log 2>&1 is used
```


# Mental Model: Crontab Line

```text
* * * * *  command
│ │ │ │ │
│ │ │ │ └── day of week  (0-7, 0 and 7 = Sunday)
│ │ │ └──── month        (1-12)
│ │ └────── day of month (1-31)
│ └──────── hour         (0-23)
└────────── minute       (0-59)

*/5 = every 5 units   (e.g. */5 in minute = every 5 minutes)
1-5 = range           (e.g. 1-5 in day of week = Mon–Fri)
1,3 = list            (e.g. 1,3 in hour = at 01:00 and 03:00)
```


# Core Building Blocks

### Managing Crontabs

```bash
crontab -e              # edit current user's crontab (opens in $EDITOR)
crontab -l              # list current user's crontab
crontab -r              # remove current user's crontab (careful — no confirmation)
crontab -u <user> -l    # list another user's crontab (root only)
```
- `crontab -r` deletes the entire crontab with no confirmation — be careful.

### Common Schedule Examples

```bash
# every minute
* * * * * /path/to/script.sh

# every day at 02:30
30 2 * * * /path/to/backup.sh

# every Monday at 09:00
0 9 * * 1 /path/to/report.sh

# every 5 minutes
*/5 * * * * /path/to/check.sh

# weekdays at 08:00 and 17:00
0 8,17 * * 1-5 /path/to/notify.sh

# 1st of every month at midnight
0 0 1 * * /path/to/monthly.sh
```

### Special Strings

```bash
@reboot   /path/to/startup.sh      # run once after system boot
@hourly   /path/to/hourly.sh       # equivalent to: 0 * * * *
@daily    /path/to/daily.sh        # equivalent to: 0 0 * * *
@weekly   /path/to/weekly.sh       # equivalent to: 0 0 * * 0
@monthly  /path/to/monthly.sh      # equivalent to: 0 0 1 * *
@yearly   /path/to/yearly.sh       # equivalent to: 0 0 1 1 *
```
- `@reboot` runs once at system boot, not after every login.

### System Cron Files

```bash
cat /etc/crontab                    # system crontab (has extra user field)
ls /etc/cron.d/                     # drop-in files for packages/admin
ls /etc/cron.daily/                 # scripts run daily via run-parts
ls /etc/cron.weekly/
ls /etc/cron.monthly/
```

Format difference:

```bash
# user crontab (/var/spool/cron/crontabs/<user>):
* * * * * /path/command

# /etc/crontab and /etc/cron.d/* — has extra user field:
* * * * * root /path/command
```
- `/etc/crontab` and files in `/etc/cron.d/` require an explicit username field.

### Environment in Cron

```bash
# cron's PATH is minimal — set it explicitly at top of crontab
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# always redirect output to capture errors
*/5 * * * * /usr/bin/bash /home/user/job.sh >> /var/log/job.log 2>&1
```
- Cron's `PATH` is `/usr/bin:/bin` by default — always use absolute paths or set `PATH=` at top of crontab.
- Output from cron jobs goes to the user's mail unless redirected to a file with `>> /log 2>&1`.

Related notes:
- [10-shell-environment-and-path](./10-shell-environment-and-path.md) — PATH and environment variables
- [08-log](./08-log.md) — journalctl for cron logs
- [09-service-systemctl-socket](./09-service-systemctl-socket.md) — systemd timers as an alternative

### Preventing Overlapping Jobs (flock)

```bash
*/5 * * * * flock -n /tmp/myjob.lock /path/to/job.sh
```

- `flock -n` skips this run if the previous run is still holding the lock.
- Prevents multiple instances of a long-running job from piling up.
- `flock -n` is the correct way to prevent overlapping cron job executions.
- For dependency control, missed-run catching, and richer logging, use `systemd timers` instead of cron.

### Security

```bash
chmod 700 /path/to/job.sh           # only owner can read/execute
# Do NOT put plain-text secrets in crontab
# Use a secrets file with restricted permissions instead
```


---

# Troubleshooting Guide

### Cron job not running

1. Check if cron service is running: `systemctl status cron` (or `crond`).
2. Confirm job is actually in crontab: `crontab -l`.
3. Test schedule expression at crontab.guru or run manually.
4. Run command manually as the cron user to check it works.
5. Check execution log: `journalctl -u cron -f` or `grep CRON /var/log/syslog`.

### Job runs but does nothing / produces errors

1. Capture all output: redirect with `command >> /tmp/job.log 2>&1`.
2. Check PATH: add full absolute paths to command and script.
3. Check script is executable: `chmod +x /path/to/job.sh`.

