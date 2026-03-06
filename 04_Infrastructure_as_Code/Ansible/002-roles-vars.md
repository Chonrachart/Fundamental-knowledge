role
variable
template
vault
group_vars

---

# Role

- Reusable unit: tasks, handlers, vars, defaults, templates, files; directory structure.
- `roles/myrole/tasks/main.yml`, `roles/myrole/defaults/main.yml`, etc.
- Play references role: `roles: [nginx]` or `role: nginx`.

```
roles/
  nginx/
    tasks/main.yml
    handlers/main.yml
    defaults/main.yml
    vars/main.yml
    templates/
    files/
```

# Variable

- **vars**, **vars_files**: Define in play or include file.
- **defaults**: Role defaults; overridable.
- **group_vars/<group>**, **host_vars/<host>**: Per group or host; no need to pass in play.
- Precedence: command line > play vars > role vars > group_vars > defaults.
- Reference: `{{ myvar }}`; use quotes in some contexts: `"{{ myvar }}"`.

# Template

- **template** module: Jinja2 file; `{{ var }}`, `{% for %}`, `{% if %}`.
- Source file in `templates/`; dest on host; same idempotent behavior as copy.

```yaml
- template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: restart nginx
```

# Vault

- Encrypt sensitive data (vars, files); `ansible-vault encrypt file.yml`.
- Run: `ansible-playbook playbook.yml --ask-vault-pass` or use vault password file.
- **ansible-vault edit**, **decrypt**, **rekey** for management.

# group_vars and host_vars

- **group_vars/webservers.yml**: Vars for group `webservers`.
- **host_vars/server1.yml**: Vars for host `server1`.
- Keeps playbooks generic; secrets in vault or external store.
