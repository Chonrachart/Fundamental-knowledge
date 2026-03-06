stdin
stdout
stderr
redirect
pipe
heredoc

---

# stdin, stdout, stderr

- **stdin** (0): input; default keyboard.
- **stdout** (1): output; default terminal.
- **stderr** (2): error output; default terminal.

# Redirect

- `>` — overwrite stdout.
- `>>` — append stdout.
- `2>` — redirect stderr.
- `&>` or `2>&1` — redirect both to same place.

```bash
echo "log" > file.txt
echo "append" >> file.txt
command 2> error.log
command &> all.log
```

# Pipe

- `|` — stdout of left becomes stdin of right.

```bash
cat file | grep "pattern"
ls -l | wc -l
```

# Heredoc

- Embed multi-line input.

```bash
cat << EOF
Line 1
Line 2
EOF
```

### Suppress variable expansion

- `<< 'EOF'` — literal; no expansion.

# Discard Output

- `>/dev/null` — discard stdout.
- `2>/dev/null` — discard stderr.
- `&>/dev/null` — discard both.

```bash
id "$user" &>/dev/null
```
