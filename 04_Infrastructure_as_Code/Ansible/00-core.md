# Ansible Core Overview

- Ansible is agentless automation for configuration, deployment, and orchestration.
- A **control node** runs Ansible; **managed nodes** are reached over SSH (Linux) or WinRM (Windows) — no agent installed.
- Playbooks describe desired state; modules are designed to be idempotent (safe to run repeatedly).


# Ansible Architecture

```text
Control Node
  ansible.cfg + inventory + playbooks + roles
                    |
            SSH / WinRM (no agent)
                    |
   ┌────────────────┼────────────────┐
Managed Node A  Managed Node B  Managed Node C
 (web-01)        (db-01)         (app-01)
```

- Ansible pushes work from the control node over SSH; nothing runs persistently on managed nodes.
- Inventory tells Ansible *which* hosts exist; playbooks tell it *what* to do on them.
- Modules are copied to managed nodes, executed, and then removed automatically.


# Ansible Mental Model

```text
ansible-playbook site.yml
         |
         v
Parse inventory → resolve target hosts
         |
         v
Connect to each host (SSH)
         |
         v
Gather facts (OS, IPs, packages…) unless gather_facts: false
         |
         v
Execute tasks top-to-bottom (module calls)
         |
         v
Notify handlers if task reports changed
         |
         v
Task result → ok | changed | failed | skipped
```

Example:

```yaml
- hosts: web
  become: true
  tasks:
    - name: Install nginx
      ansible.builtin.package:
        name: nginx
        state: present
      notify: restart nginx

  handlers:
    - name: restart nginx
      ansible.builtin.service:
        name: nginx
        state: restarted
```

- `package` module checks current state; if already installed → `ok` (no change).
- Handler fires only when at least one task notifying it reported `changed`.


# Core Building Blocks

### Inventory (Who)

- Inventory = list of hosts + groups + connection variables.
- Formats: INI, YAML, or dynamic scripts/plugins.
- Group variables in `group_vars/<group>.yml`; host overrides in `host_vars/<host>.yml`.

Related notes:
- [02-inventory-and-ansible-cfg](./02-inventory-and-ansible-cfg.md)

### Playbooks and Tasks (What)

- Playbook = YAML file with one or more **plays**.
- Play = `hosts` + optional `vars` + `tasks` (or `roles`).
- Task = call a module with named arguments.

Related notes:
- [01-ansible-overview](./01-ansible-overview.md)
- [003-playbooks-tasks-handlers](./003-playbooks-tasks-handlers.md)

### Modules (How)

- Module = unit of work: `package`, `file`, `service`, `template`, `user`, `copy`, `command`…
- Prefer built-in modules over `shell`/`command` — safer and more idempotent.
- `become: true` runs with sudo (required for packages, services, system files).
- `ansible-doc ansible.builtin.<module>` shows usage and examples inline.

Related notes:
- [003-playbooks-tasks-handlers](./003-playbooks-tasks-handlers.md)

### Variables and Templates (Values)

- Variables are key/value data consumed by tasks and Jinja2 templates: `{{ var_name }}`.
- Precedence order (low → high): role defaults → group_vars → host_vars → extra-vars (`-e`).
- Templates (`.j2`) combine static config with dynamic values.
- Ansible Vault encrypts secrets at rest inside variable files.

Related notes:
- [004-variables-facts-templating](./004-variables-facts-templating.md)
- [008-vault-secrets](./008-vault-secrets.md)

### Roles and Collections (Reuse)

- Role = self-contained unit: `tasks/`, `handlers/`, `defaults/`, `templates/`, `files/`.
- Collection = bundle of roles + modules + plugins; distributed via Ansible Galaxy.
- Roles keep playbooks short and reusable across projects.

Related notes:
- [006-roles-collections-galaxy](./006-roles-collections-galaxy.md)

### Control Flow (Logic)

- `loop` iterates a task over a list.
- `when` runs a task only when a condition is true (uses Jinja2 expressions).
- `block`/`rescue`/`always` handles errors like try/catch.

Related notes:
- [005-loops-conditions-blocks](./005-loops-conditions-blocks.md)

---

# Practical Command Set (Core)

```bash
# version / connectivity check
ansible --version
ansible localhost -c local -m ping

# ad-hoc commands
ansible <pattern> -i <inventory> -m <module> [-a "<args>"] [--become]

# run a playbook
ansible-playbook -i <inventory> site.yml
ansible-playbook -i <inventory> site.yml --limit web-01
ansible-playbook -i <inventory> site.yml --tags deploy
ansible-playbook -i <inventory> site.yml --check --diff   # dry-run

# inspect inventory
ansible-inventory -i <inventory> --graph
ansible-inventory -i <inventory> --list

# configuration
ansible-config dump --only-changed

# vault
ansible-vault encrypt group_vars/all/secrets.yml
ansible-vault view group_vars/all/secrets.yml

# roles/collections
ansible-galaxy role init <role_name>
ansible-galaxy collection install -r collections/requirements.yml
```

- Add `-v`, `-vv`, or `-vvv` to any command for increasing verbosity.


# Troubleshooting Guide

### Task fails or behaves unexpectedly

1. Re-run with `--check --diff` to see what would change.
2. Add `-vvv` to see SSH connection, module args, and raw output.
3. Insert a debug task to print vars/facts mid-play.
4. Check inventory with `ansible-inventory --graph` or `--list`.
5. Check variable precedence (extra-vars win; role defaults lose).
6. Run the ad-hoc module directly on one host.
7. Fix and re-run; verify idempotency (second run should be all ok).


# Quick Facts (Revision)

- Ansible connects with SSH; no daemon or agent runs on managed nodes.
- Exit code `0` = all tasks ok/skipped; non-zero = at least one failure.
- Idempotent = running the same playbook twice produces the same result without extra changes.
- `gather_facts: false` skips fact collection (speeds up runs when facts are unused).
- Handlers run **once** at the end of a play, not once per `notify`.
- `--check` never changes anything; useful for pre-flight validation.
- Vault password is required at runtime: `--vault-password-file` or `--ask-vault-pass`.


# Topic Map

- [01-ansible-overview](./01-ansible-overview.md) — concepts, terms, first playbook
- [02-inventory-and-ansible-cfg](./02-inventory-and-ansible-cfg.md) — inventory, groups, `ansible.cfg`
- [003-playbooks-tasks-handlers](./003-playbooks-tasks-handlers.md) — tasks, handlers, notify/restart
- [004-variables-facts-templating](./004-variables-facts-templating.md) — vars, facts, Jinja2 templates
- [005-loops-conditions-blocks](./005-loops-conditions-blocks.md) — loop, when, block/rescue
- [006-roles-collections-galaxy](./006-roles-collections-galaxy.md) — roles, structure, reuse
- [007-tags-strategies-debugging](./007-tags-strategies-debugging.md) — tags, limit, debug, verbosity
- [008-vault-secrets](./008-vault-secrets.md) — secrets, vault encrypt/decrypt
- [009-dynamic-inventory-and-cloud](./009-dynamic-inventory-and-cloud.md) — dynamic inventory, plugins
- [010-best-practices-testing](./010-best-practices-testing.md) — structure, lint, molecule
