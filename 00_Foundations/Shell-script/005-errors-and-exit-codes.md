# Errors and Exit Codes

- Every command returns an exit code (0-255); the shell uses this to decide success or failure.
- Strict mode (`set -euo pipefail`) turns silent failures into immediate, visible errors.
- Traps let you run cleanup logic when a script exits or receives a signal.

# Architecture

```text
+------------------+       exit code       +------------------+
|    Command       |---------------------->|   Shell ($?)     |
| (ls, grep, etc.) |       0 = ok         |                  |
+------------------+       1-255 = fail    +--------+---------+
                                                    |
                          +-------------------------+-------------------------+
                          |                         |                         |
                          v                         v                         v
                   +-------------+          +---------------+         +---------------+
                   |  set -e     |          |  set -o       |         |    trap       |
                   |  (errexit)  |          |  pipefail     |         |  (signal      |
                   |             |          |               |         |   handler)    |
                   | abort on    |          | catch failure |         | run cleanup   |
                   | non-zero    |          | inside pipes  |         | on EXIT/INT/  |
                   +------+------+          +-------+-------+         | TERM/ERR      |
                          |                         |                 +-------+-------+
                          v                         v                         v
                   +------+---------+       +-------+--------+       +-------+--------+
                   | Script aborts  |       | Pipeline exit  |       | Cleanup runs,  |
                   | immediately    |       | = failed cmd   |       | then exit       |
                   +----------------+       +----------------+       +----------------+

set -u (nounset): any reference to an unset variable triggers an error
                   before the command even runs
```

# Mental Model

```text
Defensive scripting pattern:

  [1] set -euo pipefail   -->  catch errors early
  [2] trap cleanup EXIT   -->  guarantee cleanup runs
  [3] write commands       -->  any failure stops the script
  [4] script ends          -->  trap fires, cleanup executes

Error propagation:

  cmd1 | cmd2 | cmd3
    |      |      |
    v      v      v
  exit=1  exit=0  exit=0

  Without pipefail: $? = 0  (last command wins)
  With pipefail:    $? = 1  (first failure wins)
```

```bash
#!/bin/bash
set -euo pipefail

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

curl -sSf "https://example.com/data" > "$TMPFILE"
process_data "$TMPFILE"
# if curl or process_data fails -> script aborts -> trap removes TMPFILE
```

# Core Building Blocks

### Exit Codes

- Every command returns an integer 0-255; `0` = success, non-zero = failure.
- `$?` holds the exit code of the most recently executed command.
- `exit N` terminates the script with code N; bare `exit` uses the last command's code.
- Convention: `1` = general error, `2` = misuse of builtin, `126` = not executable, `127` = command not found, `128+N` = killed by signal N.

```bash
ls /tmp
echo $?    # 0

ls /nonexistent
echo $?    # 2

if [ ! -f "$file" ]; then
    echo "File not found" >&2
    exit 1
fi
```

Related notes: [002-control-flow](./002-control-flow.md), [004-io-and-redirection](./004-io-and-redirection.md)

### Strict Mode (set -euo pipefail)

- `set -e` (errexit) -- abort the script immediately when any command returns non-zero.
- `set -u` (nounset) -- treat references to unset variables as errors.
- `set -o pipefail` -- a pipeline's exit code is the rightmost failed command, not the last command.
- Combine all three at the top of every script: `set -euo pipefail`.

```bash
#!/bin/bash
set -euo pipefail

# set -e: this line aborts the script if /bad/path does not exist
ls /bad/path

# set -u: this aborts because $UNDEFINED was never assigned
echo "$UNDEFINED"

# set -o pipefail: pipeline fails because grep fails (no match)
echo "hello" | grep "world" | cat
```

- Exceptions to `set -e`: commands in `if` conditions, `||`/`&&` chains, and `!`-prefixed commands do not trigger errexit.

Related notes: [001-variables-and-expansion](./001-variables-and-expansion.md)

### Trap and Signal Handling

- `trap 'commands' SIGNAL` -- register a handler that runs when the shell receives SIGNAL.
- Common signals: `EXIT` (always fires on exit), `INT` (Ctrl-C), `TERM` (kill default), `ERR` (on error, with `set -e`).
- Traps are inherited by subshells only if explicitly set; functions share the parent shell's traps.
- Multiple traps on the same signal: the last `trap` command wins (overrides previous).

```bash
cleanup() {
    echo "Removing temp files..."
    rm -f "$TMPFILE" "$LOCKFILE"
}

trap cleanup EXIT          # runs on normal exit or error exit
trap 'echo "Interrupted"; exit 130' INT TERM

TMPFILE=$(mktemp)
LOCKFILE="/var/lock/myscript.lock"
```

- `trap -l` -- list all signal names and numbers.
- `trap '' SIGNAL` -- ignore a signal (empty string = ignore).
- `trap - SIGNAL` -- reset a signal to its default behavior.

Related notes: [003-functions](./003-functions.md)

### Debugging (set -x)

- `set -x` (xtrace) -- print each command and its expanded arguments before execution.
- `set +x` -- turn tracing off.
- `bash -x script.sh` -- run an entire script in trace mode without editing it.
- `PS4='+ ${BASH_SOURCE}:${LINENO}: '` -- customize the trace prefix to show file and line number.
- `BASH_XTRACEFD=5` -- redirect trace output to a file descriptor (keeps stderr clean).

```bash
#!/bin/bash
set -euo pipefail

PS4='+ ${BASH_SOURCE}:${LINENO}: '
set -x

name="world"
echo "hello $name"
# trace output: + script.sh:7: echo 'hello world'
```

Related notes: [004-io-and-redirection](./004-io-and-redirection.md)

---

# Troubleshooting Guide

```text
Problem: script fails silently or behaves unexpectedly
    |
    v
[1] Is strict mode enabled?
    grep 'set -euo pipefail' script.sh
    |
    +-- missing --> add set -euo pipefail at the top
    |
    v
[2] Is a trap not firing?
    |
    +-- trap on ERR but no set -e --> ERR trap requires errexit
    +-- trap overwritten later   --> only the last trap per signal is active
    +-- subshell trap            --> traps are not inherited by subshells
    |
    v
[3] Pipeline hiding failures?
    cmd1 | cmd2 | cmd3 ; echo $?
    |
    +-- $? shows 0 but cmd1 failed --> add set -o pipefail
    +-- check individual codes     --> echo ${PIPESTATUS[@]}
    |
    v
[4] Still unclear?
    Run with set -x or bash -x script.sh to trace execution
```

# Quick Facts (Revision)

- Exit code `0` = success; anything `1-255` = failure.
- `$?` holds the exit code of the last command; `${PIPESTATUS[@]}` holds all pipeline exit codes.
- `set -euo pipefail` is the standard "strict mode" for production scripts.
- `set -e` does not trigger inside `if`, `||`, `&&`, or `!` constructs.
- `trap 'cmd' EXIT` always fires -- normal exit, error exit, or signal-caused exit.
- `trap 'cmd' ERR` only fires if `set -e` (errexit) is also active.
- `set -x` prints every command before execution; `PS4` controls the trace prefix.
- Signal `128+N` means the process was killed by signal N (e.g., 130 = SIGINT, 137 = SIGKILL).
