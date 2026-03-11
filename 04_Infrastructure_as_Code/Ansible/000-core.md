# Ansible Core

- Ansible is agentless automation for configuration, deployment, and orchestration.
- Control node runs Ansible; managed nodes are reached by SSH (Linux) or WinRM (Windows).
- Playbooks describe desired state; modules try to be idempotent (safe to run repeatedly).

# Core Flow (who → what → how → values → result)

### Who (targets)

- Inventory = list of hosts and groups + connection variables.
- Group = label in inventory (example: `web`, `db`, `prod`); patterns select targets.

### What (desired state)

- Playbook = YAML file with one or more plays.
- Play = `hosts` + `vars` + `tasks` (or `roles`).
- Task = call a module with arguments.
- Role = reusable set of tasks/vars/templates/files (keeps playbooks small).

### How (work units)

- Module = unit of work (package, file, service, template, user, ...).
- Prefer modules over `shell`/`command` (safer + more idempotent).
- `become: true` = run tasks with sudo (common for packages/services/files).

### Values (data, not instructions)

- Variables are key/value data used by tasks/templates: `{{ var_name }}`.
- `group_vars/<group>.yml` applies to every host in a group.
- `host_vars/<host>.yml` applies to one host (usually overrides group).
- Vault encrypts secret variables (still “data”, just protected).

```yaml
# data: group_vars/web.yml
nginx_port: 8080
```

```yaml
# instruction: task uses the data via template
- name: Render nginx config
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: restart nginx
```

```text
# template: nginx.conf.j2
listen {{ nginx_port }};
```

### Result (what you see)

- Facts: auto-collected data about the host (OS, IPs, etc.).
- `ok` already correct, `changed` modified, `failed` error, `skipped` not run.

# Learning Path

- [001-ansible-overview.md](001-ansible-overview.md) — concepts, terms, first playbook
- [002-inventory-and-ansible-cfg.md](002-inventory-and-ansible-cfg.md) — inventory, groups, `ansible.cfg`
- [003-playbooks-tasks-handlers.md](003-playbooks-tasks-handlers.md) — tasks, handlers, notify/restart
- [004-variables-facts-templating.md](004-variables-facts-templating.md) — vars, facts, Jinja templates
- [005-loops-conditions-blocks.md](005-loops-conditions-blocks.md) — loop, when, block/rescue
- [006-roles-collections-galaxy.md](006-roles-collections-galaxy.md) — roles, structure, reuse
- [007-tags-strategies-debugging.md](007-tags-strategies-debugging.md) — tags, limit, debug, verbosity
- [008-vault-secrets.md](008-vault-secrets.md) — secrets, vault encrypt/decrypt
- [009-dynamic-inventory-and-cloud.md](009-dynamic-inventory-and-cloud.md) — dynamic inventory, plugins
- [010-best-practices-testing.md](010-best-practices-testing.md) — structure, lint, molecule (idea)

# Recommended Project Layout

```text
ansible/
  ansible.cfg
  inventory/
    hosts.ini
    group_vars/
    host_vars/
  playbooks/
    site.yml
  roles/
    nginx/
      tasks/main.yml
      handlers/main.yml
      defaults/main.yml
      templates/
      files/
  collections/
    requirements.yml
```

# Some CLI

```bash
# command structures
ansible <pattern> -i <inventory> -m <module> [-a "<module_args>"] [--become] [-v|-vv|-vvv]
ansible-playbook -i <inventory> <playbook.yml> [--limit <pattern>] [--tags <t1,t2>] [--check] [--diff] [-v|-vv|-vvv]
ansible-inventory -i <inventory> --graph
ansible-inventory -i <inventory> --list
ansible-config dump --only-changed

# quick check 
ansible --version
ansible localhost -c local -m ping
```
