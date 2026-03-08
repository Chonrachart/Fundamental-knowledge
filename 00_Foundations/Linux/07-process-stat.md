# Process

- All process representing in file named by its PID in `/proc/<PID>`
- `/proc` is a virtual filesystem (procfs) — not real files on disk.

```bash
ps [option]
ps -ef -> UNIX/System V style options
ps aux -> BSD style options (no dash)
```

- `ps` list processes for current user.
### Common option
  - `-e` Show all processes (system-wide)
  - `-f` Full format (UID, PPID, start time, etc.)
  - `a` Show processes for all users with a terminal
  - `u` User-oriented format add like %CPU %MEM 
  - `x` Include processes without a terminal (daemons) 
    - process that start at boot, run in background, not interact with user
      ex. systemd, sshd, cron, nginx

# Process States (Quick)

```bash
ps -eo pid,ppid,stat,comm | head
```

- Common `STAT` values:
  - `R` Running or runnable
  - `S` Interruptible sleep (waiting)
  - `D` Uninterruptible sleep (usually disk I/O wait)
  - `Z` Zombie (finished, waiting parent to reap)


# Jobs Control

```bash
command &
```
- & runs the command in background.
- The shell returns control immediately.
- The job gets a job ID example:
  - [1] 1234
    - [1] → Job ID
    - 1234 → PID


### jobs
```bash
jobs
```
- Lists jobs in current shell session.
- Shows job ID, status, and command.
- Example:
  - [1]+  Running   sleep 100 &
  - [2]-  Stopped   vim
- Job states:
  - Running
  - Stopped
  - Done
  
### Suspend Process (Ctrl+Z)

- Press Ctrl + Z
- Sends SIGTSTP --> Process becomes Stopped --> It stays in the job table.
- It does NOT continue running until you use `bg`
  
### bg

```bash
bg [job-id]
```
- Resume a stopped job in background.
- Process continues running but not attached to terminal input.

### fg

```bash
fg [job-id]
```

- Bring background or stopped job to foreground.
- You can interact with it again.

# kill

```bash
kill <PID>
kill -9 <PID>
```

- `kill <PID>` sends SIGTERM (terminate) terminate gracefully.
- `kill -9 <PID>` sends SIGKILL. force kill (cannot be caught or ignored)

# Interrupt

```bash
Ctrl + C
```

- Send SIGINT(interrupt) to foreground process, which typically terminates it.

# Signal Quick Map

- Signals are async notifications sent to a process.

```bash
kill -l
pkill <name>
killall <name>
```

- Common signals
  - `SIGTERM (15)` default for `kill` graceful stop.
  - `SIGKILL (9)` force stop, cannot be caught.
  - `SIGINT (2)` Ctrl + C from terminal.
  - `SIGTSTP (20)` Ctrl + Z stop/suspend.
  - `SIGHUP (1)` terminal closed / reload pattern for some daemons.

- Prefer `SIGTERM` first, use `SIGKILL` only if process does not exit.

# Exit Code and Shell Logic

```bash
echo $?
command1 && command2
command1 || command2
```

- Exit code `0` = success.
- Non-zero = error/failure.
- `&&` run next only if previous success.
- `||` run next only if previous failed.

### Script safety (important)

```bash
set -euo pipefail
```

- `-e` exit on error.
- `-u` fail on unset variable.
- `-o pipefail` pipeline fails if any command fails.


# Resource Usage

```bash
top
```
- Real-time view of system resource usage.
- Shows:
  - CPU usage
  - Memory usage
  - Running processes
  - Load average
- Important fields
  - %CPU → CPU usage per process
  - %MEM → Memory usage per process
  - PID → Process ID
  - RES → Resident memory (actual RAM used)
  - VIRT → Virtual memory size
  - load average → System load (1, 5, 15 minutes)
- Useful keys inside top
  - `P` → Sort by CPU
  - `M` → Sort by memory
  - `k` → Kill process
  - `q` → Quit

# Memory
```bash
free -h
```
- Shows memory usage.
- `-h` → Human readable (MB / GB)
- Important fields
  - total → Total RAM
  - used → Used memory
  - free → Completely unused memory
  - buff/cache → Used for cache (reclaimable)
  - available → Memory available for new applications

- Important:
  - Linux uses free memory for cache.
  - High “used” memory is not always a problem.

# iostat
```bash
iostat -x 1
```

- Shows CPU and disk IO statistics.
  - `-x` → Extended statistics
  - `1` → Refresh every 1 second
- Important columns
  - %util → Disk utilization (near 100% = saturated)
  - await → Average wait time (ms)
  - r/s, w/s → Reads per second / Writes per second
  - rkB/s, wkB/s → Read/Write throughput
- If %util is high and await is high → Disk bottleneck.

# uptime
```bash
uptime
```
- Shows:
  - Current time
  - How long system has been running
  - Number of users
  - Load average (1, 5, 15 min)

# Number of CPU

```bash
nproc
```

- Shows the number of processing units available to the current process.
- Usually equals the number of CPU cores.
- In containers or cgroup limits, it may show fewer CPUs than physically available.

# lscpu
```bash
lscpu
```
- Displays detailed CPU architecture information.
- Important fields:
  - CPU(s) → Total logical CPUs
  - Core(s) per socket
  - Socket(s)
  - Thread(s) per core
- You can calculate:
  - `Logical CPUs = sockets × cores per socket × threads per core`

# Resource Limits and OOM

```bash
ulimit -a
cat /proc/<PID>/limits
dmesg | grep -i oom
```

- `ulimit` controls per-shell/per-process limits (open files, process count, etc.).
- OOM killer may terminate processes when memory is exhausted.
- OOM events are visible in kernel logs (`dmesg` / `journalctl -k`).

### cgroups (basic)

- cgroups limit and account resources for groups of processes.
- Common in containers and modern service management.
- Quick check:

```bash
cat /proc/self/cgroup
```
