inventory
ansible.cfg
groups
host_vars
group_vars
connection vars

---

# Inventory

- Inventory defines hosts and groups(where should it run).


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
  vars: # this set varible in all can be over written by group_var of host_var
    ansible_user: chonrachart.s
    ansible_become: true

  children:
    web:
      hosts:
        web_apache:
          ansible_host: 10.100.75.49

    test:
      hosts:
        web-apache:
          ansible_host: 10.100.70.45
        app-tomcat:
          ansible_host: 10.100.75.49
```


# Host Patterns

- `all` everything
- `children` to define group
- `web, test` are group name
- `web-test, app-test, web_apache` single host name
- `web:&test` intersection (host exist in both `web` and `test`)
- `test:!web-test` exclude (host in `test` except `web-test`)
- `test[0]` first host
- `test[0:1]` slice 

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


# Useful Inventory Commands

```bash
ansible-inventory --graph
ansible-inventory --list
ansible web -m ping
```
