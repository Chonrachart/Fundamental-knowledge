variable
assignment
expansion
parameter expansion
readonly
export

---

# Variable

- Name that holds a value; no spaces around `=`.
- Access with `$name` or `${name}`.

```bash
name="value"
echo $name
echo ${name}
```

# Assignment

- `var=value` — no spaces; no `$` on left.
- Variables are untyped; store strings.

```bash
count=10
path="/etc/config"
```

# Expansion

- `$var` expands to value.
- `${var}` needed when followed by letters: `echo ${var}_suffix`.
- Unset variable expands to empty string.

# Parameter Expansion

- `${var:-default}` — use default if unset or empty.
- `${var:=default}` — assign default if unset or empty.
- `${#var}` — length of string.
- `${var%pattern}` — remove shortest suffix match.
- `${var#pattern}` — remove shortest prefix match.

```bash
name=""
echo ${name:-"guest"}    # guest
echo ${#name}            # 0
file="archive.tar.gz"
echo ${file%.gz}         # archive.tar
```

# Readonly

- `readonly var` — cannot be changed.
- `declare -r var=value` — same effect.

# Export

- `export var` — makes variable available to child processes.
- Without export, child does not see the variable.

```bash
export PATH="/usr/local/bin:$PATH"
```
