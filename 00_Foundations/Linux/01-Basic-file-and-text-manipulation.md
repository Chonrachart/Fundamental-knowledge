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
- `<<` redirects stdin from script.
- `2>` redirects stderr.
- `/dev/null` is a special device that discards data.
- `>/dev/null 2>&1` the &1 mean where first file goes.
- Linux processes communicate via file descriptors:
  - 0 → stdin
  - 1 → stdout
  - 2 → stderr

# Other useful command

### EOF

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

---

### Cut

```bash
cut [option] <file>
cat file.txt | cut -d ',' -f2
```

- Use to extract (cut out) specific parts of each line from a file or standrd
  input.
- `cut -d'[delimiter]' <file>` Specifies the delimiter (character separating fields).
  Default delimiter is TAB.
- `cut -d'[delimeter]'-f<field_number> <file>` specify the delimiter and which 
  fields to extract.
- `cut -c1-5 <file>` extarct specific character position.

---

### sort

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

---

### zcat

```bash
zcat syslog.gz
zcat access.log.gz | grep "ERROR"
```

- Print the content of a compressed `.gz` file to stdout without extracting it.

# sed

```bash
sed [option] 'command' <file>
sed 's/old/new/' file.txt
sed -n '1,5p' file.txt
```

- sed (Stream Editor) is used to search, replace, delete, or modify 
  text in a stream (file or standard input).
- It processes input line by line. It does not load entire file into 
  memory (stream processing).

### Common option

- `-n` Suppress automatic printing (only print what you explicitly 
  tell it).
- `-i` Edit file in place (modify original file).
- `-i.bkp` Edit file in place and create .bkp file.
### Common Commands

- `'s/old/new/'` Substitute (replace) first occurrence 
  of "old" with "new" in each line.
- `'s/old/new/g'` Replace all occurrences in each line.
- `'1,5p'` Print lines 1 to 5 (usually used with `-n`).
- `'3d'` Delete line 3. `'2,4d'` delete line 2-4.
- `s/\<cat\>/replace` Match whole word cat (will not match catalog).
- `'/pattern/ s/old/new/' file.txt` `/pattern/` → is an address
  It decides which lines the command applies to.
- `s/want to comment/#&` this & mean entire matched text
  result will #want to comment.
