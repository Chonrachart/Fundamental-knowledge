# Ansible Overview

- Ansible is an agentless automation tool: no daemon or agent runs on managed nodes.
- A **control node** pushes work over SSH (Linux) or WinRM (Windows); managed nodes need only Python.
- Core idea: describe **desired state** in YAML; modules enforce it idempotently.


# How Ansible Connects

```text
Control Node
  ├── ansible / ansible-playbook
  ├── inventory  (who to target)
  └── playbook   (what to do)
         │
     SSH / WinRM
         │
   Managed Node
     ├── Python (required)
     ├── Module payload copied → executed → removed
     └── Result returned → ok | changed | failed | skipped
```

- No persistent connection; Ansible reconnects per task (unless pipelining is enabled).
- `become: true` triggers privilege escalation (sudo) on the managed node.


# Core Building Blocks

```text
Inventory  →  Who to target (hosts, groups)
Playbook   →  What to do (list of plays)
Play       →  hosts + tasks (or roles)
Task       →  call one module with args
Module     →  unit of work (package, file, service…)
Handler    →  task that runs only when notified
Role       →  reusable bundle of tasks/handlers/vars/templates
```

### Inventory

- Defines hosts and groups; can be static (INI/YAML) or dynamic (cloud plugin).
- `hosts: web` in a play means "run against the `web` group from inventory".

Related notes:
- [002-inventory-and-ansible-cfg](./002-inventory-and-ansible-cfg.md)

### Playbook

- YAML file with one or more plays; entry point for `ansible-playbook`.
- A play ties a host pattern to a list of tasks (or roles).

Related notes:
- [003-playbooks-tasks-handlers](./003-playbooks-tasks-handlers.md)

### Module

- Unit of work. Preferred over `shell`/`command` because modules are idempotent.
- Full list: `ansible-doc -l` or `ansible-doc ansible.builtin.<module>`.

Related notes:
- [003-playbooks-tasks-handlers](./003-playbooks-tasks-handlers.md)

### Idempotent

- Running the same playbook twice produces the same result — no extra changes.
- Example: `ansible.builtin.package: name=nginx state=present` is safe to re-run; it won't reinstall.

### First Playbook

```yaml
# playbooks/site.yml
- name: Install and start nginx
  hosts: web
  become: true

  tasks:
    - name: Install nginx
      ansible.builtin.package:
        name: nginx
        state: present

    - name: Start and enable nginx
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true
```

Run it:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
```

---

# Practical Command Set (Core)

```bash
# verify installation
ansible --version

# test connectivity (ad-hoc ping)
ansible all -m ping -i inventory/hosts.ini
ansible web -m ping                          # uses ansible.cfg inventory default

# run a playbook
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# dry-run (no changes)
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check --diff

# ad-hoc one-liner
ansible web -m ansible.builtin.package -a "name=curl state=present" --become

# inspect inventory
ansible-inventory -i inventory/hosts.ini --graph
```

- Add `-v`, `-vv`, `-vvv` to any command for increasing verbosity.



- Ansible is **push-based**: control node initiates, managed node does not call home.
- Only Python is required on managed nodes (no Ansible install needed there).
- Task result states: `ok` (no change), `changed` (modified), `failed`, `skipped`.
- Handlers run **once at end of play**, not once per notify call.
- `become: true` = sudo; `become_user` controls which user (default: root).
- `--check` never changes anything on remote hosts.
- Use `ansible.builtin.<module>` FQCN to avoid collection ambiguity.
# Troubleshooting Guide

### Something is wrong

1. Re-run with `--check --diff` to see what would change without touching anything.
2. Add `-vvv` to see SSH details, module args, and raw output.
3. Test connectivity with ad-hoc ping: `ansible <host> -m ping`.
4. Check inventory graph: `ansible-inventory --graph`.
5. Add a debug task to print the suspect variable.
6. Run a single task with `--start-at-task` or `--tags`.
7. Fix, re-run, and verify the second run is all ok (idempotency check).

