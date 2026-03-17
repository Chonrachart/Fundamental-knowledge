# Playbooks, Tasks, and Handlers

- A playbook is a YAML file that declares what state managed nodes should be in.
- Tasks call modules sequentially; each task reports `ok`, `changed`, `failed`, or `skipped`.
- Handlers are special tasks that run **once at end of play**, triggered only when a notifying task reports `changed`.


# Playbook Structure

```text
Playbook (site.yml)
  └── Play 1: hosts=web, become=true
        ├── tasks/
        │     ├── Task 1: install nginx      → ok / changed / failed / skipped
        │     ├── Task 2: deploy config      → changed  →  notify: "restart nginx"
        │     └── Task 3: open firewall      → ok
        └── handlers/
              └── "restart nginx"            ← runs once at end of play (only if notified)
```

- Multiple tasks can notify the same handler; it still runs only once.
- `meta: flush_handlers` forces handlers to run immediately mid-play.


# Mental Model

```text
ansible-playbook site.yml
        |
        v
Parse YAML → resolve hosts from inventory
        |
        v
Connect to each host (SSH)
        |
        v
Gather facts (unless gather_facts: false)
        |
        v
Execute tasks top-to-bottom
  each task:  call module → get result → update host state
  if changed: queue handler name
        |
        v
All tasks complete → flush handlers (once per queued handler, per host)
        |
        v
Play ends → next play begins
```


# Core Building Blocks

### Play Options

```yaml
- name: Configure web servers
  hosts: web              # inventory group or pattern
  become: true            # sudo for all tasks in this play
  gather_facts: true      # collect host facts at start (default)
  vars:                   # play-level variables
    app_port: 8080
  tasks: [...]
  handlers: [...]
```

### Task Fields

| Field | Purpose |
|---|---|
| `name:` | Human-readable label (shown in output) |
| `become: true` | Override sudo at task level |
| `register: result` | Save task output to variable |
| `when: condition` | Run task only if condition is true |
| `changed_when:` | Override changed detection |
| `failed_when:` | Override failure detection |
| `tags:` | Label for partial runs (`--tags`) |
| `notify:` | Queue a handler if this task changes |
| `ignore_errors: true` | Continue play even if task fails |

Related notes:
- [005-loops-conditions-blocks](./005-loops-conditions-blocks.md)
- [007-tags-strategies-debugging](./007-tags-strategies-debugging.md)

### Common Modules

| Module | Use |
|---|---|
| `ansible.builtin.package` | Install/remove packages (distro-agnostic) |
| `ansible.builtin.service` / `systemd` | Manage services |
| `ansible.builtin.copy` | Copy file from control node |
| `ansible.builtin.template` | Render Jinja2 template and copy |
| `ansible.builtin.file` | Create dir, set permissions, symlink |
| `ansible.builtin.user` / `group` | Manage users and groups |
| `ansible.builtin.lineinfile` | Ensure a line exists in a file |
| `ansible.builtin.blockinfile` | Ensure a block exists in a file |
| `ansible.builtin.get_url` | Download file from URL |
| `ansible.builtin.unarchive` | Extract archive |
| `ansible.builtin.command` | Run command (no shell, no pipe) |
| `ansible.builtin.shell` | Run shell command (use as last resort) |

- Prefer `package` over distro-specific (`apt`, `yum`) for portability.
- Prefer `command` over `shell`; use `shell` only when pipes/redirects are needed.

### Handlers

```yaml
tasks:
  - name: Deploy nginx config
    ansible.builtin.template:
      src: nginx.conf.j2
      dest: /etc/nginx/nginx.conf
    notify: restart nginx          # queues handler if this task reports changed

handlers:
  - name: restart nginx
    ansible.builtin.service:
      name: nginx
      state: restarted
```

Related notes:
- [004-variables-facts-templating](./004-variables-facts-templating.md)

---

# Practical Command Set (Core)

```bash
# run playbook
ansible-playbook -i inventory/ playbooks/site.yml

# dry-run with file diff
ansible-playbook playbooks/site.yml --check --diff

# run only tagged tasks
ansible-playbook playbooks/site.yml --tags config

# run against one host only
ansible-playbook playbooks/site.yml --limit web1

# start from a specific task
ansible-playbook playbooks/site.yml --start-at-task "Deploy nginx config"

# list all tasks without running
ansible-playbook playbooks/site.yml --list-tasks

# ad-hoc single module
ansible web -m ansible.builtin.service -a "name=nginx state=restarted" --become
```


# Troubleshooting Guide

```text
Problem: Task fails
    |
    v
[1] Read error message in output (rc, stderr, msg)
    |
    v
[2] Re-run with -vvv  (see exact module args sent + raw output)
    |
    v
[3] Test the module ad-hoc on one host
    |
    v
[4] Add debug task above failing task to print relevant variables
    |
    v
[5] Check changed_when / failed_when if result logic seems wrong
    |
    v
[6] Check become / permissions if "Permission denied"
    |
    v
[7] Fix → re-run → confirm second run is all ok
```


# Quick Facts (Revision)

- Handlers run **once at end of play** regardless of how many tasks notify them.
- `meta: flush_handlers` runs pending handlers immediately (use when order matters).
- `ignore_errors: true` lets the play continue but the task still shows as `failed`.
- `changed_when: false` is correct for read-only commands (like `nginx -v`).
- `failed_when` overrides failure; wrong logic here can silently swallow real errors.
- Always use `name:` on tasks — it makes logs readable and `--start-at-task` work.
- Prefer `ansible.builtin.*` FQCN to avoid module ambiguity across collections.
