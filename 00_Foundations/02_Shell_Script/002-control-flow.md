# Control Flow

- Control flow directs execution order using conditionals (`if`, `case`) and loops (`for`, `while`, `until`).
- Bash evaluates conditions based on exit codes: 0 = true (success), non-zero = false (failure).
- `[[ ]]` is the preferred test construct in bash -- no word splitting, supports globs and regex.

# Architecture

```text
Control Flow Decision Tree:

                       +------------------+
                       |  Start of block  |
                       +------------------+
                               |
              +----------------+----------------+
              |                |                |
              v                v                v
       +-----------+    +-----------+    +-----------+
       | Condition |    |  Pattern  |    | Iteration |
       |  (if)     |    |  (case)   |    |  (loop)   |
       +-----------+    +-----------+    +-----------+
              |                |                |
              v                v                v
       +----------+     +-----------+    +-----------+
       | test cmd |     | match $var|    | for item  |
       | [ ] or   |     | against   |    | while cond|
       | [[ ]]    |     | patterns  |    | until cond|
       +----------+     +-----------+    +-----------+
         |    |            |  |  |         |       |
         v    v            v  v  v         v       v
       true  false       p1 p2  *)      body    done
         |    |            |  |  |         |
         v    v            v  v  v         |
       then  else/       matched ;;     loop back
             elif          |             (re-check
                         esac             condition)
```

# Mental Model

```text
How bash evaluates every condition:

  [1] Run a command (test, [, [[, or any command)
  [2] Check exit code:  $?
         |
         +-- 0   --> "true"  --> execute then/body
         +-- 1+  --> "false" --> skip to else/elif/done

  Key insight: "if grep -q pattern file" works because
  grep returns 0 (found) or 1 (not found) -- no [ ] needed.
```

```bash
# concrete example: exit code drives the condition
if grep -q "root" /etc/passwd; then
    echo "root user exists"     # grep returned 0
else
    echo "no root user"         # grep returned non-zero
fi
```

# Core Building Blocks

### Conditionals (if / elif / else)

- `if command; then ... fi` -- executes `then` block when command exits 0.
- `elif` chains additional conditions; `else` is the fallback.
- Any command can be a condition -- not just `test` or `[ ]`.
- Combine conditions with `&&` (and) and `||` (or).
- Bash conditions are exit codes: 0 = true, non-zero = false.
- Any command can serve as a condition -- `if grep -q`, `while read`, `until ping`.

```bash
if [ "$x" -eq 5 ]; then
    echo "x is 5"
elif [ "$x" -gt 5 ]; then
    echo "x is greater"
else
    echo "x is less"
fi

# using a command directly as condition
if ping -c1 -W1 host &>/dev/null; then
    echo "host reachable"
fi
```

Related notes: [005-errors-and-exit-codes](./005-errors-and-exit-codes.md)

### Test Expressions ([ ] vs [[ ]])

- `[ condition ]` -- POSIX `test` builtin; spaces required around brackets.
- `[[ condition ]]` -- bash keyword; safer, no word splitting, no pathname expansion.
- `[ ]` is POSIX `test`; `[[ ]]` is bash-specific, safer, and more powerful.
- Always quote variables inside `[ ]` to prevent word splitting; `[[ ]]` handles this automatically.
- Numeric operators: `-eq`, `-ne`, `-lt`, `-le`, `-gt`, `-ge`.
- String operators: `=`, `!=`, `-z` (empty), `-n` (non-empty).
- File operators: `-f` (regular file), `-d` (directory), `-e` (exists), `-r` (readable), `-w` (writable), `-x` (executable).
- `[[ ]]` extras: `==` for glob matching, `=~` for regex, `&&` and `||` inside brackets.

```bash
# POSIX test -- must quote variables to avoid word splitting
[ -f /etc/passwd ]
[ "$var" = "yes" ]
[ "$EUID" -ne 0 ]

# bash [[ ]] -- no quoting issues, supports patterns
[[ "$file" == *.txt ]]
[[ "$input" =~ ^[0-9]+$ ]]
[[ -n "$var" && -f "$file" ]]
```

| Feature                | `[ ]` (test)   | `[[ ]]` (bash) |
| :--------------------- | :------------- | :-------------- |
| POSIX compatible       | yes            | no (bash only)  |
| Word splitting on vars | yes (quote!)   | no              |
| Glob matching (`==`)   | no             | yes             |
| Regex (`=~`)           | no             | yes             |
| Logical `&&` `||`      | use `-a` `-o`  | yes, natively   |

Related notes: [001-variables-and-expansion](./001-variables-and-expansion.md)

### Pattern Matching (case)

- `case "$var" in pattern) ... ;; esac` -- matches value against patterns.
- Patterns use glob syntax: `*` any string, `?` single char, `[abc]` character class.
- `|` separates multiple patterns for the same block.
- `*)` is the default / catch-all (like `else`).
- `;;` ends a branch; `;&` falls through to next branch (bash 4+).
- `case` uses glob patterns, not regex; use `|` to combine patterns.
- `shopt -s nullglob` makes unmatched globs expand to nothing instead of the literal pattern.

```bash
case "$1" in
    start|restart)
        echo "Starting service"
        ;;
    stop)
        echo "Stopping service"
        ;;
    status)
        echo "Checking status"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
```

Related notes: [003-functions](./003-functions.md)

### Loops (for / while / until)
```bash
# iterate over a list
for f in *.log; do
    echo "Processing $f"
done

# C-style loop
for ((i=1; i<=5; i++)); do
    echo "$i"
done

# read file line by line
while IFS= read -r line; do
    echo "$line"
done < file.txt

# retry until success
until ping -c1 host &>/dev/null; do
    sleep 1
done
echo "host is up"
```

Related notes: [004-io-and-redirection](./004-io-and-redirection.md), [001-variables-and-expansion](./001-variables-and-expansion.md)
- `for var in list; do ... done` -- iterate over a list of items.
- `for ((i=0; i<n; i++)); do ... done` -- C-style for loop.
- `while command; do ... done` -- loop while command exits 0.
- `until command; do ... done` -- loop until command exits 0 (inverse of while).
- `break` exits the loop; `continue` skips to next iteration.
- `while read` is the standard pattern for processing lines from a file or pipe.
- `while IFS= read -r line` is the safe idiom for reading lines (preserves whitespace, no backslash interpretation).
- `break` exits a loop; `continue` skips to the next iteration; both accept a numeric depth argument.


---

# Troubleshooting Guide

```text
Problem: condition not evaluating as expected
    |
    v
[1] Is it an exit code issue?
    run the command manually; check echo $?
    |
    +-- non-zero when expecting 0 --> fix the command
    |
    v
[2] Using [ ] with unquoted variable?
    [ $var = "yes" ]  --> fails if var is empty or has spaces
    |
    +-- yes --> quote it: [ "$var" = "yes" ]  or use [[ ]]
    |
    v
[3] Comparing numbers with string operators?
    [ "$x" = "5" ]   --> string compare (works but fragile)
    [ "$x" -eq 5 ]   --> numeric compare (correct)
    |
    +-- wrong operator --> use -eq/-gt/-lt for numbers, =  /!= for strings
    |
    v
[4] Loop not iterating?
    for f in *.log   --> if no .log files, glob stays literal "*.log"
    |
    +-- yes --> use: shopt -s nullglob  (empty list if no match)
    |
    v
[5] Infinite loop?
    while/until condition never changes
    |
    +-- check that loop body modifies the condition variable
    +-- add a counter with break as safety net
```
