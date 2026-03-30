# Processes and System Statistics

- Every running program is a process with a unique PID; all process metadata lives in `/proc/<PID>/`.
- Processes are created by `fork()` (clone parent) and `execve()` (replace with new program); they terminate by sending exit codes to their parent.
- Signals are asynchronous notifications sent to processes to control their behaviour (terminate, stop, reload).


# Process Lifecycle

```text
Kernel boots → systemd (PID 1) starts
        |
        v
systemd forks child → child loads service binary → service starts
        |
        v
Process states:
  R  Running / Runnable   (on CPU or ready)
  S  Sleeping             (waiting for event — interruptible)
  D  Disk wait            (uninterruptible sleep — I/O)
  Z  Zombie               (exited, parent not yet called wait())
  T  Stopped              (Ctrl+Z / SIGTSTP)
        |
        v
Process calls exit() → kernel sends SIGCHLD to parent
        |
        v
Parent calls wait() → zombie reaped → PID released
```

A zombie process is harmless but indicates a parent not calling `wait()`.


# Mental Model: Process Creation

```text
Shell runs: nginx
        |
        v
Shell calls fork() → creates identical child process
        |
        v
Child loads nginx binary into memory (replaces shell image)
        |
        v
nginx runs as new process (new PID, still child of shell)
        |
        v
Shell waits (foreground) or returns prompt (background with &)
```


# Core Building Blocks

### Viewing Processes

```bash
ps aux                          # all processes, BSD format (user, %CPU, %MEM, command)
ps -ef                          # all processes, UNIX format (UID, PPID, start time)
ps -eo pid,ppid,stat,comm       # custom columns
ps aux | grep nginx             # find process by name

top                             # real-time resource view
  # inside top: P=sort CPU, M=sort memory, k=kill, q=quit
```

`STAT` codes: `R` running · `S` sleeping · `D` disk wait · `Z` zombie · `T` stopped
- Processes in state `D` (uninterruptible disk wait) cannot be killed — wait for I/O to complete or reboot.
- Zombie processes (`Z`) hold a PID but use no resources; parent must call `wait()` to reap them.

### Job Control

```bash
command &               # run in background; shell returns [job_id] PID
jobs                    # list jobs in current shell
fg [%job_id]            # bring job to foreground
bg [%job_id]            # resume stopped job in background
Ctrl + Z                # send SIGTSTP → suspend foreground process → state T
Ctrl + C                # send SIGINT  → terminate foreground process
```

### Signals

```bash
kill <PID>              # send SIGTERM (15) — graceful stop request
kill -9 <PID>           # send SIGKILL (9)  — force kill (cannot be caught)
kill -HUP <PID>         # send SIGHUP  (1)  — reload config pattern for daemons
pkill <name>            # send signal by process name
killall <name>          # kill all processes matching name
kill -l                 # list all signal names and numbers
```

| Signal | Number | Meaning |
|---|---|---|
| SIGTERM | 15 | Graceful termination request (default `kill`) |
| SIGKILL | 9 | Force kill — cannot be caught or ignored |
| SIGINT | 2 | Interrupt from keyboard (Ctrl+C) |
| SIGTSTP | 20 | Stop/suspend from keyboard (Ctrl+Z) |
| SIGHUP | 1 | Terminal closed; reload pattern for daemons |
| SIGCHLD | 17 | Child process changed state |

Always try SIGTERM first; use SIGKILL only if the process does not respond.
- SIGKILL cannot be caught, blocked, or ignored — always terminates the process.
- Default `kill` signal is SIGTERM (15), not SIGKILL (9).

### Exit Codes

```bash
echo $?                 # exit code of last command (0=success, non-zero=error)
command && next         # run next only if command succeeds (exit 0)
command || fallback     # run fallback only if command fails (exit non-zero)
```

Script safety header:

```bash
set -euo pipefail       # -e: exit on error  -u: error on unset var  -o pipefail: catch pipe failures
```
- `set -euo pipefail` should be the first line of every non-trivial shell script.

### Resource Monitoring

```bash
# CPU and memory
top                             # interactive real-time view
free -h                         # RAM and swap usage (total / used / free / available)
uptime                          # load average (1, 5, 15 min) + uptime

# CPU info
nproc                           # number of logical CPUs
lscpu                           # CPU architecture details (sockets, cores, threads)
  # logical CPUs = sockets × cores/socket × threads/core

# Disk I/O
iostat -x 1                     # extended disk stats, refresh every 1s
  # %util near 100% = disk saturated; high await = I/O bottleneck

# Per-process inspection
cat /proc/<PID>/status          # memory, state, UID, threads
cat /proc/<PID>/cmdline         # full command line (null-byte delimited)
```
- Load average > number of CPU cores = system is overloaded.
- `free -h` `available` field is the real usable memory — not `free` (Linux caches in unused RAM).
- All process metadata is accessible as virtual files under `/proc/<PID>/`.

### Resource Limits and OOM

```bash
ulimit -a                       # show current shell limits (open files, max processes, etc.)
cat /proc/<PID>/limits          # per-process resource limits
dmesg | grep -i oom             # check if OOM killer fired
journalctl -k | grep -i oom     # same via systemd journal
```

- OOM killer terminates processes when RAM is exhausted.
- `ulimit -n 65535` increases open-file limit for the current shell session.

### cgroups

```bash
cat /proc/self/cgroup                           # show cgroups for current process
systemctl show <service> | grep -i memory       # memory limit set by systemd unit
```

- cgroups (control groups) limit CPU, memory, and I/O per group of processes.
- systemd assigns each service its own cgroup slice; containers use them for isolation.

Related notes:
- [09-service-systemctl-socket](./09-service-systemctl-socket.md) — systemd manages services as cgroup slices
- [08-log](./08-log.md) — journalctl for process logs
