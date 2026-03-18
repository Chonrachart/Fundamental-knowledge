# Practical Script Patterns

- Shell scripts follow a predictable lifecycle: parse arguments, load config, execute logic, clean up on exit.
- Defensive patterns (strict mode, traps, lock files, temp files) prevent silent failures and resource leaks.
- Reusable boilerplate for argument parsing, logging, and cleanup turns ad-hoc scripts into production-grade tools.

# Architecture

```text
+---------------------------------------------------------------+
|                    Script Lifecycle Layout                      |
+---------------------------------------------------------------+
|  #!/usr/bin/env bash                                           |
|  set -euo pipefail                     # strict mode           |
|                                                                |
|  +------------------+                                          |
|  |  Constants &     |  SCRIPT_DIR, VERSION, defaults           |
|  |  Defaults        |                                          |
|  +------------------+                                          |
|           |                                                    |
|  +------------------+                                          |
|  |  Functions       |  usage(), log(), cleanup(), die()        |
|  +------------------+                                          |
|           |                                                    |
|  +------------------+                                          |
|  |  Trap Setup      |  trap cleanup EXIT                       |
|  +------------------+                                          |
|           |                                                    |
|  +------------------+                                          |
|  |  Argument Parse  |  getopts / manual loop / shift           |
|  +------------------+                                          |
|           |                                                    |
|  +------------------+                                          |
|  |  Config Load     |  source .conf, env vars, validation      |
|  +------------------+                                          |
|           |                                                    |
|  +------------------+                                          |
|  |  Main Logic      |  core functionality                      |
|  +------------------+                                          |
|           |                                                    |
|  +------------------+                                          |
|  |  Cleanup (trap)  |  remove temp files, release locks        |
|  +------------------+                                          |
+---------------------------------------------------------------+
```

# Mental Model

```text
Script invoked
  |
  v
1. Bash reads shebang, sets strict mode (set -euo pipefail)
  |
  v
2. Define functions (usage, log, cleanup, die)
  |
  v
3. Register trap cleanup EXIT
  |     (cleanup guaranteed on any exit: normal, error, signal)
  |
  v
4. Parse arguments (getopts / manual loop)
  |     Invalid? --> usage() --> exit 1
  |
  v
5. Load config (source file, env vars, defaults)
  |     Missing required value? --> die "msg"
  |
  v
6. Create temp files (mktemp), acquire lock (flock)
  |
  v
7. Execute main logic
  |
  v
8. Exit --> trap fires --> cleanup() removes temps, releases lock
```

Example -- minimal but complete script:

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
VERBOSE=false
OUTPUT_FILE=""

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [-v] [-o file] <input>
  -v        verbose output
  -o file   write output to file
  -h        show this help
EOF
  exit 1
}

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

TMPFILE=""
cleanup() {
  [[ -n "$TMPFILE" && -f "$TMPFILE" ]] && rm -f "$TMPFILE"
}
trap cleanup EXIT

while getopts ":vo:h" opt; do
  case $opt in
    v) VERBOSE=true ;;
    o) OUTPUT_FILE="$OPTARG" ;;
    h) usage ;;
    :) die "Option -$OPTARG requires an argument" ;;
    *) die "Unknown option -$OPTARG" ;;
  esac
done
shift $((OPTIND - 1))

[[ $# -lt 1 ]] && usage
INPUT="$1"

TMPFILE="$(mktemp)"
$VERBOSE && log "Processing $INPUT"

# Main logic here
cat "$INPUT" > "$TMPFILE"
if [[ -n "$OUTPUT_FILE" ]]; then
  cp "$TMPFILE" "$OUTPUT_FILE"
else
  cat "$TMPFILE"
fi
```

# Core Building Blocks

### Argument Parsing with getopts

- `getopts` handles short options (`-v`, `-o value`); built-in to bash.
- The option string: leading `:` enables silent error mode; trailing `:` means the option takes an argument.
- `OPTARG` holds the argument value; `OPTIND` tracks the index for `shift`.
- `getopts` does not support long options (`--verbose`); use manual parsing for those.

```bash
# getopts for short options
while getopts ":vo:h" opt; do
  case $opt in
    v) VERBOSE=true ;;
    o) OUTPUT="$OPTARG" ;;
    h) usage ;;
    :) die "Option -$OPTARG requires an argument" ;;
    *) die "Unknown option -$OPTARG" ;;
  esac
done
shift $((OPTIND - 1))
# Remaining positional args: "$@"
```

```bash
# Manual parsing for long options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--verbose) VERBOSE=true; shift ;;
    -o|--output)  OUTPUT="$2"; shift 2 ;;
    -h|--help)    usage ;;
    --)           shift; break ;;
    -*)           die "Unknown option: $1" ;;
    *)            break ;;
  esac
done
```

Related notes: [001-variables-and-expansion](./001-variables-and-expansion.md), [002-control-flow](./002-control-flow.md)

### Script Template (Strict Boilerplate)

- `set -e` -- exit on error (non-zero return).
- `set -u` -- error on unset variables.
- `set -o pipefail` -- pipe returns the exit code of the first failing command.
- `readonly` for constants prevents accidental reassignment.
- `SCRIPT_DIR` pattern resolves the script's own location regardless of cwd.

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="1.0.0"
```

