# Inventory and ansible.cfg

- Inventory tells Ansible **which hosts exist** and how to reach them.
- Hosts are organised into **groups**; variables scoped to groups/hosts live in `group_vars/` and `host_vars/`.
- `ansible.cfg` sets project-wide defaults (inventory path, SSH args, forks, etc.).


# Inventory Architecture

```text
inventory/
  hosts.ini (or inventory.yaml)     <- host list + groups
  group_vars/
    all.yml                         <- vars for every host
    web.yml                         <- vars for group "web"
    prod.yml                        <- vars for group "prod"
  host_vars/
    web1.yml                        <- vars for host "web1" only
```

```text
Variable precedence (low -> high):

  role defaults
      |
      v
  group_vars/all
      |
      v
  group_vars/<group>
      |
      v
  host_vars/<host>           <- wins over group
      |
      v
  extra vars (-e)            <- always wins
```


# Core Building Blocks

### Inventory Formats — Static INI

```ini
[web]
web1 ansible_host=192.168.1.10
web2 ansible_host=192.168.1.11

[db]
db1 ansible_host=192.168.1.20

[prod:children]
web
db
```

### Inventory Formats — Static YAML (preferred for readability)

```yaml
all:
  vars:
    ansible_user: deploy
    ansible_become: true

  children:
    web:
      hosts:
        web1:
          ansible_host: 10.0.1.10
        web2:
          ansible_host: 10.0.1.11

    db:
      hosts:
        db1:
          ansible_host: 10.0.1.20

    prod:
      children:
        web:
        db:
```

### group_vars / host_vars

```yaml
# group_vars/web.yml
nginx_port: 8080
```

```yaml
# host_vars/web1.yml
nginx_port: 9090   # overrides group value for web1 only
```

Related notes:
- [004-variables-facts-templating](./004-variables-facts-templating.md)

### Host Patterns

| Pattern | Meaning |
|---|---|
| `all` | Every host in inventory |
| `web` | All hosts in group `web` |
| `web,db` | Union of groups `web` and `db` |
| `web:&prod` | Intersection: hosts in both `web` AND `prod` |
| `web:!web1` | All `web` hosts except `web1` |
| `web[0]` | First host in `web` |
| `web[0:2]` | First three hosts in `web` |
| `~web.*` | Regex match |

```bash
# inspect inventory
ansible-inventory --graph
ansible-inventory --list
ansible-inventory --host web1        # show all vars for a single host

# test reachability per group
ansible web -m ping
ansible all -m ping

# ad-hoc with connection var override
ansible web -m ping -u deploy --private-key ~/.ssh/id_ed25519
```

Related notes:
- [009-dynamic-inventory-and-cloud](./009-dynamic-inventory-and-cloud.md)

### Connection Variables (common)

| Variable | Purpose |
|---|---|
| `ansible_host` | Real IP or hostname |
| `ansible_user` | SSH login user |
| `ansible_port` | SSH port (default 22) |
| `ansible_ssh_private_key_file` | Path to private key |
| `ansible_become` | Enable privilege escalation |
| `ansible_become_method` | `sudo`, `su`, etc. |
| `ansible_become_user` | Target user (default: root) |
| `ansible_python_interpreter` | Python path on managed node |

### ansible.cfg

- Ansible reads config in precedence order: `./ansible.cfg` > `~/.ansible.cfg` > `/etc/ansible/ansible.cfg`.
- Project-level `ansible.cfg` (same directory as playbooks) is the most common setup.
- `ansible-config dump --only-changed` shows only non-default settings.

```ini
[defaults]
inventory           = inventory/inventory.yaml  # default inventory path; skip -i flag in commands
retry_files_enabled = false                     # don't create .retry files on failure (clutters repo)
host_key_checking   = false                     # skip SSH known_hosts check (lab only; disable in prod)
forks               = 20                        # parallel connections (default 5); tune to infra size
gathering           = smart                     # cache facts per host; re-gather only if host changes
interpreter_python  = auto_silent               # auto-detect Python on managed node without warning

[ssh_connection]
pipelining          = true         # bundle module steps into one SSH session; big speed boost
                                   # requires: Defaults !requiretty in /etc/sudoers on managed nodes
ssh_args            = -o ControlMaster=auto -o ControlPersist=60s  # reuse SSH connections for 60s
```

- `pipelining = true` requires `requiretty` to be disabled in sudoers on managed nodes.
- `host_key_checking = false` is acceptable in isolated lab environments only.



- `group_vars/<group>.yml` applies to **all hosts in the group**; `host_vars/<host>.yml` applies to **one host**.
- `host_vars` beats `group_vars`; `-e` (extra vars) beats everything.
- YAML inventory is preferred over INI for complex nested group structures.
- `[prod:children]` (INI) = `prod: children:` (YAML) — groups can contain other groups.
- `ansible-inventory --graph` is the fastest way to verify inventory structure.
- `pipelining = true` can significantly speed up playbook runs.
- Never commit `ansible.cfg` with `host_key_checking = false` to shared repos without a comment warning.
# Troubleshooting Guide

### Host unreachable

1. Run `ansible <host> -m ping -vvv` to see SSH attempt details.
2. Check `ansible_host` / `ansible_user` / `ansible_port` in host_vars.
3. Verify SSH key auth works manually: `ssh -i <key> user@host`.
4. Check `ansible.cfg` for the correct inventory path.

### Wrong host targeted or variable value unexpected

1. Run `ansible-inventory --graph` to confirm the host is in the correct group.
2. Check `group_vars`/`host_vars` precedence if the variable value is wrong.

