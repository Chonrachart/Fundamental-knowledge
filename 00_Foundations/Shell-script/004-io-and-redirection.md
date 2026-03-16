# I/O and Redirection

- Every process inherits three open file descriptors: stdin (0), stdout (1), and stderr (2).
- Redirection operators (`>`, `>>`, `<`, `2>`, `&>`) reroute these descriptors to files, pipes, or /dev/null.
- Pipes (`|`) connect stdout of one process to stdin of the next, forming a data processing pipeline.

# Architecture

```text
                        +---------------------------+
    keyboard ------>    |  fd 0  (stdin)             |
                        |                           |
                        |       PROCESS             |
                        |                           |
    terminal <------    |  fd 1  (stdout)            |----> file   (>  >>)
                        |                           |----> pipe   (|)
    terminal <------    |  fd 2  (stderr)            |----> /dev/null
                        |                           |
                        |  fd 3+ (user-opened)       |----> other files
                        +---------------------------+

    Redirection rewires these connections:

    command > file          fd 1 --> file  (overwrite)
    command >> file         fd 1 --> file  (append)
    command 2> file         fd 2 --> file
    command &> file         fd 1 + fd 2 --> file
    command < file          fd 0 <-- file
    cmd1 | cmd2             cmd1 fd 1 --> pipe --> cmd2 fd 0
```

# Mental Model

```text
Data flow through redirections and pipes:

  [1] Shell parses the command line and sets up redirections BEFORE exec
  [2] File descriptors are rewired according to operators (left to right)
  [3] The command runs with its fd table already modified
  [4] Pipes: shell creates a pipe, forks two processes, wires fd 1 -> pipe -> fd 0

  Order matters:
    command > file 2>&1    -->  stderr goes to same file as stdout (correct)
    command 2>&1 > file    -->  stderr goes to terminal, only stdout to file (wrong)
```

```bash
# concrete example: separate stdout and stderr into different files
./deploy.sh > deploy.log 2> deploy_errors.log

# combine both into one file
./deploy.sh > deploy_all.log 2>&1

# pipe chain: find large files, sort by size, show top 5
du -ah /var/log | sort -rh | head -5
```

# Core Building Blocks

### File Descriptors

- A file descriptor (fd) is an integer handle the kernel assigns to every open file/pipe/socket.
- Every process starts with three: stdin (0), stdout (1), stderr (2).
- Additional fds (3, 4, ...) can be opened with `exec`.

```bash
# open fd 3 for writing to a log file
exec 3> /tmp/custom.log
echo "log entry" >&3
exec 3>&-                # close fd 3

# open fd 4 for reading
exec 4< /etc/hostname
read hostname <&4
exec 4<&-                # close fd 4
```

Related notes: [005-errors-and-exit-codes](./005-errors-and-exit-codes.md)

### Output Redirection

- `>` -- redirect stdout to a file (overwrite; creates file if missing).
- `>>` -- redirect stdout to a file (append).
- `2>` -- redirect stderr to a file.
- `&>` -- redirect both stdout and stderr to the same file (Bash shorthand).
- `2>&1` -- redirect stderr to wherever stdout currently points.

```bash
echo "hello" > output.txt        # overwrite
echo "world" >> output.txt       # append

command 2> errors.log            # stderr only
command > all.log 2>&1           # both to same file (portable)
command &> all.log               # both to same file (Bash shorthand)
```

- Redirection order matters: `> file 2>&1` works; `2>&1 > file` does not merge.

Related notes: [001-variables-and-expansion](./001-variables-and-expansion.md)

### Input Redirection and Heredoc

- `<` -- redirect a file into stdin.
- `<<DELIM` -- heredoc: inline multi-line input (variables are expanded).
- `<<'DELIM'` -- heredoc with quoting: no variable expansion (literal).
- `<<<` -- herestring: pass a single string as stdin.

```bash
# input from file
wc -l < /etc/passwd

# heredoc (variables expanded)
cat << EOF
Host: $HOSTNAME
Date: $(date)
EOF

# heredoc (no expansion -- note the quotes)
cat << 'EOF'
Literal $HOSTNAME -- not expanded
EOF

# herestring
grep "root" <<< "root:x:0:0:root:/root:/bin/bash"
```

Related notes: [006-strings-and-arrays](./006-strings-and-arrays.md)

### Pipes

- `|` connects stdout of the left command to stdin of the right command.
- Each command in a pipeline runs in its own subshell.
- `|&` pipes both stdout and stderr (Bash 4+, equivalent to `2>&1 |`).
- Exit code of a pipeline is the exit code of the last command (unless `set -o pipefail`).

```bash
# basic pipe
cat /var/log/syslog | grep "error" | wc -l

# multi-stage pipeline
ps aux | sort -rnk 4 | head -10     # top 10 processes by memory

# pipe stderr too
command |& grep "warning"

# pipefail: fail if any command in the pipeline fails
set -o pipefail
curl -s "$url" | jq '.data' || echo "pipeline failed"
```

- Variables set inside a pipeline are lost (subshell); use process substitution or `lastpipe` to avoid this.

Related notes: [002-control-flow](./002-control-flow.md), [005-errors-and-exit-codes](./005-errors-and-exit-codes.md)

### Discarding Output

- `/dev/null` is a special file that discards all data written to it.
- Use it to suppress unwanted output without losing the exit code.

```bash
# discard stdout only
command > /dev/null

# discard stderr only
command 2> /dev/null

# discard both stdout and stderr
command &> /dev/null

# common pattern: check if user exists without printing output
if id "$user" &> /dev/null; then
    echo "User exists"
fi
```

Related notes: [005-errors-and-exit-codes](./005-errors-and-exit-codes.md)

---

# Troubleshooting Flow (Quick)

```text
Problem: output not going where expected
    |
    v
[1] Is output going to terminal instead of file?
    Check redirect operator: > not | (pipe is not redirect)
    |
    +-- using echo | file --> wrong; use echo > file
    |
    v
[2] Is stderr missing from the log file?
    command > file captures only stdout
    |
    +-- need both --> use command > file 2>&1 or command &> file
    |
    v
[3] Is the file being overwritten instead of appended?
    > overwrites; >> appends
    |
    +-- data lost each run --> switch from > to >>
    |
    v
[4] Is redirect order wrong?
    command 2>&1 > file  -- stderr still goes to terminal
    |
    +-- swap order --> command > file 2>&1
    |
    v
[5] Are pipe variables disappearing?
    Pipes run in subshells; variables do not propagate back
    |
    +-- need variable from pipe --> use process substitution:
        while read line; do ... done < <(command)
```

# Quick Facts (Revision)

- Three default fds: stdin (0), stdout (1), stderr (2).
- `>` overwrites, `>>` appends, `<` reads from file.
- `2>&1` redirects stderr to stdout's current target -- order matters.
- `&>` is Bash shorthand for `> file 2>&1` (redirect both).
- Pipes run each command in a subshell; variables set inside are lost.
- `set -o pipefail` makes a pipeline fail if any command fails (not just the last).
- Heredoc (`<< EOF`) expands variables; quoted heredoc (`<< 'EOF'`) does not.
- `/dev/null` discards output; useful for silent existence checks.
