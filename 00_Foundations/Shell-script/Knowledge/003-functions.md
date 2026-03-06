function
define
call
return
local
arguments

---

# Function

- Reusable block of commands; can take arguments and return exit code.

# Define

- Two syntaxes: `name() { ... }` or `function name { ... }`.

```bash
my_func() {
    echo "Hello"
}

function my_func {
    echo "Hello"
}
```

# Call

- Call by name; arguments passed as `$1`, `$2`, etc.

```bash
my_func
my_func arg1 arg2
```

# Return

- `return N` — exit code (0–255); 0 = success.
- Cannot return arbitrary data; use global variable or `echo` + command substitution.

```bash
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "No root"
        return 1
    fi
    return 0
}
```

# Local

- `local var=value` — variable only inside function; does not affect caller.

```bash
my_func() {
    local count=10
    echo $count
}
```

# Arguments

- `$1`, `$2`, ... — positional parameters.
- `$#` — number of arguments.
- `$@` — all arguments as separate words.
- `$*` — all arguments as single string.

```bash
parse_args() {
    if [ "$#" -lt 2 ]; then
        echo "Need at least 2 args"
        exit 1
    fi
    first=$1
    second=$2
}
```
