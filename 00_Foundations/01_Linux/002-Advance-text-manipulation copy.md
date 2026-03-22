# Advanced Text Manipulation

- `sed` and `awk` are stream processors: they read input line by line and transform it without loading the whole file.
- `sed` is best for substitution, deletion, and line-range edits on structured text.
- `awk` is best when you need field extraction, arithmetic, or conditional logic per line.


# Stream Processing Model

```text
Input (file or stdin)
        |
        v
Read one line at a time
        |
        v
Apply pattern/command (sed) or pattern/action (awk)
        |
        v
Write result to stdout
        |
        v
Next line…

Pipeline example:
  cat access.log | sed 's/GET/POST/g' | awk '$9 == 200 {print $7}'
```


# Mental Model

```text
sed 's/old/new/g' file
        |
        v
Read line
        |
        v
Does line match address/pattern? → no:  print as-is
                                 → yes: apply command (s, d, p, …)
        |
        v
Print result to stdout (unless -n suppresses it)
        |
        v
Repeat for each line
***********************************************
awk '/pattern/ { action }' file
        |
        v
Read line → split into fields $1 $2 … $NF
        |
        v
Does line match pattern? → no:  skip (unless default action)
                         → yes: execute action block
        |
        v
Print / compute / accumulate
        |
        v
END block runs once after all lines are processed
```


# Core Building Blocks

### sed (Stream Editor)

```bash
# substitution — most common use
sed 's/old/new/'     file    # replace first match per line
sed 's/old/new/g'    file    # replace all matches per line (global)
sed 's/old/new/gi'   file    # global + case-insensitive
sed 's/old/new/2'    file    # replace 2nd occurrence only

# edit file in-place
sed -i 's/old/new/g' file         # modify file directly
sed -i.bkp 's/old/new/g' file     # modify + keep backup as file.bkp

# suppress default print, explicit print
sed -n 's/old/new/p' file         # print only lines where substitution happened

# delete lines
sed '/pattern/d'     file    # delete lines matching pattern
sed '3d'             file    # delete line 3
sed '3,7d'           file    # delete lines 3–7
sed '/^$/d'          file    # delete blank lines

# print specific lines
sed -n '10,20p'          file   # print lines 10–20
sed -n '/start/,/end/p'  file   # print between pattern markers
```

Common sed recipes:

```bash
# remove leading whitespace
sed 's/^[[:space:]]*//' file

# comment out lines matching a pattern
sed '/pattern/s/^/#/' file

# replace string in all .conf files under /etc
find /etc -name "*.conf" | xargs sed -i 's/old/new/g'
```
- `sed` default: prints every line; `-n` suppresses all output (pair with `p` flag to print selectively).
- `sed -i` edits in-place — always test without `-i` first; use `-i.bkp` as a safety net.

### awk

```bash
# basic structure
awk '{ print $1, $3 }' file           # print field 1 and 3 (whitespace-delimited)
awk -F',' '{ print $2 }' file.csv     # comma delimiter, field 2
awk 'NR==5 { print }' file            # print line 5 only
awk 'NR>=5 && NR<=10' file            # print lines 5–10
awk '/pattern/ { print $0 }' file     # print lines matching pattern
```

Built-in variables:

| Variable | Meaning |
|---|---|
| `$0` | entire current line |
| `$1`, `$2`… | field 1, field 2… |
| `$NF` | last field |
| `NR` | current line number |
| `NF` | number of fields in current line |
| `FS` | input field separator (default: whitespace) |
| `OFS` | output field separator |

```bash
# sum a column
awk '{ sum += $3 } END { print sum }' file

# conditional: print lines where field 5 > 100
awk '$5 > 100 { print $1, $5 }' file

# reformat — username + UID from /etc/passwd
awk -F':' '{ print $1 "\t" $3 }' /etc/passwd

# count occurrences of a value in field 1
awk '{ count[$1]++ } END { for (k in count) print k, count[k] }' file

# BEGIN and END blocks
awk 'BEGIN { print "Start" } { print $0 } END { print "Done" }' file
```
- `awk` splits each line into fields by whitespace by default; use `-F` to change the delimiter.
- `$NF` is always the last field regardless of how many fields a line has.
- `NR` = current line number; `NF` = field count on the current line.
- `awk END {}` runs after all lines — use for totals, summaries, or cleanup output.
- Combine in a pipeline: `sed` for substitution/cleanup first, then `awk` for field logic.

Related notes:
- [01-Basic-file-and-text-manipulation](./01-Basic-file-and-text-manipulation.md)


---

# Troubleshooting Guide

### sed substitution makes no change

1. Test without `-i` first: `sed 's/old/new/g' file | head`.
2. Check quoting — use single quotes to prevent shell expansion of pattern.

### awk prints wrong fields or empty output

1. Check delimiter: default is any whitespace run; use `-F` to set explicit delimiter.
2. Print `$0` to see full raw line, then narrow down field number.

### sed -i destroyed file

1. Check for `.bkp` backup if `-i.bkp` was used.
2. Restore from git: `git checkout -- <file>`.

