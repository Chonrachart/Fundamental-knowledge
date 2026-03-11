exit code
set -e
trap
errexit
debug

---

# Exit Code

- Every command returns 0–255; 0 = success, non-zero = failure.
- `$?` — exit code of last command.

```bash
ls /tmp
echo $?    # 0
ls /nonexistent
echo $?    # 2
```

# set -e

- Exit immediately if any command fails (non-zero exit).
- Use at top of script for fail-fast behavior.

```bash
#!/bin/bash
set -e
```

### set -u

- Treat unset variables as error.
- Catches typos in variable names.

### set -o pipefail

- Pipeline fails if any command in pipe fails (not just last).

# trap

- Run command on signal or exit.

```bash
trap 'echo "Cleaning up"; rm -f /tmp/foo' EXIT
trap 'exit 1' INT TERM
```

### Common Use

- Cleanup on exit; restore state on interrupt.

# Exit

- `exit N` — exit script with code N.
- `exit` — exit with last command's code.

```bash
if [ ! -f "$file" ]; then
    echo "File not found"
    exit 1
fi
```

# Debug

- `set -x` — print each command before execution.
- `bash -x script.sh` — run script in trace mode.
