inventory
ansible.cfg
groups
host_vars
group_vars
connection vars

---

# Inventory

- Inventory defines hosts and groups.
- You can keep it simple at first: one `hosts.ini` file.

### Static Inventory (INI)

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

### Static Inventory (YAML)

```yaml
all:
  children:
    web:
      hosts:
        web1:
          ansible_host: 192.168.1.10
    db:
      hosts:
        db1:
          ansible_host: 192.168.1.20
```

# Host Patterns

- `all` everything
- `web` group
- `web1` single host
- `web:&prod` intersection
- `web:!canary` exclude

# group_vars and host_vars

- `group_vars/web.yml` applies to all hosts in group `web`.
- `host_vars/web1.yml` applies only to `web1`.
- This keeps playbooks generic.

```text
inventory/
  hosts.ini
  group_vars/
    web.yml
    prod.yml
  host_vars/
    web1.yml
```

# Connection Variables (common)

- `ansible_host`: real IP/hostname
- `ansible_user`: ssh user
- `ansible_port`: ssh port
- `ansible_ssh_private_key_file`: key path
- `ansible_become`: enable privilege escalation
- `ansible_become_method`: sudo, su, etc.
- `ansible_become_user`: usually root

# ansible.cfg

- `ansible.cfg` controls defaults for inventory, ssh args, forks, timeouts, etc.
- Ansible reads config with precedence (project > user > system).

```ini
[defaults]
inventory = inventory/hosts.ini
retry_files_enabled = false
host_key_checking = false
forks = 20

[ssh_connection]
pipelining = true
```

- Note: `host_key_checking = false` is convenient for labs, but not recommended for production.

# Useful Config Commands

```bash
ansible-config dump --only-changed
ansible-config view
```

# Useful Inventory Commands

```bash
ansible-inventory --graph
ansible-inventory --list
ansible web -m ping
```
