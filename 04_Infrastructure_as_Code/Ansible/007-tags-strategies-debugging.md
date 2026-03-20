# Tags, Strategies, and Debugging

- Tags let you run or skip a subset of tasks without editing the playbook.
- Strategy controls how Ansible distributes work across hosts (all-together vs as-fast-as-possible).
- Debugging tools: verbosity flags, `debug` module, `assert`, `--check --diff`.


# Mental Model: Partial Runs

```text
Full playbook: install -> config -> deploy -> restart
                  |
                  v
--tags config,deploy   ->   runs only config + deploy tasks
--skip-tags install    ->   runs everything except install tasks
--limit web1           ->   runs full playbook but only on web1
--start-at-task "Deploy config"  ->  skips all tasks before that name
```

- Combine `--limit` + `--tags` for surgical targeted runs.
- `--list-tasks` + `--tags` shows which tasks would run without executing.


# Core Building Blocks

### Tags

```yaml
- name: Install nginx
  ansible.builtin.package:
    name: nginx
    state: present
  tags:
    - install
    - packages

- name: Deploy nginx config
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  tags:
    - config
    - deploy

- name: Start nginx
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: true
  tags:
    - install
    - always          # "always" is a special tag: runs even with --tags filtering
```

```bash
ansible-playbook site.yml --tags install          # only install-tagged tasks
ansible-playbook site.yml --skip-tags config      # everything except config tasks
ansible-playbook site.yml --list-tags             # show all tags without running
ansible-playbook site.yml --list-tasks --tags deploy
```

- Tag roles in the playbook: `- { role: nginx, tags: web }` — applies to all tasks in the role.
- Special tags: `always` (always runs), `never` (only runs if explicitly requested).

### limit and start-at-task

```bash
# target subset of hosts
ansible-playbook site.yml --limit web              # group
ansible-playbook site.yml --limit web1,web2        # specific hosts
ansible-playbook site.yml --limit "web:!web1"      # pattern

# resume from a known task (useful after failure mid-play)
ansible-playbook site.yml --start-at-task "Deploy config"
```

### Check Mode and Diff

```bash
# dry-run: show what would change without touching anything
ansible-playbook site.yml --check

# show file content diff for template/copy tasks
ansible-playbook site.yml --diff

# combine for pre-flight review
ansible-playbook site.yml --check --diff
```

- Not all modules support `--check` (e.g. `command`/`shell` always skip in check mode).
- `--diff` only shows diffs for `template`, `copy`, `lineinfile`, `blockinfile`.

### Strategy and Serial

```yaml
# default: linear -- all hosts run task N before any host runs task N+1
- name: Standard deploy
  hosts: web
  strategy: linear    # default; most predictable

# free: each host runs as fast as it can
- name: Fast parallel run
  hosts: web
  strategy: free      # harder to read logs; good for independent hosts

# serial: rolling update -- batch by batch
- name: Rolling deploy
  hosts: web
  serial: 2           # 2 hosts at a time
  tasks:
    - name: Deploy app
      ansible.builtin.command: /opt/deploy.sh
```

- `serial: "20%"` — rolling percentage of total hosts per batch.
- `serial: [1, 5, 10]` — canary pattern: 1 first, then 5, then rest.

Related notes:
- [010-best-practices-testing](./010-best-practices-testing.md)

### Debugging

```yaml
# print a variable
- ansible.builtin.debug:
    var: nginx_port

# print formatted message
- ansible.builtin.debug:
    msg: "Port is {{ nginx_port }}, env is {{ app_env }}"

# conditional print (only in verbose)
- ansible.builtin.debug:
    var: result
    verbosity: 2     # only shown with -vv or higher

# fail early with clear message
- ansible.builtin.assert:
    that:
      - app_port is defined
      - app_port | int > 1024
    fail_msg: "app_port must be defined and > 1024"
    success_msg: "app_port is valid: {{ app_port }}"
```

---

# Practical Command Set (Core)

```bash
# verbosity levels
ansible-playbook site.yml -v       # task results
ansible-playbook site.yml -vv      # task input/output
ansible-playbook site.yml -vvv     # SSH connection details
ansible-playbook site.yml -vvvv    # connection plugin debug

# surgical run
ansible-playbook site.yml --limit web1 --tags config --check --diff

# list everything without running
ansible-playbook site.yml --list-hosts
ansible-playbook site.yml --list-tasks
ansible-playbook site.yml --list-tags
```


# Troubleshooting Guide

### Playbook runs wrong hosts or tasks

1. Run `--list-hosts` + `--list-tasks` to verify scope before running.

### Task result unexpected

1. Add `-vvv` to see raw module input/output.
2. Add `ansible.builtin.debug: var=<suspect_variable>` before the failing task.
3. Add `ansible.builtin.assert:` to validate assumptions early.
4. Run `--check --diff` to preview changes on a single host.
5. Use `--start-at-task` to resume after fixing a mid-play failure.


# Quick Facts (Revision)

- `always` tag = runs even when `--tags` filters are applied.
- `never` tag = only runs when explicitly called with `--tags never`.
- `serial: 1` = one host at a time (safest rolling deploy; slowest).
- `--check` does **not** change anything; some modules report inaccurate results in check mode.
- `--diff` only works for file-manipulating modules (template, copy, lineinfile, blockinfile).
- `-vvv` is the go-to for SSH and module-level debugging.
- `assert` is better than `fail` — it shows what was tested and why it failed.
