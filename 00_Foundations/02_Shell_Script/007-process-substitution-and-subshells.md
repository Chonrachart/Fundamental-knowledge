# Process Substitution and Subshells

- Subshells `( )` and command groups `{ }` control whether commands run in a child or the current shell, affecting variable scope and side effects.
- Process substitution `<(cmd)` and `>(cmd)` creates temporary file descriptors (/dev/fd/N) that let commands consume or produce data as if reading/writing files.
- Key distinction: subshells isolate changes (variables, cd, traps); grouping shares them; process substitution bridges commands that expect filenames.

# Architecture

```text
+-----------------------------------------------------+
|                   Parent Shell (PID 100)             |
|                                                      |
|  Variables: X=1, PATH=...                            |
|                                                      |
|  +---------------------+   +----------------------+  |
|  |  Subshell ( )       |   |  Grouping { }        |  |
|  |  PID 101 (fork)     |   |  PID 100 (same!)     |  |
|  |                     |   |                       |  |
|  |  X=2  (local copy)  |   |  X=2  (modifies       |  |
|  |  cd /tmp (local)    |   |        parent X)      |  |
|  |                     |   |  cd /tmp (affects      |  |
|  |  exit -> changes    |   |          parent cwd)  |  |
|  |         discarded   |   |                       |  |
|  +---------------------+   +----------------------+  |
|                                                      |
|  Process Substitution                                |
|  diff <(cmd1) <(cmd2)                               |
|       |          |                                   |
|       v          v                                   |
|  /dev/fd/63  /dev/fd/62    (named pipe / fd)         |
|  [cmd1 stdout] [cmd2 stdout]                         |
+-----------------------------------------------------+
```

# Mental Model

```text
Need to run multiple commands together?
  |
  +--> Do changes need to persist in current shell?
  |       |
  |       +--> YES --> use { cmd1; cmd2; }   (grouping)
  |       +--> NO  --> use ( cmd1; cmd2 )    (subshell)
  |
  +--> Need command output as a "file" argument?
  |       |
  |       +--> Reading output --> <(command)
  |       +--> Writing to input --> >(command)
  |
  +--> Need to isolate side effects (cd, traps, vars)?
          |
          +--> YES --> subshell ( )
          +--> NO  --> grouping { }
```

Example -- comparing output of two commands without temp files:

```bash
# Without process substitution (needs temp files)
sort file1.txt > /tmp/sorted1
sort file2.txt > /tmp/sorted2
diff /tmp/sorted1 /tmp/sorted2

# With process substitution (no temp files)
diff <(sort file1.txt) <(sort file2.txt)
```

# Core Building Blocks

### Subshells `( )`

- Commands run in a forked child process (new PID).
- All variable assignments, `cd`, traps, and options (`set`) are local to the subshell.
- Parent shell is unaffected after the subshell exits.
- Exit code of the subshell is the exit code of its last command.
- `( )` forks a subshell (new PID); all variable/cd/trap changes are discarded on exit.
- Command substitution `$(cmd)` also runs in a subshell but captures stdout into a variable.

```bash
X=1
( X=99; echo "inside: $X" )   # prints 99
echo "outside: $X"             # prints 1

# Isolate cd
( cd /tmp && tar czf backup.tar.gz . )
pwd   # still in original directory
```

- Pipes implicitly create subshells -- variables set inside a pipe segment do not persist:

```bash
echo "hello" | read VAR
echo "$VAR"   # empty! (read ran in a subshell)
```

Related notes: [005-errors-and-exit-codes](./005-errors-and-exit-codes.md), [003-functions](./003-functions.md)

### Command Grouping `{ }`

- Commands run in the current shell -- all side effects persist.
- Syntax requires a space after `{`, a semicolon (or newline) before `}`.
- Useful for combining output of multiple commands into a single redirect.
- `{ }` groups commands in the current shell; changes persist. Requires space after `{` and `;` before `}`.

```bash
# Redirect combined output to a file
{
  echo "=== Header ==="
  date
  uptime
} > report.txt

# Variable persists
{ X=42; }
echo "$X"   # prints 42
```

