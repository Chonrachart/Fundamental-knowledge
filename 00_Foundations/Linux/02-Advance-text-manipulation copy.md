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
  of "old" with "new" in each line. can use `|` instead `/`
- `'s/old/new/g'` Replace all occurrences in each line.
- `'1,5p'` Print lines 1 to 5 (usually used with `-n`).
- `'3d'` Delete line 3. `'2,4d'` delete line 2-4.
- `'/pattern/d'` delete line that match pattern.
- `s/\<cat\>/replace` Match whole word cat (will not match catalog).
- `'/pattern/ s/old/new/' file.txt` `/pattern/` → is an address
  It decides which lines the command applies to.
- `s/want to comment/#&` this & mean entire matched text
  result will #want to comment.
- `i\` Insert text BEFORE the matched line
- `a\` append text after the matched line.

# awk
```bash
awk [option] 'pattern { action }' <file>
awk '{print $1}' file.txt
awk -F: '{print $1}' /etc/passwd
```

- Two parts:
  - pattern → when to run (default run every line)
  - action → what to do (default {print})
- awk is a text processing tool used to filter, extract, calculate, and format data.
- It processes input line by line.
- It automatically splits each line into fields (columns).
- Default field separator = whitespace.

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
  - `'NR>1`' Skip header
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