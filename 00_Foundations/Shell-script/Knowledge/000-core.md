overview of

    shebang
    execution
    bash vs sh
    quoting
    command substitution

---

# Shebang

- First line of script: `#!/bin/bash` or `#!/usr/bin/env bash`
- Tells the system which interpreter to use.
- `#!` must be at the very start; path follows.

```bash
#!/bin/bash
echo "Hello"
```

### env vs direct path

- `#!/usr/bin/env bash` — finds `bash` in PATH; more portable.
- `#!/bin/bash` — direct path; may differ on some systems.

# Execution

- Make executable: `chmod +x script.sh`
- Run: `./script.sh` (current dir) or `bash script.sh` (explicit interpreter)
- Sourcing: `source script.sh` or `. script.sh` — runs in current shell; variables/functions persist.

```bash
./script.sh    # New subshell
source script.sh   # Current shell
```

# Bash vs sh

- `sh` is often dash or a minimal shell; not full bash.
- Bash has more features: arrays, `[[ ]]`, `$()`, `{1..10}`, etc.
- Use `#!/bin/bash` for bash features; `#!/bin/sh` for portability.

| Feature       | sh     | bash   |
| :------------ | :----- | :----- |
| Arrays        | No     | Yes    |
| `[[ ]]`       | No     | Yes    |
| `$()`         | Yes*   | Yes    |
| `{1..10}`     | No     | Yes    |

# Quoting

- **Double quotes** `"..."`: expand variables, `$()`, escape `\`, `$`, `` ` ``.
- **Single quotes** `'...'`: no expansion; literal.
- **Unquoted**: word splitting, glob expansion.

```bash
name="world"
echo "Hello $name"    # Hello world
echo 'Hello $name'    # Hello $name
```

# Command Substitution

- Run command and use its output: `$(command)` or `` `command` ``.
- Prefer `$(...)`; nests better.

```bash
today=$(date +%Y-%m-%d)
files=$(ls *.txt)
```

# Topic Map

- [001-variables-and-expansion](./001-variables-and-expansion.md) — Variables, expansion, parameter expansion
- [002-control-flow](./002-control-flow.md) — if, case, for, while
- [003-functions](./003-functions.md) — Defining and using functions
- [004-io-and-redirection](./004-io-and-redirection.md) — stdin, stdout, stderr, pipes
- [005-errors-and-exit-codes](./005-errors-and-exit-codes.md) — set -e, trap, exit codes
- [006-strings-and-arrays](./006-strings-and-arrays.md) — String manipulation, arrays
