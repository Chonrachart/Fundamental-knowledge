# Shell Environment and PATH

- Environment variables are key-value pairs inherited by child processes — they configure runtime behaviour without hardcoding values.
- `PATH` is a colon-separated list of directories the shell searches when you type a command name.
- Variables set without `export` are shell-local; `export` makes them visible to child processes.


# Environment Architecture

```text
Login shell starts
        ↓
Reads startup files:
  /etc/environment          (system-wide, all shells)
  /etc/profile              (system-wide, login shells)
  ~/.profile or ~/.bash_profile  (user login shell)
  ~/.bashrc                 (user interactive non-login shell)
        ↓
Environment variables loaded into shell memory
        ↓
Shell forks child process (command, script, subshell)
        ↓
Child inherits copy of parent's exported environment
        ↓
Child changes to its env do NOT affect parent
```


# Mental Model: Command Resolution

```text
User types: nginx
        ↓
Is "nginx" a shell alias?  → yes: use alias expansion
        ↓
Is "nginx" a shell function?  → yes: call function
        ↓
Is "nginx" a shell builtin (cd, echo, export…)?  → yes: run builtin
        ↓
Search PATH left to right:
  /usr/local/sbin/nginx?  not found
  /usr/local/bin/nginx?   not found
  /usr/sbin/nginx?        found → execute
        ↓
"command not found" if exhausted all PATH directories
```

`which nginx` and `command -v nginx` show which binary wins the PATH search.


# Core Building Blocks

### Viewing the Environment

```bash
echo $PATH                          # show PATH value
env                                 # list all exported variables
printenv HOME                       # print single variable
printenv | grep -E '^(PATH|HOME|USER|SHELL)='

echo "$SHELL"       # current shell binary path
echo "$HOME"        # user home directory
echo "$USER"        # current username
echo "$PWD"         # current working directory
```

### Setting Variables

```bash
MY_VAR=hello                        # shell-local variable (NOT exported; children cannot see it)
export MY_VAR=hello                 # export to child processes
export PATH="$HOME/bin:$PATH"       # prepend directory to PATH (higher priority)
```

- Exported variables exist only for the current session — lost when terminal closes.
- Child processes cannot modify the parent's environment.

### Persisting Variables

```bash
# append to ~/.bashrc (interactive non-login shells)
echo 'export MY_VAR=hello' >> ~/.bashrc
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc

# reload without reopening terminal
source ~/.bashrc
# or
. ~/.bashrc
```

### Shell Startup Files (bash)

| File | When read |
|---|---|
| `/etc/environment` | System-wide, all shells, login |
| `/etc/profile` | System-wide, bash login shells |
| `~/.bash_profile` or `~/.profile` | User, login shells |
| `~/.bashrc` | User, interactive non-login shells |

Common pattern in `~/.bash_profile`:

```bash
# source .bashrc from login shell so settings are consistent
if [ -f ~/.bashrc ]; then . ~/.bashrc; fi
```

- Put `export` variables in `~/.profile` (or `~/.bash_profile`).
- Put aliases and functions in `~/.bashrc`.

Related notes:
- [01-Basic-file-and-text-manipulation](./01-Basic-file-and-text-manipulation.md) — shell basics

---

# Troubleshooting Flow (Quick)

```text
"command not found"
        ↓
command -v <cmd>  →  does shell find it at all?
        ↓
echo $PATH  →  is the binary's directory in PATH?
        ↓
ls -l $(which <cmd>)  →  does binary exist and have execute bit?
        ↓
which shows wrong version of command
        ↓
echo $PATH  →  check order (leftmost directory wins)
        ↓
export works in terminal but not in cron / script
        ↓
Script runs in non-interactive shell — source the startup file explicitly
or set PATH at top of script with full absolute paths
        ↓
Variable set in script not visible in parent shell
        ↓
Use source ./script.sh (not ./script.sh) to run in current shell context
```


# Quick Facts (Revision)

- `PATH` is searched left to right — put priority directories at the front.
- `export` marks a variable for inheritance by child processes; without it, children cannot see it.
- Child processes get a **copy** of the parent environment — changes in the child do not affect the parent.
- `source` (or `.`) runs a script in the current shell — the only way a script can modify the parent's environment.
- Cron runs with a minimal environment — always use absolute paths in cron scripts or set `PATH=` in crontab.
- `command -v` is a shell builtin and more reliable than `which` (works for functions and builtins too).
- Login shell reads `~/.profile`; interactive non-login reads `~/.bashrc` — put persistent exports in `~/.profile`.
