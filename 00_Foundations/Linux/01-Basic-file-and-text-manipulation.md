# List files and Directory

```bash
ls
```

- Displays directory contents.
- A directory in Linux is a special file containing filename → inode mappings.
- `ls` reads directory entries from the filesystem.
- `ls -l` shows metadata stored in the inode (permissions, owner, 
  size, timestamp).
- `ls -a` show all hiddenfile (files starting with .).
- `ls -la` combines -l and -a.

### Important Detail

- First character in `ls -l`
  - `-` regular file 
  - `d` directory
  - `l` symbolic link
  - `s` socket
  - `p` Pipe (Process pipe)
  - `c` character device (tty, keybord)
  - `b` block device (disk, partition)
- Color in `ls` ()
  - `blue`   Directory
  - `Green`  Executable file
  - `Cyan`   symbolic link
  - `Red`   Archive/compressed

# Change Directory 

```bash
cd [path]
```

- The shell maintains a **current working directory** (CWD).
- `cd` change the CWD of the shell process and When you run `cd`, 
  the shell calls a system call (`chdir()`). 
- `pwd` prints the absolute path current working directory.
  
### Meaning of symbols

- `/` root directory
- `~` user home directory
- `.` current directory
- `..` parent directory
- Default is to home directory

# Make Directory and file

```bash
mkdir <directory_name>
touch <file_name>
```

- `mkdir` creates a new directory entry.
- `touch` creates a new empty file if it does not exist.
- `mkdir` creates a new inode and updates parent directory 
  mapping.

# History

```bash
Ctrl + R
```

- `history` shows previously executed commands.
- Shell history is stored in ~/.bash_history.
- Press `Ctrl + R` repeatedly to cycle through older matches.

# Copy 

```bash
cp <source> <dest>
```

- `cp` duplicates file content.
- `cp * [dest]` copies all non-hidden files in the current directory.
- `cp -r <dir> <dest>` copies a directory recursively.
- Creates a new inode for the destination file.
  
# Move

```bash
mv <source> <dest>
```

- `mv` renames or moves (may just update directory entry).

# Remove

```bash
rm <file>
```

- `rm` remove file.
- `rmdir <directory>` or `rm -r <dir>`  remove directory.
- `rm -f` force the operation.

# Display  content

```bash
cat
less
head
tail
echo
wc <file>
```

- Reads file content and sends to standard output.
  - `cat` viwe entire file 
  - `less` viwe file page by page
  - `head` viwe start file 10 lines by default
  - `tail` viwe end of file 10 lines by default  
  - `echo` display text or print text 
  - `wc <file>` show line word character of file

# Find text and Redirect

```bash
grep <pattern> <file>
cmd1 > file
cmd1 >> file
cmd1 < file
cmd 2> error.log
cmd > /dev/null
```

- `grep <pattern> <file>` searches text.
  - `.` acts as wild card that matches any single character
  - `^` an anchor character that matches the beginning of line.
  - `$` an anchor that matches the end of a line.
- `|` pipes output of one command to another(stdout of one process to 
  stdin of another). <br> ex. `ls | grep .txt`
- `>` redirects stdout, overwrites file.
- `>>` redirects stdout, append file.
- `<` redirects stdin from file.
- `2>` redirects stderr.
- `/dev/null` is a special device that discards data.
- Linux processes communicate via file descriptors:
  - 0 → stdin
  - 1 → stdout
  - 2 → stderr

# Other useful command

```bash
cat <path> << EOFgit dgdgdfsdfssfsd
```
