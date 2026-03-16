# Shell Scripting (Bash)

- A shell script is a text file containing a sequence of commands executed by a shell interpreter (typically Bash).
- The shell reads the script line by line, performs expansion and word splitting, then executes each resulting command as a child process.
- Scripts automate repetitive tasks; Bash is the most widely used shell on Linux and provides variables, control flow, functions, and I/O redirection.

# Architecture

```text
+--------------------+
|    Script file     |
|   (text + shebang) |
+--------------------+
         |
         v
+--------------------+
|   Shell (Bash)     |
|   reads lines      |
+--------------------+
         |
         v
+--------------------+
|  Lexer / Parser    |
| tokenize + parse   |
+--------------------+
         |
         v
+--------------------+     +---------------------+
|  Word Splitting    |---->|    Expansion         |
|  (IFS-based)       |     | variable, command,   |
+--------------------+     | brace, tilde, glob   |
                           +---------------------+
                                    |
                                    v
                           +---------------------+
                           | Command Execution   |
                           | fork + exec or      |
                           | builtin dispatch    |
                           +---------------------+
                                    |
                                    v
                           +---------------------+
                           |   Exit Status       |
                           |   (0 = success)     |
                           +---------------------+
```

# Mental Model

```text
Script execution flow:

  #!/bin/bash at line 1
      |
      v
  kernel reads shebang --> launches /bin/bash with script as argument
      |
      v
  bash reads line N
      |
      v
  expand variables, command substitution, globs
      |
      v
  split into words (IFS)
      |
      v
  execute command (builtin or external via fork+exec)
      |
      v
  capture exit code ($?)
      |
      v
  read next line (or exit)
```

```bash
#!/bin/bash
# concrete example: script lifecycle
name="world"
today=$(date +%Y-%m-%d)       # command substitution
echo "Hello $name, today is $today"
# bash expands $name and $today, then executes echo
```

# Core Building Blocks

### Shebang and Execution

- First line `#!/bin/bash` or `#!/usr/bin/env bash` tells the kernel which interpreter to use.
- `#!/usr/bin/env bash` searches PATH for bash; more portable across systems.
- Make executable with `chmod +x script.sh`; run with `./script.sh` (subshell) or `source script.sh` (current shell).

```bash
./script.sh        # runs in new subshell; variables do not persist
source script.sh   # runs in current shell; variables persist
bash script.sh     # explicit interpreter; shebang ignored
```

Related notes: [005-errors-and-exit-codes](./005-errors-and-exit-codes.md)

### Bash vs sh

- `sh` is often dash or a minimal POSIX shell; Bash is a superset with extra features.
- Use `#!/bin/bash` when you need arrays, `[[ ]]`, brace expansion, or process substitution.
- Use `#!/bin/sh` only when strict POSIX portability is required.

| Feature       | sh     | bash   |
| :------------ | :----- | :----- |
| Arrays        | No     | Yes    |
| `[[ ]]`       | No     | Yes    |
| `$()`         | Yes*   | Yes    |
| `{1..10}`     | No     | Yes    |

Related notes: [002-control-flow](./002-control-flow.md)

### Quoting