Related notes: [004-io-and-redirection](./004-io-and-redirection.md), [001-variables-and-expansion](./001-variables-and-expansion.md)

### Process Substitution `<( )` and `>( )`

- `<(command)` -- bash runs `command` in background, provides its stdout as a readable file descriptor (`/dev/fd/N`).
- `>(command)` -- bash provides a writable file descriptor; anything written to it goes to `command`'s stdin.
- Only available in bash (and zsh), not POSIX sh.
- The file descriptor is a named pipe (FIFO) -- data flows once, not seekable.
- `<(cmd)` creates a readable file descriptor from command output; `>(cmd)` creates a writable one.
- Process substitution produces `/dev/fd/N` paths -- they are named pipes, not regular files (not seekable).
- Process substitution requires bash or zsh; it is not available in POSIX sh.

```bash
# Compare two directory listings
diff <(ls /dir1) <(ls /dir2)

# Feed multiple inputs to paste
paste <(cut -f1 data.tsv) <(cut -f3 data.tsv)

# Tee to a log while also piping
command | tee >(grep "ERROR" > errors.log) | next_command

# See what the shell creates
echo <(true)   # prints something like /dev/fd/63
```

Related notes: [004-io-and-redirection](./004-io-and-redirection.md), [000-core](./000-core.md)
- Solutions: process substitution, `lastpipe`, or here-string.

### Avoiding the Subshell Pipe Trap
```bash
# BROKEN -- count is always 0 after loop (subshell)
count=0
cat file.txt | while read -r line; do
  (( count++ ))
done
echo "$count"   # 0

# FIX 1 -- process substitution (no subshell for while)
count=0
while read -r line; do
  (( count++ ))
done < <(cat file.txt)
echo "$count"   # correct count

# FIX 2 -- redirect directly (best if reading a file)
count=0
while read -r line; do
  (( count++ ))
done < file.txt
echo "$count"   # correct count

# FIX 3 -- enable lastpipe (bash 4.2+)
shopt -s lastpipe
count=0
cat file.txt | while read -r line; do
  (( count++ ))
done
echo "$count"   # correct count
```

Related notes: [002-control-flow](./002-control-flow.md), [001-variables-and-expansion](./001-variables-and-expansion.md)
- A common pitfall: variables set inside a piped `while read` loop are lost.
- Pipes (`|`) create implicit subshells -- variables set in a pipe segment do not survive.
- `while read < <(cmd)` avoids the pipe-subshell trap by using process substitution.

---

# Practical Command Set (Core)

```bash
# --- Subshells ---
( cd /tmp && do_work )           # isolate directory change
result=$( complex_command )      # command substitution (also a subshell)
( trap '' INT; long_task )       # ignore SIGINT only in subshell

# --- Grouping ---
{ echo "start"; process; echo "end"; } > log.txt   # combined redirect
{ read -r first; read -r second; } < input.txt      # read two lines

# --- Process Substitution ---
diff <(sort file1) <(sort file2)                    # compare sorted outputs
comm <(sort list1.txt) <(sort list2.txt)             # find common lines
while read -r line; do echo "$line"; done < <(cmd)   # avoid pipe subshell
tee >(gzip > backup.gz) < original.txt               # write and compress

# --- Nested combinations ---
diff <( ssh host1 cat /etc/hosts ) <( ssh host2 cat /etc/hosts )
```


# Troubleshooting Guide

```text
Variable lost after loop/pipe?
  |
  +--> Is the variable set inside a pipe segment?
  |       |
  |       +--> YES --> pipe creates subshell; use < <(cmd) or redirect < file
  |       +--> NO  --> check if inside ( ) subshell by mistake
  |
  +--> Process substitution not working?
  |       |
  |       +--> Check shebang: must be #!/bin/bash, not #!/bin/sh
  |       +--> Confirm <( has no space before (
  |
  +--> Grouping { } syntax error?
  |       |
  |       +--> Space after { ? Semicolon before } ?
  |       +--> { cmd1; cmd2; }   <-- correct
  |       +--> {cmd1; cmd2}      <-- wrong
  |
  +--> Unexpected directory change?
          |
          +--> cd inside { } affects parent -- wrap in ( ) to isolate
```
