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

# Jobs Control

```bash
command &
```
- & runs the command in background.
- The shell returns control immediately.
- The job gets a job ID like:
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
- Sends SIGTSTP
- Process becomes Stopped
- Moves to background (paused)
### bg
```bash
bg %1
```
- Resume a stopped job in background.
- %1 → job ID
- Process continues running but not attached to terminal input.
### fg
```bash
fg %1
```
- Bring background or stopped job to foreground.
- Process regains terminal control.
- You can interact with it again.