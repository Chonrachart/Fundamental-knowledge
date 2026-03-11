string
array
length
slice
substring

---

# String

- Bash has no separate string type; variables hold strings.
- Concatenate: `"$a$b"` or `"${a}${b}"`.

# Array

- Indexed array: `arr=(a b c)`.
- Access: `${arr[0]}`, `${arr[@]}` (all elements).
- `${#arr[@]}` — number of elements.

```bash
files=(*.txt)
echo ${files[0]}
echo ${files[@]}
```

# Length

- `${#var}` — length of string.
- `${#arr[@]}` — number of array elements.

# Substring

- `${var:offset:length}` — substring from offset.
- `${var:offset}` — from offset to end.

```bash
s="hello"
echo ${s:0:2}    # he
echo ${s:2}      # llo
```

# String Manipulation

- `${var#pattern}` — remove shortest prefix.
- `${var##pattern}` — remove longest prefix.
- `${var%pattern}` — remove shortest suffix.
- `${var%%pattern}` — remove longest suffix.
- `${var/old/new}` — replace first match.
- `${var//old/new}` — replace all.

```bash
path="/usr/local/bin/script"
echo ${path##*/}     # script
echo ${path%/*}      # /usr/local/bin
```
