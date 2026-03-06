if
test
case
for
while
until

---

# if

- Condition in `[ ]` or `[[ ]]`; `[[ ]]` is bash-specific, safer for strings.

```bash
if [ "$x" -eq 5 ]; then
    echo "x is 5"
elif [ "$x" -gt 5 ]; then
    echo "x is greater"
else
    echo "x is less"
fi
```

# test and [ ]

- `[ condition ]` — same as `test condition`; spaces required.
- Numeric: `-eq`, `-ne`, `-lt`, `-le`, `-gt`, `-ge`.
- String: `=`, `!=`, `-z` (empty), `-n` (non-empty).
- File: `-f` (file), `-d` (dir), `-e` (exists), `-r` (readable).

```bash
[ -f /etc/passwd ]
[ "$var" = "yes" ]
[ "$EUID" -ne 0 ]
```

# [[ ]] (Bash)

- No word splitting; `==` supports glob; `=~` for regex.

```bash
[[ "$x" == *.txt ]]
[[ "$x" =~ ^[0-9]+$ ]]
```

# case

- Pattern matching; `*` as default.

```bash
case "$1" in
    start)
        echo "Starting"
        ;;
    stop)
        echo "Stopping"
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac
```

# for

- Iterate over list or range.

```bash
for i in 1 2 3; do
    echo $i
done

for i in {1..10}; do
    echo $i
done

for f in *.txt; do
    echo "$f"
done
```

# while and until

- `while` — loop while condition true.
- `until` — loop until condition true.

```bash
while read line; do
    echo "$line"
done < file.txt

until ping -c1 host &>/dev/null; do
    sleep 1
done
```
