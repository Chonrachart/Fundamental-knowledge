# Processes and System Statistics

# Overview
- **What it is** — All process representing in file named by its PID in `/proc/<PID>`. `/proc` is a virtual filesystem (procfs) — not real files on disk.

# Architecture

# Core Building Blocks

### Viewing Processes

```bash
ps [option]
ps -ef -> UNIX/System V style options
ps aux -> BSD style options (no dash)
```

- `ps` list processes for current user.
#### Common option
  - `-e` Show all processes (system-wide)
  - `-f` Full format (UID, PPID, start time, etc.)
  - `a` Show processes for all users with a terminal
  - `u` User-oriented format add like %CPU %MEM
  - `x` Include processes without a terminal (daemons)
    - process that start at boot, run in background, not interact with user
      ex. systemd, sshd, cron, nginx

### Job Control

```bash
command &
```
- & runs the command in background.
- The shell returns control immediately.
- The job gets a job ID example:
  - [1] 1234
    - [1] → Job ID
    - 1234 → PID

#### jobs
```bash
jobs
```
- Lists jobs in current shell session.
- Job states: Running, Stopped, Done

#### Suspend Process (Ctrl+Z)

- Sends SIGTSTP --> Process becomes Stopped --> It stays in the job table.
- It does NOT continue running until you use `bg`

#### bg / fg

```bash
bg [job-id]
fg [job-id]
```
- `bg` Resume a stopped job in background.
- `fg` Bring background or stopped job to foreground.

### Signals

```bash
kill <PID>
kill -9 <PID>
Ctrl + C
```

- `kill <PID>` sends SIGTERM (terminate) terminate gracefully.
- `kill -9 <PID>` sends SIGKILL. force kill (cannot be caught or ignored)
- Ctrl + C Send SIGINT(interrupt) to foreground process, which typically terminates it.

### Exit Codes

### Resource Monitoring

#### top
```bash
top
```
- Real-time view of system resource usage.
- Important fields
  - %CPU → CPU usage per process
  - %MEM → Memory usage per process
  - RES → Resident memory (actual RAM used)
  - VIRT → Virtual memory size
  - load average → System load (1, 5, 15 minutes)
- Useful keys inside top
  - `P` → Sort by CPU
  - `M` → Sort by memory
  - `k` → Kill process
  - `q` → Quit

#### free
```bash
free -h
```
- Shows memory usage. `-h` → Human readable (MB / GB)
- Important fields: total, used, free, buff/cache, available
- Linux uses free memory for cache. High "used" memory is not always a problem.

#### iostat
```bash
iostat -x 1
```
- Shows CPU and disk IO statistics. `-x` Extended, `1` Refresh every 1 second
- Important: %util (near 100% = saturated), await (wait time ms)
- If %util is high and await is high → Disk bottleneck.

#### uptime
```bash
uptime
```
- Shows: Current time, How long system has been running, Number of users, Load average (1, 5, 15 min)

#### nproc and lscpu
```bash
nproc
lscpu
```

- `nproc` Shows the number of processing units available. In containers or cgroup limits, it may show fewer CPUs than physically available.
- `lscpu` Displays detailed CPU architecture information.
  - `Logical CPUs = sockets × cores per socket × threads per core`

### Resource Limits and OOM

### cgroups