- **Double quotes** `"..."` -- expand variables, `$()`, and escapes (`\`, `$`, backtick).
- **Single quotes** `'...'` -- everything is literal; no expansion at all.
- **Unquoted** -- subject to word splitting and glob expansion; almost always a bug.

```bash
name="world"
echo "Hello $name"    # Hello world   (variable expanded)
echo 'Hello $name'    # Hello $name   (literal)
echo Hello $name      # Hello world   (works but unsafe with spaces)
```

Related notes: [001-variables-and-expansion](./001-variables-and-expansion.md)

### Command Substitution

- `$(command)` runs command in a subshell and substitutes its stdout into the current line.
- Backtick form `` `command` `` is legacy; `$(...)` nests cleanly and is preferred.
- Always double-quote the result to prevent word splitting: `"$(command)"`.

```bash
today=$(date +%Y-%m-%d)
file_count=$(ls *.txt | wc -l)
echo "Found $file_count files on $today"
```

Related notes: [001-variables-and-expansion](./001-variables-and-expansion.md), [004-io-and-redirection](./004-io-and-redirection.md)

### Variables and Expansion

- Variables are untyped strings by default; assigned with `var=value` (no spaces around `=`).
- Parameter expansion provides defaults, substrings, and substitution: `${var:-default}`, `${var#pattern}`.
- Export makes variables available to child processes: `export VAR=value`.

Related notes: [001-variables-and-expansion](./001-variables-and-expansion.md)

### Control Flow

- Conditionals: `if`, `elif`, `else`, `case` for pattern matching.
- Loops: `for`, `while`, `until`; `break` and `continue` to control iteration.
- Test commands: `[[ ]]` for string/file tests, `(( ))` for arithmetic.

Related notes: [002-control-flow](./002-control-flow.md)

### Functions

- Defined with `func_name() { ... }` or `function func_name { ... }`.
- Arguments accessed via `$1`, `$2`, ..., `$@`; return value is an exit code (0-255).
- Functions run in the current shell; use `local` to scope variables.

Related notes: [003-functions](./003-functions.md)

### I/O and Redirection

- Three default file descriptors: stdin (0), stdout (1), stderr (2).
- Redirect with `>`, `>>`, `2>`, `&>`; pipe with `|` to chain commands.
- Here documents (`<<EOF`) and here strings (`<<<`) feed inline input.

Related notes: [004-io-and-redirection](./004-io-and-redirection.md)

### Error Handling and Exit Codes

- Every command returns an exit code: 0 = success, non-zero = failure.
- `set -euo pipefail` enables strict mode: exit on error, undefined variable, pipe failure.
- `trap` registers cleanup handlers for signals and script exit.

Related notes: [005-errors-and-exit-codes](./005-errors-and-exit-codes.md)

### Strings and Arrays

- Bash supports indexed arrays (`arr=(a b c)`) and associative arrays (`declare -A map`).
- String operations: length `${#var}`, substring `${var:offset:length}`, replacement `${var/old/new}`.
- Iterate arrays with `for item in "${arr[@]}"` -- always quote to preserve elements with spaces.

Related notes: [006-strings-and-arrays](./006-strings-and-arrays.md)

### Process Substitution and Subshells

- Subshells `( )` run commands in a child shell; variables do not leak to the parent.
- Command grouping `{ }` runs in the current shell; variables persist.
- Process substitution `<(cmd)` and `>(cmd)` present command I/O as file descriptors.

Related notes: [007-process-substitution-and-subshells](./007-process-substitution-and-subshells.md)

### Practical Patterns

- Standard script template: shebang, strict mode, trap cleanup, usage function, main logic.
- Argument parsing with `getopts` (short options) or manual loop (long options).
- Lock files (`flock`, `mkdir`) prevent concurrent execution; `mktemp` + trap handles temp files.

Related notes: [008-practical-patterns](./008-practical-patterns.md)

---

# Practical Command Set (Core)

```bash
# check which shell is running
echo $SHELL
echo $BASH_VERSION

# run a script
chmod +x script.sh && ./script.sh

# debug a script (print each command before execution)
bash -x script.sh

# syntax check without executing
bash -n script.sh

# source a script (run in current shell)
source script.sh

# check exit code of last command
echo $?

# run with strict mode inline
bash -euo pipefail script.sh
```

# Troubleshooting Flow (Quick)

```text
Problem: script fails or behaves unexpectedly
    |
    v
[1] Shebang: correct interpreter? #!/bin/bash vs #!/bin/sh?
    head -1 script.sh
    |
    v
[2] Permissions: is it executable?
    ls -l script.sh / chmod +x script.sh
    |
    v
[3] Syntax: any parse errors?
    bash -n script.sh
    |
    v
[4] Debug: where does it fail?
    bash -x script.sh   (trace each line)
    |
    v
[5] Variables: unset or empty?
    echo "$var" / set -u to catch
    |
    v
[6] Quoting: word splitting or glob issues?
    check unquoted $var usage
    |
    v
[7] Exit codes: which command returns non-zero?
    echo $? after each suspect command
```

# Quick Facts (Revision)

- Shebang `#!/usr/bin/env bash` is the most portable way to invoke Bash.
- `source script.sh` runs in the current shell; `./script.sh` runs in a subshell.
- Single quotes are literal; double quotes expand variables and command substitution.
- Always quote `"$variable"` to prevent word splitting and glob expansion.
- `$()` is preferred over backticks for command substitution; it nests cleanly.
- `set -euo pipefail` is the standard strict mode for robust scripts.
- Exit code 0 = success; anything else = failure; check with `$?`.
- `bash -x` enables trace mode; `bash -n` checks syntax without running.

# Topic Map

- [001-variables-and-expansion](./001-variables-and-expansion.md) -- Variables, expansion, parameter expansion
- [002-control-flow](./002-control-flow.md) -- if, case, for, while
- [003-functions](./003-functions.md) -- Defining and using functions
- [004-io-and-redirection](./004-io-and-redirection.md) -- stdin, stdout, stderr, pipes
- [005-errors-and-exit-codes](./005-errors-and-exit-codes.md) -- set -e, trap, exit codes
- [006-strings-and-arrays](./006-strings-and-arrays.md) -- String manipulation, arrays
- [007-process-substitution-and-subshells](./007-process-substitution-and-subshells.md) -- Subshells, grouping, process substitution
- [008-practical-patterns](./008-practical-patterns.md) -- Script template, getopts, logging, lock files
