# Variables and Expansion

- Variables are named storage locations in the shell; assigned with `var=value` (no spaces), accessed with `$var` or `${var}`.
- During command parsing, the shell expands variables, performs word splitting, and applies globbing before execution.
- Variables live in shell scope by default; `export` promotes them to the environment so child processes inherit them.

# Architecture

```text
+---------------------+
|   Script / User     |
|   name="alice"      |   [1] Assignment: store in shell memory
+---------------------+
          |
          v
+---------------------+     +---------------------+
|   Shell Variables   |     |   Environment Vars  |
|   (current shell)   |---->|   (inherited by     |
|   name="alice"      |     |    child processes)  |
|   count=10          |     |   PATH, HOME, ...   |
+---------------------+     +---------------------+
     export name               |
          |                    |
          v                    v
+---------------------+     +---------------------+
|   Command Parsing   |     |   Child Process     |
|   echo "hi $name"   |     |   sees exported     |
|        |             |     |   vars only         |
|        v             |     +---------------------+
|   Expansion Phase    |
|   echo "hi alice"    |
|        |             |
|        v             |
|   Word Splitting     |
|   Glob Expansion     |
|        |             |
|        v             |
|   Execute Command    |
+---------------------+
```

# Mental Model

```text
Expansion order (left to right during command parsing):

  [1] Brace expansion        {a,b,c}
  [2] Tilde expansion        ~/dir
  [3] Parameter expansion    ${var}, ${var:-default}
  [4] Command substitution   $(cmd)
  [5] Arithmetic expansion   $((1+2))
  [6] Word splitting         unquoted results split on IFS
  [7] Pathname expansion     *.txt, /etc/*/
```

```bash
# concrete example: parameter expansion + word splitting pitfall
file="my document.txt"

# WRONG -- word splitting breaks this into two args
cat $file
# cat: my: No such file or directory
# cat: document.txt: No such file or directory

# RIGHT -- double quotes prevent word splitting
cat "$file"
```

# Core Building Blocks

### Variables and Assignment

- `var=value` -- no spaces around `=`; no `$` on the left side.
- Variables are untyped by default; they store strings.
- `declare -i num=5` -- declare as integer (arithmetic on assignment).
- `declare -a arr=(a b c)` -- declare indexed array.
- Naming rules: letters, digits, underscore; must start with letter or underscore.
- Assignment: `var=value` with no spaces; `$` only on access, never on assignment.

```bash
name="alice"
count=10
path="/etc/config"
declare -i total=5+3    # total is 8
```

Related notes: [006-strings-and-arrays](./006-strings-and-arrays.md)
- Unset variables silently expand to empty string unless `set -u` (nounset) is enabled.

### Expansion

- `$var` -- simple expansion; value substituted in place.
- `${var}` -- braced form; required when adjacent to other characters (`${var}_suffix`).
- `$(command)` -- command substitution; output of command replaces the expression.
- `$((expr))` -- arithmetic expansion; evaluates math expression.
- Unset or empty variable expands to empty string (no error by default).
- Always double-quote variable expansions (`"$var"`) to prevent word splitting and globbing.
- Expansion order: brace, tilde, parameter, command substitution, arithmetic, word splitting, pathname.
- `${var##*/}` acts like `basename`; `${var%/*}` acts like `dirname`.

```bash
echo "$name"              # alice
echo "${name}_home"       # alice_home
echo "Today is $(date)"   # Today is Mon Mar 16 ...
echo "$((5 + 3))"         # 8
```

Related notes: [004-io-and-redirection](./004-io-and-redirection.md)

### Parameter Expansion

- `${var:-default}` -- use default if var is unset or empty.
- `${var:=default}` -- assign default if var is unset or empty.
- `${var:-default}` provides a fallback; `${var:=default}` provides and assigns a fallback.
- `${var:+alternate}` -- use alternate if var IS set and non-empty.
- `${var:?message}` -- exit with error message if var is unset or empty.
- `${#var}` -- length of string value.
- `${var%pattern}` -- remove shortest suffix match.
- `${var%%pattern}` -- remove longest suffix match.
- `${var#pattern}` -- remove shortest prefix match.
- `${var##pattern}` -- remove longest prefix match.
- `${var/pattern/replacement}` -- replace first match.
- `${var//pattern/replacement}` -- replace all matches.

```bash
name=""
echo "${name:-guest}"         # guest
echo "${name:=guest}"         # guest (also assigns)

file="archive.tar.gz"
echo "${file%.gz}"            # archive.tar
echo "${file%%.*}"            # archive
echo "${file#*.}"             # tar.gz
echo "${file##*.}"            # gz

path="/home/user/file.txt"
echo "${path/user/admin}"     # /home/admin/file.txt
```

Related notes: [006-strings-and-arrays](./006-strings-and-arrays.md)

### Readonly and Export
```bash
readonly PI=3.14159
PI=3.14               # error: PI: readonly variable

export PATH="/usr/local/bin:$PATH"
export EDITOR="vim"

# verify a variable is exported
declare -p PATH       # declare -x PATH="..."
```

Related notes: [005-errors-and-exit-codes](./005-errors-and-exit-codes.md), [003-functions](./003-functions.md)
- `readonly var` -- prevents reassignment or unsetting; error if attempted.
- `declare -r var=value` -- same effect as readonly.
- `export var` -- promotes shell variable to environment; child processes inherit it.
- `export var=value` -- assign and export in one step.
- Without export, a variable exists only in the current shell.
- `env` or `printenv` -- list all exported environment variables.
- `export` makes a variable available to child processes; without it, the variable is shell-local.
- `readonly` is permanent for the current shell session; cannot be unset.
