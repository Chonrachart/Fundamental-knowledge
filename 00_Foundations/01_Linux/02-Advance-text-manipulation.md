# Advanced Text Manipulation

# Overview

- `sed` and `awk` are stream processors: they read input line by line and transform it without loading the whole file.
- `sed` is best for substitution, deletion, and line-range edits on structured text.
- `awk` is best when you need field extraction, arithmetic, or conditional logic per line.
- 
# Architecture

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
- **Why it exists** — search, replace, delete, or modify text in a stream (file or standard input).
- **What it is** — It processes input line by line. It does not load entire file into memory (stream processing).

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
- **Why it exists** — filter, extract, calculate, and format data.
- **What it is** — a text processing tool. It processes input line by line. It automatically splits each line into fields (columns). Default field separator = whitespace.
- **One-liner** — Two parts: pattern → when to run (default run every line), action → what to do (default {print}).

```bash
awk [option] 'pattern { action }' <file>
awk '{print $1}' file.txt
awk -F: '{print $1}' /etc/passwd
```

- Common Options
  - `-F:` Set field separator (e.g. -F: for /etc/passwd)
  - `-v` var=value Define variable before execution

- example
  ```
  awk -F: -v min_uid=1000 '$3 >= min_uid {print $1}' /etc/passwd
  ```

  - Common Patterns
    - `$1 == "root"'` Match column 1 equals "root"
    - `'$3 > 1000'` Numeric comparison
    - `'/pattern/'` Match line containing pattern
    - `'NR==1'` First line only
    - `'NR>1'` Skip header
    - `'NF==0'` Empty line
    - `'BEGIN { ... }'` Run once before reading input
    - `'END { ... }'` Run once after finishing input

- Common Actions
  - `{print}` Print entire line
  - `{print $1}` Print column 1
  - `{print $1, $3}` Print multiple columns
  - `{sum+=$1}` Add column 1 to variable

Example
```bash
awk '
    /<!--/ {comment=1}
    /-->/ {comment=0; next}
    !comment && /<Connector/ && /protocol="AJP\/1\.3"/ {found=1}
    END {exit !found}' "$TOMCAT_CONFIG"
```
- this awk have 4 pair pattern action.
- if in <!-- comment=1
- if out --> comment=0
- if out comment and have `<Connector` and have `protocol="AJP/1.3"`
  then found=1
- if finish process run once `exit !found` like exit code 0 or 1