Related notes: [005-errors-and-exit-codes](./005-errors-and-exit-codes.md), [000-core](./000-core.md)

### Config Files

- Source a config file to load variables into the current shell.
- Guard with existence check; provide defaults for missing values.
- Use `:-` for default values; use `:?` to require a value.

```bash
# Source config if it exists
CONFIG_FILE="${SCRIPT_DIR}/app.conf"
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi

# Defaults for optional config values
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

# Require critical values
DB_PASSWORD="${DB_PASSWORD:?ERROR: DB_PASSWORD must be set}"
```

```bash
# Example app.conf
DB_HOST="db.example.com"
DB_PORT=5432
LOG_LEVEL="info"
```

Related notes: [001-variables-and-expansion](./001-variables-and-expansion.md), [003-functions](./003-functions.md)

### Logging

- Wrap log output in a function for consistent formatting.
- Include timestamp and severity level.
- Redirect log output to both terminal and file with `tee`.

```bash
readonly LOG_FILE="/var/log/myscript.log"

log()   { printf '[%s] [INFO]  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"; }
warn()  { printf '[%s] [WARN]  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE" >&2; }
error() { printf '[%s] [ERROR] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE" >&2; }
die()   { error "$@"; exit 1; }

# Verbose/debug logging controlled by flag
debug() { $VERBOSE && printf '[%s] [DEBUG] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"; }
```

Related notes: [004-io-and-redirection](./004-io-and-redirection.md), [003-functions](./003-functions.md)

### Lock Files (Preventing Concurrent Execution)

- `flock` is the standard Linux advisory lock mechanism.
- `mkdir` can serve as an atomic lock for portability (mkdir is atomic on all filesystems).
- Always pair lock acquisition with trap-based cleanup.

```bash
# Method 1: flock (preferred on Linux)
readonly LOCK_FILE="/var/lock/myscript.lock"
exec 200>"$LOCK_FILE"
flock -n 200 || die "Another instance is already running"

# Method 2: mkdir (portable)
readonly LOCK_DIR="/tmp/myscript.lock"
mkdir "$LOCK_DIR" 2>/dev/null || die "Another instance is already running"
cleanup() { rmdir "$LOCK_DIR" 2>/dev/null; }
trap cleanup EXIT
```

Related notes: [005-errors-and-exit-codes](./005-errors-and-exit-codes.md), [004-io-and-redirection](./004-io-and-redirection.md)

### Temp Files and Cleanup

- `mktemp` creates unique temporary files/directories securely.
- Always register a trap to clean up temp files on exit (normal or error).
- Use `mktemp -d` for temporary directories.

```bash
# Create temp file and register cleanup
TMPFILE="$(mktemp /tmp/myscript.XXXXXX)"
TMPDIR="$(mktemp -d /tmp/myscript.XXXXXX)"

cleanup() {
  rm -f "$TMPFILE"
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

# Use temp files safely
curl -sS "$URL" > "$TMPFILE"
process "$TMPFILE"
```

Related notes: [005-errors-and-exit-codes](./005-errors-and-exit-codes.md), [006-strings-and-arrays](./006-strings-and-arrays.md)

---

# Troubleshooting Guide

```text
Script fails silently?
  |
  +--> Is set -euo pipefail enabled?
  |       |
  |       +--> NO  --> add it; rerun to surface the real error
  |       +--> YES --> check which line fails: run with bash -x script.sh
  |
  +--> Arguments parsed wrong?
  |       |
  |       +--> getopts colon missing? "o:" means -o takes a value
  |       +--> Forgot shift $((OPTIND - 1)) after getopts loop?
  |       +--> Long options: check shift 2 for options with values
  |
  +--> Cleanup not running?
  |       |
  |       +--> trap set before the code that might fail?
  |       +--> Using EXIT signal? (fires on normal exit AND errors)
  |       +--> SIGKILL (kill -9) cannot be trapped -- nothing can catch it
  |
  +--> Lock file stale (script crashed without cleanup)?
  |       |
  |       +--> flock: lock auto-releases when fd closes (process dies)
  |       +--> mkdir: manually remove stale lock dir
  |       +--> Consider storing PID in lock file to detect stale locks
  |
  +--> Config not loading?
          |
          +--> File exists? [[ -f "$CONFIG_FILE" ]]
          +--> Permissions? (must be readable)
          +--> Syntax error in conf? Run: bash -n app.conf
```

# Quick Facts (Revision)

- `set -euo pipefail` is the standard strict mode: exit on error, unset var error, pipe failure propagation.
- `getopts` handles short options only; use a manual `while/case` loop for `--long-options`.
- `trap cleanup EXIT` guarantees cleanup runs on any exit (normal, error, or caught signal).
- `mktemp` creates unique temp files; always pair with trap cleanup to prevent leaks.
- `flock -n` provides non-blocking advisory locks; lock auto-releases when the process exits.
- `source config.conf` loads variables into the current shell; guard with `[[ -f ]]` check.
- `${VAR:-default}` provides fallback values; `${VAR:?msg}` exits if the variable is unset.
- `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` reliably resolves the script's own directory.
