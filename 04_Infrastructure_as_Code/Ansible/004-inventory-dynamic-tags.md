inventory
dynamic inventory
groups
host_vars
group_vars
tags
include
roles

---

# Inventory — Static File

- **INI or YAML**; define hosts and groups; optional vars per host/group.
- **Groups** can have **children** (e.g. webservers, dbs; children: prod_webservers under webservers).
- **Ranges**: `host[1:5]` = host1..host5; **alias**: `alias ansible_host=10.0.0.1`.

```ini
[webservers]
web1 ansible_host=192.168.1.10
web2 ansible_host=192.168.1.11

[databases]
db1

[prod:children]
webservers
databases
```

# Dynamic Inventory

- **Script** or **plugin** that outputs JSON (or YAML) with hosts and groups; Ansible runs it to get current list.
- **Cloud**: ec2.py, aws_ec2, gcp_compute, azure_rm; **VMware**, **OpenStack** plugins.
- Use when hosts change often; vars can come from inventory script or from group_vars/host_vars keyed by group/host name.
- **-i script.py** or configure in ansible.cfg; script must support **--list** and **--host <host>**.

# group_vars and host_vars

- **group_vars/groupname.yml** (or groupname/): Vars for group **groupname**; all hosts in that group get these vars.
- **host_vars/hostname.yml**: Vars for host **hostname**; overrides group for that host.
- Precedence: host_vars > group_vars (child > parent) > play vars > role vars > defaults.
- Use for per-env (group_vars/prod.yml) or per-host overrides (host_vars/special-server.yml).

# Tags

- **tag** tasks or roles: **tags: [install, config]**; run only tagged tasks with **--tags install** or **--tags config**.
- **--skip-tags**: Skip tasks with given tags; **--tags tagged** runs only explicitly tagged tasks.
- **Special tags**: **always** (run unless --skip-tags always); **never** (run only with --tags never).
- Use to run “only config” or “only deploy” without running full playbook.

```yaml
tasks:
- name: Install package
  yum:
    name: nginx
    state: present
  tags: install
- name: Deploy config
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  tags: config
  notify: restart nginx
```

# include_role and import_role

- **include_role** (dynamic): Can use loops, conditionals; role is included at runtime; **import_role** (static): Parsed at parse time; no loop over roles.
- **tasks_from**, **vars_from**: Run subset of role (e.g. only install.yml) or different vars file.
- Use **include_role** when you need **loop: ...** over roles or **when**; **import_role** for static inclusion and when using **tags** on role.

# Role Tags

- **roles: - role: nginx; tags: [web]** — all tasks in role get tag **web** (when using static import).
- **include_role** with **tags**: Only that include is tagged; tasks inside role keep their own tags.
- Run “all nginx” with **--tags web** or “only nginx install” if role tasks have subtags.
