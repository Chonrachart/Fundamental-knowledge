# Functions

- A function is a named, reusable block of commands that runs in the current shell and can accept arguments.
- The caller passes positional parameters; the function executes its body and returns an exit code (0-255).
- Variables are global by default; use `local` to confine them to the function scope.

# Architecture

```text
+--------------------------+
|       Caller / Main      |
|  my_func "arg1" "arg2"   |
+-----------+--------------+
            |
            v
+--------------------------+
|     Function Scope       |
|  $1="arg1"  $2="arg2"   |
|  $#=2       $@=all args  |
|                          |
|  +--------------------+  |
|  |  local variables   |  |
|  |  (not visible to   |  |
|  |   caller)          |  |
|  +--------------------+  |
|                          |
|  +--------------------+  |
|  |  global variables  |  |
|  |  (visible to       |  |
|  |   caller -- leak!) |  |
|  +--------------------+  |
|                          |
|  return N  /  echo val   |
+-----------+--------------+
            |
            v
+--------------------------+
|       Caller / Main      |
|  $? = exit code (0-255)  |
|  capture = $(my_func)    |
+--------------------------+
```

# Mental Model

```text
Function execution lifecycle:

  [1] Define    -->  function body stored in memory (not executed yet)
  [2] Call      -->  shell enters function scope, sets $1..$N from arguments
  [3] Execute   -->  runs commands in body; local vars created/destroyed here
  [4] Return    -->  exit code set via `return N` (or last command's exit code)
  [5] Resume    -->  caller continues; $? holds the return code
```

```bash
# concrete example: function that returns data via echo + captures it
get_hostname() {
    local raw
    raw=$(hostname -f)
    echo "${raw,,}"       # lowercase
}

result=$(get_hostname)    # capture stdout into variable
echo "Host: $result"      # use the captured value
```

# Core Building Blocks

### Defining Functions

- Two equivalent syntaxes; the POSIX form (`name()`) is more portable.

```bash
# POSIX syntax (preferred)
greet() {
    echo "Hello, $1"
}

# Bash keyword syntax
function greet {
    echo "Hello, $1"
}
```

- The body runs in the current shell (not a subshell) -- it can modify global state.
- Functions must be defined before they are called (top of script or sourced file).

Related notes: [001-variables-and-expansion](./001-variables-and-expansion.md)

### Arguments and Parameters

- Arguments are passed after the function name, separated by spaces.
- Inside the function, `$1`, `$2`, ... refer to the function's own arguments (not the script's).

| Variable | Meaning                              |
| :------- | :----------------------------------- |
| `$1..$N` | Positional parameters                |
| `$#`     | Number of arguments                  |
| `$@`     | All arguments as separate words      |
| `$*`     | All arguments as a single string     |
| `$0`     | Script name (not the function name)  |

```bash
log_msg() {
    local level="$1"; shift
    echo "[$level] $*"
}
log_msg "INFO" "Service started on port" "8080"
# output: [INFO] Service started on port 8080
```

- Always quote `"$@"` when passing arguments through to another command.

Related notes: [002-control-flow](./002-control-flow.md)

### Return Values

- `return N` sets the exit code (0-255); 0 = success, non-zero = failure.
- If `return` is omitted, the exit code of the last command in the body is used.
- To return arbitrary data, use `echo` and capture with command substitution.

```bash
# return exit code for boolean check
is_root() {
    [ "$EUID" -eq 0 ]
    return $?
}

if is_root; then
    echo "Running as root"
fi

# return data via echo
get_count() {
    local count
    count=$(wc -l < "$1")
    echo "$count"
}

lines=$(get_count "/etc/passwd")
```

- Do not use `echo` for data and status messages in the same function -- the caller captures all stdout.

Related notes: [005-errors-and-exit-codes](./005-errors-and-exit-codes.md)

### Local Variables and Scope

- Without `local`, variables set inside a function leak into the caller's scope.
- `local var=value` restricts the variable to the function (and its children).
- Always declare loop counters and temporary variables as `local`.

```bash
bad_func() {
    count=10          # GLOBAL -- leaks to caller
}

good_func() {
    local count=10    # LOCAL -- stays inside function
}

bad_func
echo "$count"         # prints 10 (leaked)

good_func
echo "$count"         # still prints 10 from bad_func (good_func did not leak)
```

- `local` is a Bash/Zsh feature; pure POSIX sh does not support it (use subshell instead).

Related notes: [001-variables-and-expansion](./001-variables-and-expansion.md), [006-strings-and-arrays](./006-strings-and-arrays.md)

---

# Practical Command Set (Core)

```bash
# define and call a simple function
greet() { echo "Hello, $1"; }
greet "World"

# capture function output into a variable
result=$(greet "World")

# check function return code
is_root() { [ "$EUID" -eq 0 ]; }
if is_root; then echo "root"; fi

# pass all script arguments to a function
wrapper() { echo "Got $# args: $@"; }
wrapper "$@"

# use shift to process arguments one by one
parse_flags() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -v) verbose=1 ;;
            -f) file="$2"; shift ;;
        esac
        shift
    done
}
```

# Troubleshooting Guide

```text
Problem: function not behaving as expected
    |
    v
[1] Is the function defined before it is called?
    type my_func
    |
    +-- "not found" --> move definition above the call, or source the file
    |
    v
[2] Are variables leaking into / out of the function?
    Add `local` to all internal variables
    |
    +-- still leaking --> check for missing `local` on loop vars (i, line, tmp)
    |
    v
[3] Is return value wrong?
    echo $? right after the call
    |
    +-- unexpected code --> check if a command between `return` and caller reset $?
    +-- data garbled --> function prints debug/status to stdout -- send to stderr instead
    |
    v
[4] Arguments not received correctly?
    Add: echo "args: $# -> $@" at top of function
    |
    +-- wrong count --> caller forgot quotes; use my_func "$var" not my_func $var
    +-- $1 empty --> called without arguments; add argument validation
```

# Quick Facts (Revision)

- Two syntaxes: `name() { ... }` (POSIX) and `function name { ... }` (Bash-only).
- Functions run in the current shell, not a subshell -- they can modify global variables.
- `return N` sets exit code (0-255); use `echo` + `$()` to return arbitrary data.
- `local` keeps variables scoped to the function; without it, they leak to the caller.
- `$@` (quoted) preserves word splitting of arguments; `$*` merges into one string.
- `$#` gives the argument count; `shift` removes `$1` and shifts the rest down.
- A function's `$1..$N` are independent of the script's positional parameters.
- Always quote `"$@"` when forwarding arguments to prevent word splitting.
