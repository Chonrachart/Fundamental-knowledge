# Basic File and Text Manipulation

# Overview
- Linux treats everything as a file: regular files, directories, devices, and pipes all share the same `open/read/write` interface.
- Every process has three default file descriptors: `stdin (0)`, `stdout (1)`, `stderr (2)` — redirection and pipes rewire these.
- Commands are composable: pipe `|` chains stdout of one process to stdin of the next.

# Architecture
```text
stdin  (0) ─────► Process ─────► stdout (1)
                     │
                     └──────────► stderr (2)

Pipeline:
  cmd1 | cmd2 | cmd3
  stdout(cmd1) → stdin(cmd2) → stdin(cmd3)

Redirection:
  cmd > file       stdout → file (overwrite)
  cmd >> file      stdout → file (append)
  cmd < file       file   → stdin
  cmd 2> err.log   stderr → file
  cmd > /dev/null 2>&1    discard both stdout and stderr
```
# Core Building Blocks

### Navigating Files and Directories

```bash
ls                  # list directory contents
ls -l               # long format: permissions, owner, size, timestamp
ls -la              # include hidden files (starting with .)
ls -d <dir>         # show the directory itself, not its contents

cd <path>           # change working directory (calls chdir() syscall)
cd ~                # go to home directory
cd -                # go back to previous directory
pwd                 # print absolute path of current directory
```

`ls -l` first character — file type:

| Char | Type |
|---|---|
| `-` | regular file |
| `d` | directory |
| `l` | symbolic link |
| `s` | socket |
| `p` | named pipe |
| `c` | character device (tty, keyboard) |
| `b` | block device (disk, partition) |

Path symbols: `/` root · `~` home · `.` current · `..` parent

### Creating and Removing

```bash
mkdir <dir>         # create directory
mkdir -p a/b/c      # create parent directories as needed
touch <file>        # create empty file (or update timestamp if exists)

rm <file>           # remove file
rm -r <dir>         # remove directory recursively
rm -f <file>        # force removal (no error if missing)
rmdir <dir>         # remove empty directory only
```
- `rm` removes the directory entry; actual data is freed when link count reaches 0.

### Copying and Moving

```bash
cp <src> <dest>         # copy file (creates new inode at dest)
cp -r <dir> <dest>      # copy directory recursively
cp * <dest>             # copy all non-hidden files in current directory

mv <src> <dest>         # move or rename
                        # same filesystem: renames inode pointer (no data copy)
                        # different filesystem: copies data + removes source
```
- `mv` on the same filesystem renames the directory entry; no data is copied.

### Viewing File Content

```bash
cat <file>          # dump entire file to stdout
less <file>         # page through file (q to quit, / to search)
head -n 20 <file>   # first 20 lines (default 10)
tail -n 20 <file>   # last 20 lines (default 10)
tail -f <file>      # follow file in real time (for logs)
wc -l <file>        # count lines  (-w words, -c bytes)
zcat <file>.gz      # view gzip-compressed file without extracting
```
- `tail -f` follows a growing file in real time — standard tool for watching live logs.

### grep and Redirection

```bash
grep <pattern> <file>     # search lines matching pattern
grep -i <pattern> <file>  # case-insensitive
grep -w <pattern> <file>  # whole-word match only
grep -v <pattern> <file>  # invert: lines NOT matching
grep -r <pattern> <dir>   # recursive search in directory
grep -c <pattern> <file>  # count matching lines
grep -A3 <pattern> <file> # context after match 3 line
grep -B3 <pattern> <file> # context before match 3 line
grep -C3 <pattern> <file> # context around match 3 line
```

Regex anchors: `.` any char · `^` start of line · `$` end of line

```bash
# redirection
cmd > file           # stdout → file (overwrite)
cmd >> file          # stdout → file (append)
cmd 2> error.log     # stderr → file
cmd > /dev/null 2>&1 # discard all output
cmd1 | cmd2          # pipe stdout of cmd1 to stdin of cmd2
```

File descriptors: `0` stdin · `1` stdout · `2` stderr
- File descriptors: `0=stdin`, `1=stdout`, `2=stderr` — redirection rewires these per-process.
- `>` overwrites; `>>` appends — don't mix them up on important files.
- `2>&1` redirects stderr to wherever stdout currently points (order matters).
- `/dev/null` discards everything written to it — use to suppress unwanted output.
- `grep -r` without a path searches the current directory recursively.

### Text Processing Utilities

```bash
# cut — extract fields or characters per line
cut -d',' -f2 file.csv       # field 2, comma-delimited
cut -c1-5 file.txt           # characters 1–5 per line

# sort — sort lines
sort file.txt                # alphabetical ascending
sort -n numbers.txt          # numeric sort
sort -r file.txt             # reverse order
sort -u file.txt             # remove duplicates
sort -t',' -k2 data.csv      # sort by field 2, comma-delimited

# here-document — feed multi-line string as stdin
cat >> /etc/config << EOF
key=value
other=data
EOF
```

Related notes:
- [02-Advance-text-manipulation](./02-Advance-text-manipulation%20copy.md)

### Shell History

```bash
history          # show command history (~/.bash_history)
Ctrl + R         # reverse search through history (repeat to go further back)
!!               # repeat last command
!<n>             # repeat command number n
```
