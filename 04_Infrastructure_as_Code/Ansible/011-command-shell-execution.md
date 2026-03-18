# Command, Shell, and Execution Modules

- `command`, `shell`, `raw`, and `script` are Ansible's escape hatches for running arbitrary commands on managed nodes.
- They are **not idempotent by default** — you must add guards (`creates`, `removes`, `changed_when`) to make them safe.
- Prefer purpose-built modules (`package`, `file`, `service`) whenever possible; use execution modules only when no module exists for the operation.


# When to Use Each Module

```text
Need to run a command on remote host?
        |
        v
Does a purpose-built module exist?  ──yes──→  Use the module (idempotent)
        |
       no
        |
        v
Need pipes, redirects, env vars, or shell features?
        |                                    |
       no                                  yes
        |                                    |
        v                                    v
ansible.builtin.command            ansible.builtin.shell
(safer, no shell injection)        (full /bin/sh processing)
        |
        v
Host has no Python? ──yes──→ ansible.builtin.raw (bare SSH command)
        |
       no
        |
        v
Need to run a local script on remote? ──yes──→ ansible.builtin.script
```


# Core Building Blocks

### ansible.builtin.command

- Runs a command **without** a shell (`/bin/sh`).
- No pipes (`|`), redirects (`>`), or shell variables (`$HOME`) — these are silently ignored.
- Safer than `shell` because no shell injection risk.

```yaml
- name: Check if app is installed
  ansible.builtin.command: /opt/app/bin/app --version
  register: app_version
  changed_when: false          # read-only, never changes state
```

**Key parameters:**

| Parameter | Purpose | Example |
|---|---|---|
| `cmd` (or free-form) | Command to run | `cmd: /usr/bin/uptime` |
| `argv` | Pass command as a list (avoids quoting issues) | `argv: [/usr/bin/app, --config, /etc/app.conf]` |
| `creates` | Skip task if this path exists | `creates: /opt/app/.installed` |
| `removes` | Skip task if this path does **not** exist | `removes: /tmp/installer.sh` |
| `chdir` | Change to this directory before running | `chdir: /opt/app` |
| `stdin` | Pass data to command's stdin | `stdin: "yes"` |
| `strip_empty_ends` | Strip trailing empty lines from output (default: true) | `strip_empty_ends: false` |

```yaml
- name: Run database migration
  ansible.builtin.command:
    cmd: python manage.py migrate --noinput
    chdir: /opt/webapp
    creates: /opt/webapp/.migrated
  register: migration_result
  changed_when: "'No migrations to apply' not in migration_result.stdout"
```

Related notes:
- [010-best-practices-testing](./010-best-practices-testing.md) — idempotency rules for command tasks

### ansible.builtin.shell

- Runs a command **through** `/bin/sh` — supports pipes, redirects, env vars, and globbing.
- Higher risk: user-controlled input in commands can lead to shell injection.

```yaml
- name: Get disk usage for data partition
  ansible.builtin.shell: df -h /data | tail -1 | awk '{print $5}'
  register: disk_usage
  changed_when: false
```

**Additional parameters (beyond command):**

| Parameter | Purpose | Example |
|---|---|---|
| `executable` | Use a different shell | `executable: /bin/bash` |

```yaml
- name: Build application
  ansible.builtin.shell:
    cmd: |
      source /opt/app/venv/bin/activate
      pip install -r requirements.txt
      python setup.py build
    chdir: /opt/app
    executable: /bin/bash        # needed for 'source' (bashism)
    creates: /opt/app/build/     # skip if already built
```

Related notes:
- [010-best-practices-testing](./010-best-practices-testing.md) — why shell is a last resort

### ansible.builtin.raw

- Sends a command over SSH **without** Ansible's module system — no Python required on the target.
- Use case: bootstrapping a host that has no Python (e.g., install Python itself).
- Does not support `creates`, `removes`, or `chdir`.

```yaml
- name: Bootstrap Python on minimal host
  ansible.builtin.raw: apt-get install -y python3
  become: true
  changed_when: false

- name: Verify Python is available
  ansible.builtin.raw: python3 --version
  register: python_check
  changed_when: false
```

### ansible.builtin.script

- Copies a **local** script to the remote host and executes it.
- Script lives on the control node, not the managed node.
- Supports `creates`, `removes`, and `chdir` like `command`.

```yaml
- name: Run setup script
  ansible.builtin.script:
    cmd: files/setup.sh --env production
    creates: /opt/app/.setup_complete
```


### args Form vs. Inline Form

Two ways to pass parameters — they are equivalent:

```yaml
# inline (free-form) — simple commands
- ansible.builtin.command: /opt/install.sh --silent
  args:
    creates: /opt/app/.installed
    chdir: /opt

# structured (cmd parameter) — complex or multi-arg commands
- ansible.builtin.command:
    cmd: /opt/install.sh --silent
    creates: /opt/app/.installed
    chdir: /opt
```

