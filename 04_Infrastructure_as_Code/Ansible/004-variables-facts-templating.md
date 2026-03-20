# Variables, Facts, and Templating

- Variables are key/value data consumed by tasks and templates: `{{ var_name }}`.
- Facts are variables auto-collected from the managed node at play start (OS, IPs, CPU, etc.).
- Jinja2 templates combine static config with dynamic variable values.


# Variable Precedence (low -> high)

```text
role defaults          (defaults/main.yml)       <- easiest to override
    |
    v
inventory group_vars/all
    |
    v
inventory group_vars/<group>
    |
    v
inventory host_vars/<host>
    |
    v
play vars / vars_files
    |
    v
role vars              (vars/main.yml)
    |
    v
task vars / set_fact / register
    |
    v
extra vars  (-e key=value)                       <- always wins
```

- Rule of thumb: use `defaults/` for role inputs (easy to override), `vars/` for internal role constants.
- Avoid relying on deep precedence tricks — prefer explicit variable scoping.


# Core Building Blocks

### group_vars / host_vars

```yaml
# group_vars/web.yml  ->  applies to all hosts in "web"
nginx_port: 8080
app_env: production
```

```yaml
# host_vars/web1.yml  ->  overrides group for web1 only
nginx_port: 9090
```

Related notes:
- [002-inventory-and-ansible-cfg](./002-inventory-and-ansible-cfg.md)

### Play vars

```yaml
- name: Deploy app
  hosts: web
  vars:
    app_version: "2.1.0"
  vars_files:
    - vars/secrets.yml        # loaded from file (can be vaulted)
```

### set_fact (runtime)

```yaml
- name: Compute derived variable
  ansible.builtin.set_fact:
    app_url: "http://{{ ansible_host }}:{{ app_port }}"
```

- `set_fact` sets a variable per-host at runtime; persists for remainder of play.
- Useful for derived values; avoid overusing as it makes flow harder to follow.

### register (capture task output)

```yaml
- name: Check nginx version
  ansible.builtin.command: nginx -v
  register: nginx_out
  changed_when: false           # read-only; never counts as changed

- name: Show version
  ansible.builtin.debug:
    var: nginx_out.stderr        # nginx -v writes to stderr
```

Common `register` fields: `.stdout`, `.stderr`, `.rc`, `.changed`, `.stdout_lines`.

### Facts

```text
Play starts
    |
    v
gather_facts: true  (default)
    |
    v
Ansible runs setup module on each host
    |
    v
Facts stored as variables: ansible_*
    |
    v
Available in all tasks and templates
```

```yaml
- ansible.builtin.debug:
    var: ansible_hostname        # short hostname
- ansible.builtin.debug:
    var: ansible_default_ipv4.address
- ansible.builtin.debug:
    var: ansible_os_family       # "Debian", "RedHat", etc.
- ansible.builtin.debug:
    var: ansible_distribution    # "Ubuntu", "CentOS", etc.
```

- `gather_facts: false` skips collection (faster runs when facts are unused).
- `ansible_facts` dict holds all facts; also accessible as top-level `ansible_*` vars.

Related notes:
- [005-loops-conditions-blocks](./005-loops-conditions-blocks.md) — using facts in `when:`

### Jinja2 Templating — In task arguments

```yaml
- name: Create app config
  ansible.builtin.template:
    src: app.conf.j2
    dest: /etc/app/app.conf
    mode: "0644"
```

### Jinja2 Templating — In template files (.j2)

```jinja2
# app.conf.j2
port={{ app_port | default(8080) }}
env={{ app_env }}
host={{ ansible_hostname }}

{% if app_env == "production" %}
log_level=warn
{% else %}
log_level=debug
{% endif %}
```

### Common Jinja2 filters

| Filter | Example | Result |
|---|---|---|
| `default` | `{{ port \| default(80) }}` | fallback if undefined |
| `upper` | `{{ name \| upper }}` | UPPERCASE |
| `lower` | `{{ name \| lower }}` | lowercase |
| `int` | `{{ "8080" \| int }}` | cast to integer |
| `join` | `{{ list \| join(",") }}` | `"a,b,c"` |
| `length` | `{{ list \| length }}` | count items |
| `selectattr` | `{{ users \| selectattr("active") }}` | filter list |

---

# Practical Command Set (Core)

```bash
# print all facts for a host
ansible web1 -m ansible.builtin.setup

# filter facts
ansible web1 -m ansible.builtin.setup -a "filter=ansible_default_ipv4"

# debug variable in playbook (add task)
- ansible.builtin.debug:
    var: my_variable

# pass extra var at runtime (highest precedence)
ansible-playbook site.yml -e "app_version=2.1.0"
ansible-playbook site.yml -e "@vars/overrides.yml"   # from file
```


# Troubleshooting Guide

### Variable has wrong value or is undefined

1. Add a debug task: `ansible.builtin.debug: var=<variable_name>`.
2. Check precedence -- is `host_vars` overriding `group_vars`?
3. Check if `-e` was passed (always wins).
4. Check if `set_fact` was called earlier in the play (runtime override).
5. Verify the fact value: `ansible web1 -m ansible.builtin.setup | grep <fact_name>`.
6. Use `| default(fallback)` in the template to handle undefined safely.


# Quick Facts (Revision)

- `{{ var }}` is substitution; `{% %}` is logic (conditionals/loops) in Jinja2.
- Always use `| default(value)` in templates for optional variables to avoid undefined errors.
- `register` output fields: `.stdout`, `.stderr`, `.rc`, `.changed`, `.stdout_lines`.
- `gather_facts: false` speeds up runs when no `ansible_*` facts are needed.
- `set_fact` is per-host and persists for the rest of the play only.
- Extra vars `-e` override everything — useful for CI/CD pipeline overrides.
- `ansible_os_family` returns `"Debian"` or `"RedHat"` — good for branching config by distro.
