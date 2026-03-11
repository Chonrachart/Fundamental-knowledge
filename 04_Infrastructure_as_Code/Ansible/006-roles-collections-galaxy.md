role
collection
ansible-galaxy
include_role
import_role
requirements

---

# Role

- Role is a reusable unit: tasks, handlers, defaults, templates, files.
- Playbook uses roles to keep code organized and reusable.

```text
roles/
  nginx/
    tasks/main.yml
    handlers/main.yml
    defaults/main.yml
    vars/main.yml
    templates/
    files/
    meta/main.yml
```

```yaml
- name: Web
  hosts: web
  roles:
    - nginx
```

# defaults vs vars

- `defaults/main.yml` is lowest precedence (safe default values).
- `vars/main.yml` is higher precedence (harder to override).
- Prefer `defaults` for most role parameters.

# include_role vs import_role

- `import_role` is static (parsed at parse time).
- `include_role` is dynamic (can be used with `when`, `loop`, runtime decisions).

```yaml
- name: Include role dynamically
  include_role:
    name: nginx
  when: enable_nginx
```

# Collections

- Collection is a package of roles + modules + plugins.
- Namespaced like `vendor.namespace`.
- Example: `community.general`, `amazon.aws`.

# ansible-galaxy

```bash
# install a role
ansible-galaxy role install geerlingguy.nginx

# install a collection
ansible-galaxy collection install community.general
```

### requirements.yml

```yaml
collections:
  - name: community.general
    version: ">=7.0.0"
roles:
  - name: geerlingguy.nginx
```

```bash
ansible-galaxy install -r collections/requirements.yml
```

# Best Practices for Roles

- Keep roles small and composable.
- Use handlers for restarts.
- Put role inputs in `defaults/main.yml`.
- Avoid shell unless needed; prefer modules.
