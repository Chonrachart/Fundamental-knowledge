# Basic File and Text Manipulation

# Overview
- **Why it exists** —
- **What it is** —
- **One-liner** —

# Architecture

# Core Building Blocks

### Navigating Files and Directories
- **What it is** — The shell maintains a **current working directory** (CWD). `cd` change the CWD of the shell process and When you run `cd`, the shell calls a system call (`chdir()`).

```bash
ls
cd [path]
pwd
```

- Displays directory contents.
- A directory in Linux is a special file containing filename → inode mappings.
- `ls` reads directory entries from the filesystem.
- `ls -l` shows metadata stored in the inode (permissions, owner,
  size, timestamp).
- `ls -a` show all hiddenfile (files starting with .).
- `ls -la` combines -l and -a.
- `ls -d` show directory it self(not content in it).
- `ls -la *` show directory and it all child directory.
- `pwd` prints the absolute path current working directory.

#### Important Detail

- First character in `ls -l`
  - `-` regular file
  - `d` directory
  - `l` symbolic link
  - `s` socket
  - `p` Pipe (Process pipe)
  - `c` character device (tty, keyboard)
  - `b` block device (disk, partition)
- Color in `ls` ()
  - `blue`   Directory
  - `Green`  Executable file
  - `Cyan`   symbolic link
  - `Red`   Archive/compressed

#### Meaning of symbols

- `/` root directory
- `~` user home directory
- `.` current directory
- `..` parent directory
- Default is to home directory

### Creating and Removing
- **What it is** — `mkdir` creates a new inode and updates parent directory mapping. `touch` creates a new empty file if it does not exist.

```bash
mkdir <directory_name>
touch <file_name>
rm <file>
```

- `mkdir` creates a new directory entry.
- `mkdir -p` creates parent directory if not have.
- `touch` creates a new empty file if it does not exist.
- `rm` remove file.
- `rmdir <directory>` or `rm -r <dir>`  remove directory.
- `rm -r` remove recursively
- `rm -f` force the operation.

### Copying and Moving
- **What it is** — `cp` duplicates file content. Creates a new inode for the destination file. `mv` renames or moves (may just update directory entry).

```bash
cp <source> <dest>
mv <source> <dest>
```

- `cp * [dest]` copies all non-hidden files in the current directory.
- `cp -r <dir> <dest>` copies a directory recursively.

### Viewing File Content

```bash
cat
less
head
tail
echo
wc <file>
```

- `cat` view entire file
- `less` view file page by page
- `head` view start file 10 lines by default
- `tail` view end of file 10 lines by default
- `tail -f` view real time.
- `echo` display text or print text
- `wc <file>` show line word character of file

### grep and Redirection
- **What it is** — Linux processes communicate via file descriptors: 0 → stdin, 1 → stdout, 2 → stderr.

```bash
grep <pattern> <file>
cmd1 > file
cmd1 >> file
cmd1 < file
cmd 2> error.log
cmd > /dev/null
```

- `grep <pattern> <file>` searches text.
  - `-i` case-insensitive
  - `-q` quite mode
  - `-w` whole match
  - `.` acts as wild card that matches any single character
  - `^` an anchor character that matches the beginning of line.
  - `$` an anchor that matches the end of a line.
- `|` pipes output of one command to another(stdout of one process to
  stdin of another). <br> ex. `ls | grep .txt`
- `>` redirects stdout, overwrites file.
- `>>` redirects stdout, append file.
- `<` redirects stdin from file.
- `<<` redirects stdin from script.
- `2>` redirects stderr.
- `/dev/null` is a special device that discards data.
- `>/dev/null 2>&1` the &1 mean where first file goes.

#### EOF

```bash
cat <path> << EOF
line1
line2
EOF
```

- `<< EOF` starts a here-document.
- `EOF` is a delimiter (marker) that tells the shell where the input ends.
- Everything between `<< EOF` and the ending `EOF` is sent to the command as
  standard input.

### Text Processing Utilities

#### Cut

```bash
cut [option] <file>
cat file.txt | cut -d ',' -f2
```

- Use to extract (cut out) specific parts of each line from a file or standard input.
- `cut -d'[delimiter]' <file>` Specifies the delimiter (character separating fields).
  Default delimiter is TAB.
- `cut -d'[delimeter]'-f<field_number> <file>` specify the delimiter and which
  fields to extract.
- `cut -c1-5 <file>` extract specific character position.

#### sort

```bash
sort [option] <file>
sort -n numbers.txt
sort -u name.txt
sort -t',' -k2 data.csv
```
- Sorts lines of text from a file or standard input.
- By default, sorts in ascending order (dictionary).

Common Options
- `-r` Reverse the result (descending order).
- `-n` Sort numerically instead of alphabetically.
- `-u` unique (remove duplicates)
- `-k<column_num>` specify which column to sort by.
- `-t'[delimeter]` specify which field delimiter (when sorting by columns).

#### zcat

```bash
zcat syslog.gz
zcat access.log.gz | grep "ERROR"
```

- Print the content of a compressed `.gz` file to stdout without extracting it.

### Shell History

```bash
history
Ctrl + R
```

- `history` shows previously executed commands.
- Shell history is stored in ~/.bash_history.
- Press `Ctrl + R` repeatedly to cycle through older matches.
