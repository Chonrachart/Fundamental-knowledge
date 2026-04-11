# Processes and System Statistics

# Overview
- **What it is** — All process representing in file named by its PID in `/proc/<PID>`. `/proc` is a virtual filesystem (procfs) — not real files on disk.

# Architecture

  1. Everything starts from systemd

  When Linux boots, the kernel starts one process: systemd (PID 1). Every other process is a child of it (directly or indirectly).

  2. How a new process is created

  systemd (or any parent)
      |
      fork()  → creates a COPY of itself (child process, new PID)
      |
      execve() → child replaces itself with the actual program (e.g. nginx)

  So starting nginx = fork a copy → replace that copy with nginx binary.

  3. Process states — what a process can be doing

  | State | Meaning                                          | Example                                            |
  | ----- | ------------------------------------------------ | -------------------------------------------------- |
  | R     | Running or ready to run                          | nginx handling a request                           |
  | S     | Sleeping, waiting for something                  | waiting for network data                           |
  | D     | Disk wait — cannot be interrupted                | waiting for disk I/O to finish, can't even kill -9 |
  | Z     | Zombie — finished but parent hasn't acknowledged | process exited, parent didn't call wait()          |
  | T     | Stopped — paused by signal                       | you pressed Ctrl+Z                                 |

  You can see these in ps aux under the STAT column.

  4. How a process dies

  Process calls exit()
          |
          v
  Kernel sends SIGCHLD to parent → "hey, your child finished"
          |
          v
  Parent calls wait() → reads the exit code → zombie disappears → PID is freed

  5. What's a zombie?

  If the parent doesn't call wait(), the child is stuck as a zombie:

  Child exits → becomes zombie (Z) → waits for parent to acknowledge
                                    → if parent never does, zombie stays forever

  - It uses no CPU, no memory — just holds a PID in the process table                                                                                                                                                                                                        
  - It's harmless in small numbers, but indicates a bug in the parent program
  - You can't kill a zombie with kill -9 — you'd have to kill the parent, then systemd (PID 1) adopts and reaps the zombie    
  - `ps aux | awk '$8 ~ /Z/ {print}'    # find any zombies`

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

| Signal  | Number | Meaning                                       |
| ------- | ------ | --------------------------------------------- |
| SIGTERM | 15     | Graceful termination request (default `kill`) |
| SIGKILL | 9      | Force kill — cannot be caught or ignored      |
| SIGINT  | 2      | Interrupt from keyboard (Ctrl+C)              |
| SIGTSTP | 20     | Stop/suspend from keyboard (Ctrl+Z)           |
| SIGHUP  | 1      | Terminal closed; reload pattern for daemons   |
| SIGCHLD | 17     | Child process changed state                   |

Always try SIGTERM first; use SIGKILL only if the process does not respond.
- SIGKILL cannot be caught, blocked, or ignored — always terminates the process.
- Default `kill` signal is SIGTERM (15), not SIGKILL (9).

### Exit Codes

```bash
echo $?                 # exit code of last command (0=success, non-zero=error)
command && next         # run next only if command succeeds (exit 0)
command || fallback     # run fallback only if command fails (exit non-zero)
```

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

