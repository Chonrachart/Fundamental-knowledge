# Shell Environment and PATH

- Environment variables are key-value pairs inherited by child processes — they configure runtime behaviour without hardcoding values.
- `PATH` is a colon-separated list of directories the shell searches when you type a command name.
- Variables set without `export` are shell-local; `export` makes them visible to child processes.


# Environment Architecture

```text
Login shell starts
        |
        v
Reads startup files:
  /etc/environment          (system-wide, all shells)
  /etc/profile              (system-wide, login shells)
  ~/.profile or ~/.bash_profile  (user login shell)
  ~/.bashrc                 (user interactive non-login shell)
        |
        v
Environment variables loaded into shell memory
        |
        v
Shell forks child process (command, script, subshell)
        |
        v
Child inherits copy of parent's exported environment
        |
        v
Child changes to its env do NOT affect parent
```


# Mental Model: Command Resolution

```text
User types: nginx
        |
        v
Is "nginx" a shell alias?  → yes: use alias expansion
        |
        v
Is "nginx" a shell function?  → yes: call function
        |
        v
Is "nginx" a shell builtin (cd, echo, export…)?  → yes: run builtin
        |
        v
Search PATH left to right:
  /usr/local/sbin/nginx?  not found
  /usr/local/bin/nginx?   not found
  /usr/sbin/nginx?        found → execute
        |
        v
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
- `command -v` is a shell builtin and more reliable than `which` (works for functions and builtins too).

### Setting Variables

```bash
MY_VAR=hello                        # shell-local variable (NOT exported; children cannot see it)
export MY_VAR=hello                 # export to child processes
export PATH="$HOME/bin:$PATH"       # prepend directory to PATH (higher priority)
```

- Exported variables exist only for the current session — lost when terminal closes.
- Child processes cannot modify the parent's environment.
- `PATH` is searched left to right — put priority directories at the front.
- `export` marks a variable for inheritance by child processes; without it, children cannot see it.
- Child processes get a **copy** of the parent environment — changes in the child do not affect the parent.

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
- `source` (or `.`) runs a script in the current shell — the only way a script can modify the parent's environment.

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
- Cron runs with a minimal environment — always use absolute paths in cron scripts or set `PATH=` in crontab.
- Login shell reads `~/.profile`; interactive non-login reads `~/.bashrc` — put persistent exports in `~/.profile`.

Related notes:
- [01-Basic-file-and-text-manipulation](./01-Basic-file-and-text-manipulation.md) — shell basics


---

# Troubleshooting Guide

### "command not found"

1. Check if shell finds it at all: `command -v <cmd>`.
2. Check if the binary's directory is in PATH: `echo $PATH`.
3. Verify binary exists and has execute bit: `ls -l $(which <cmd>)`.

### which shows wrong version of command

1. Check PATH order (leftmost directory wins): `echo $PATH`.

### export works in terminal but not in cron / script

1. Script runs in non-interactive shell — source the startup file explicitly or set PATH at top of script with full absolute paths.

### Variable set in script not visible in parent shell

1. Use `source ./script.sh` (not `./script.sh`) to run in current shell context.

