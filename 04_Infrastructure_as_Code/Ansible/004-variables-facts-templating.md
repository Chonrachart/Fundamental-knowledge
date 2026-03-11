variables
facts
register
jinja2
group_vars
host_vars

---

# Variables

- Variables can be defined in many places.
- The same var name can be overridden by higher precedence sources.

### Common Variable Sources

- Inventory: `group_vars/`, `host_vars/`
- Play vars: `vars:`, `vars_files:`
- Role vars and defaults
- Extra vars: `-e key=value` (very high precedence)

### Precedence (rough idea)

- Extra vars are highest.
- Role defaults are lowest.
- Many layers exist in between; avoid relying on deep precedence tricks.

# Facts

- Facts are information collected from hosts (OS, IP, CPU, etc.).
- Default behavior: `gather_facts: true` at start of play.

```yaml
- name: Example
  hosts: all
  gather_facts: true
  tasks:
  - debug:
      var: ansible_hostname
```

# register

- `register` stores the result of a task (stdout, rc, changed, etc.).

```yaml
- name: Check nginx
  command: nginx -v
  register: nginx_version
  changed_when: false

- debug:
    var: nginx_version.stderr
```

# set_fact

- `set_fact` sets variables at runtime (per host).
- Useful but can make playbook harder to reason about if overused.

```yaml
- set_fact:
    app_port: 8080
```

# Jinja2 and Templating

- Jinja2 expressions use `{{ }}`.
- Conditionals/loops in templates use `{% %}`.
- Use `default()` to avoid undefined errors.

```yaml
- name: Render config
  template:
    src: app.conf.j2
    dest: /etc/app/app.conf
```

```text
# app.conf.j2 (example)
port={{ app_port | default(8080) }}
```