- `args:` is the YAML key that passes extra parameters when using free-form syntax.
- The structured form puts everything under the module key — no `args:` needed.


### Idempotency Guards

Execution modules report `changed` on every run unless you tell them otherwise.

```text
                          ┌─────────────────────┐
                          │ Does the command     │
                          │ change system state? │
                          └──────┬──────────────┘
                                 │
                    ┌────────────┼────────────────┐
                   yes          maybe              no
                    │            │                  │
                    v            v                  v
              creates/removes  changed_when       changed_when: false
              (file-based      (output-based
               guard)           guard)
```

**Guard 1: `creates` / `removes`**

- `creates: /path` — task is skipped if path exists (file was already created by a previous run).
- `removes: /path` — task is skipped if path does **not** exist (file was already removed).

```yaml
- name: Download and install application
  ansible.builtin.command: /tmp/install.sh
  args:
    creates: /opt/app/bin/app          # idempotent: skip if app exists
```

**Guard 2: `changed_when`**

- Override the default changed detection using task output.

```yaml
# read-only command — never changes anything
- name: Get current kernel version
  ansible.builtin.command: uname -r
  register: kernel_version
  changed_when: false

# conditional change — only "changed" when something actually happened
- name: Apply database schema
  ansible.builtin.command: /opt/app/migrate.sh
  register: migrate_result
  changed_when: "'Applied' in migrate_result.stdout"
  failed_when: migrate_result.rc != 0
```

**Guard 3: `failed_when`**

- Override default failure detection (default: non-zero return code = failed).

```yaml
- name: Check if service exists
  ansible.builtin.command: systemctl status myapp
  register: service_check
  failed_when: service_check.rc not in [0, 3, 4]   # 3=inactive, 4=not-found are OK
  changed_when: false
```


### Return Values

All execution modules return the same set of values in the registered variable:

| Field | Type | Description |
|---|---|---|
| `rc` | int | Return code (0 = success) |
| `stdout` | string | Standard output |
| `stdout_lines` | list | stdout split into lines |
| `stderr` | string | Standard error |
| `stderr_lines` | list | stderr split into lines |
| `cmd` | string/list | Command that was executed |
| `start` | string | Timestamp when command started |
| `end` | string | Timestamp when command ended |
| `delta` | string | Execution duration |

```yaml
- name: Run health check
  ansible.builtin.command: /opt/app/healthcheck.sh
  register: health
  failed_when: health.rc != 0

- name: Show health check output
  ansible.builtin.debug:
    msg: "RC={{ health.rc }}, Output={{ health.stdout }}, Duration={{ health.delta }}"
```

---

# Practical Command Set (Core)

```bash
# test a command module ad-hoc
ansible web -m ansible.builtin.command -a "uptime" --become

# test shell module ad-hoc (use quotes for pipes)
ansible web -m ansible.builtin.shell -a "df -h | grep /data"

# test raw module (no Python needed)
ansible newhost -m ansible.builtin.raw -a "apt-get install -y python3" --become

# check what a module supports
ansible-doc ansible.builtin.command
ansible-doc ansible.builtin.shell
```


# Troubleshooting Guide

### Command runs but reports changed every time

1. Check if `creates` or `changed_when` is set — without either, every run reports `changed`.
2. Add `creates: /path/to/artifact` if the command produces a file.
3. Add `changed_when: false` if the command is read-only.
4. For conditional changes, register output and use `changed_when: "'pattern' in result.stdout"`.

### Shell features not working in command module

1. Verify you are using `ansible.builtin.shell`, not `ansible.builtin.command`.
2. `command` does not process pipes (`|`), redirects (`>`), or variables (`$HOME`).
3. If you need `source` or other bashisms, add `executable: /bin/bash`.

### Command fails with "No such file or directory"

1. Check if the binary path is correct: `ansible host -m ansible.builtin.command -a "which <binary>"`.
2. Add `chdir:` if the command expects a specific working directory.
3. For `script` module, confirm the script exists on the **control node**, not the managed node.

### creates/removes guard not working as expected

1. `creates:` skips when the path **exists** — verify with `ls -la <path>` on the target.
2. `removes:` skips when the path **does not exist** — opposite logic.
3. Both check at task execution time, not at playbook parse time.
4. Paths are evaluated on the **managed node**, not the control node.


# Quick Facts (Revision)

- `command` = no shell, no pipes — safer; `shell` = full `/bin/sh` — flexible but riskier.
- `raw` = bare SSH, no Python needed — use only for bootstrap tasks.
- `script` = copies local script to remote and runs it — script lives on control node.
- `creates` / `removes` = file-based skip guards; `changed_when` = output-based guard.
- `args:` block is only needed with free-form syntax; structured form puts params under the module key.
- Always `register:` + `changed_when:` for command/shell tasks — bare execution is never idempotent.
- `executable: /bin/bash` is needed for bashisms like `source`, `[[`, arrays.
- `stdin:` passes data to command's stdin — useful for interactive installers.
