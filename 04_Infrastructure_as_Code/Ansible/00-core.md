# Ansible Core Overview

- Agentless automation for configuration, deployment, and orchestration.
- Control node pushes work over SSH (Linux) or WinRM (Windows) — no agent on managed nodes.
- Playbooks describe desired state; modules enforce it idempotently.
- For detailed concepts, architecture, and first playbook: see [001-ansible-overview](./001-ansible-overview.md).

# Architecture

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

- Inventory tells Ansible *which* hosts exist; playbooks tell it *what* to do on them.
- Modules are copied to managed nodes, executed, and then removed automatically.


# Core Building Blocks

### Inventory (Who)

- List of hosts + groups + connection variables (INI, YAML, or dynamic plugins).
- `group_vars/<group>.yml` for group variables; `host_vars/<host>.yml` for host overrides.

```bash
ansible-inventory -i <inventory> --graph
```

Related notes:
- [002-inventory-and-ansible-cfg](./002-inventory-and-ansible-cfg.md)

### Playbooks and Tasks (What)

- Playbook = YAML with plays; play = `hosts` + `tasks` (or `roles`).
- Task = call a module with named arguments.

```bash
ansible-playbook -i <inventory> site.yml
ansible-playbook -i <inventory> site.yml --check --diff   # dry-run
```

Related notes:
- [001-ansible-overview](./001-ansible-overview.md)
- [003-playbooks-tasks-handlers](./003-playbooks-tasks-handlers.md)

### Modules (How)

- Unit of work: `package`, `file`, `service`, `template`, `copy`, `command`.
- Prefer built-in modules over `shell`/`command` for idempotency.

```bash
ansible <pattern> -i <inventory> -m <module> [-a "<args>"] [--become]
```

Related notes:
- [003-playbooks-tasks-handlers](./003-playbooks-tasks-handlers.md)

### Variables and Templates (Values)

- Precedence (low to high): role defaults, group_vars, host_vars, extra-vars (`-e`).
- Jinja2 templates (`.j2`) combine static config with dynamic values.
- Ansible Vault encrypts secrets at rest.

Related notes:
- [004-variables-facts-templating](./004-variables-facts-templating.md)
- [008-vault-secrets](./008-vault-secrets.md)

### Roles and Collections (Reuse)

- Role = self-contained unit: `tasks/`, `handlers/`, `defaults/`, `templates/`, `files/`.
- Collection = bundle of roles + modules + plugins via Ansible Galaxy.

Related notes:
- [006-roles-collections-galaxy](./006-roles-collections-galaxy.md)

### Control Flow (Logic)

- `loop` iterates a task; `when` adds conditions; `block`/`rescue`/`always` handles errors.

Related notes:
- [005-loops-conditions-blocks](./005-loops-conditions-blocks.md)


- Idempotent = running the same playbook twice produces the same result without extra changes.
- Handlers run **once** at end of play, not once per `notify`.
- `--check` never changes anything; useful for pre-flight validation.
- Exit code `0` = all tasks ok/skipped; non-zero = at least one failure.
- Vault password required at runtime: `--vault-password-file` or `--ask-vault-pass`.
# Troubleshooting Guide

### Task fails or behaves unexpectedly

1. Re-run with `--check --diff` to see what would change.
2. Add `-vvv` to see SSH connection, module args, and raw output.
3. Insert a debug task to print vars/facts mid-play.
4. Check inventory with `ansible-inventory --graph` or `--list`.
5. Check variable precedence (extra-vars win; role defaults lose).
6. Run the ad-hoc module directly on one host.
7. Fix and re-run; verify idempotency (second run should be all ok).


# Topic Map

- [001-ansible-overview](./001-ansible-overview.md) — concepts, terms, first playbook
- [002-inventory-and-ansible-cfg](./002-inventory-and-ansible-cfg.md) — inventory, groups, `ansible.cfg`
- [003-playbooks-tasks-handlers](./003-playbooks-tasks-handlers.md) — tasks, handlers, notify/restart
- [004-variables-facts-templating](./004-variables-facts-templating.md) — vars, facts, Jinja2 templates
- [005-loops-conditions-blocks](./005-loops-conditions-blocks.md) — loop, when, block/rescue
- [006-roles-collections-galaxy](./006-roles-collections-galaxy.md) — roles, structure, reuse
- [007-tags-strategies-debugging](./007-tags-strategies-debugging.md) — tags, limit, debug, verbosity
- [008-vault-secrets](./008-vault-secrets.md) — secrets, vault encrypt/decrypt
- [009-dynamic-inventory-and-cloud](./009-dynamic-inventory-and-cloud.md) — dynamic inventory, plugins
- [010-best-practices-testing](./010-best-practices-testing.md) — structure, lint, molecule
- [011-command-shell-execution](./011-command-shell-execution.md) — command, shell, raw, script modules and idempotency guards
