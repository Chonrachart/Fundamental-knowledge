# Shell Environment and PATH

```bash
echo $PATH
which ls
command -v ls
env
printenv HOME
export APP_ENV=dev
export PATH="$HOME/bin:$PATH"
```

- Environment variables are key-value data passed to child processes.
- `PATH` is search path for commands (`/usr/bin`, `/usr/local/bin`, etc.).
- If command is "not found", check PATH first.
- Shell searches `PATH` from left to right and runs the first match.
- `which` is useful, but `command -v` is a shell built-in and more reliable.
- `env` or `printenv` prints exported variables only.

### Quick checks

```bash
echo "$SHELL"
echo "$HOME"
echo "$USER"
echo "$PWD"
printenv | grep -E '^(PATH|HOME|USER|SHELL)='
```

- `SHELL` current default shell path.
- `HOME` user home directory.
- `USER` current username.
- `PWD` current working directory.

### Temporary vs persistent variables

```bash
MY_VAR=hello
echo "$MY_VAR"
```

- `MY_VAR=hello` creates a shell variable in current shell only.
- Child processes cannot see it until you `export` it.

```bash
export MY_VAR=hello
```

- `export` makes variable available to child processes.
- Variables set this way are temporary for current session (lost after closing terminal).


### Persist PATH (bash)

```bash
echo 'export MY_VAR=hello' >> ~/.bashrc
source ~/.bashrc
```

- Put persistent `export` in startup files, not in random scripts.
- `source ~/.bashrc` reloads config in current shell without reopening terminal.
- On many systems:
  - login shell reads `~/.profile` or `~/.bash_profile`
  - interactive non-login shell reads `~/.bashrc`

### Shell startup files (bash)

- `~/.bashrc` for interactive non-login shell.
- `~/.profile` (or `~/.bash_profile`) for login shell.
- Common pattern: export variables in `.profile`, aliases/functions in `.bashrc`.
- Common pattern in `.bash_profile`:
  - `if [ -f ~/.bashrc ]; then . ~/.bashrc; fi`

### Troubleshooting "command not found"

```bash
command -v mycmd
echo "$PATH"
ls -l ~/bin
```

- Confirm binary exists and has execute permission (`chmod +x file`).
- Confirm directory containing binary is in `PATH`.
