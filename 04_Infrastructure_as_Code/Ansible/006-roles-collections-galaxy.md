# Roles and Collections

- A role is a reusable, self-contained unit of automation: tasks, handlers, defaults, templates, and files in a standard directory layout.
- A collection is a distribution package of roles, modules, and plugins — installed via Ansible Galaxy.
- Roles keep playbooks small; collections extend Ansible with vendor/community content.


# Role Directory Layout

```text
roles/
  nginx/                        ← role name
    tasks/
      main.yml                  ← entry point; all tasks go here (or include sub-files)
    handlers/
      main.yml                  ← handlers used by this role
    defaults/
      main.yml                  ← default variable values (lowest precedence; easy to override)
    vars/
      main.yml                  ← role-internal constants (higher precedence; harder to override)
    templates/
      nginx.conf.j2             ← Jinja2 templates
    files/
      index.html                ← static files for copy module
    meta/
      main.yml                  ← role dependencies, Galaxy metadata
```

- `defaults/main.yml` = inputs/parameters for the role (put user-facing vars here).
- `vars/main.yml` = internal constants that should not be changed by callers.


# Mental Model: Role in a Playbook

```text
Playbook calls role
        |
        v
Ansible loads role from roles/ or collections/
        |
        v
Merge variable precedence:
  role defaults → group_vars → host_vars → role vars → extra-vars
        |
        v
Execute tasks/main.yml  (top-to-bottom)
  can include sub-files: include_tasks / import_tasks
        |
        v
Register handlers from handlers/main.yml
        |
        v
End of play → flush handlers
```


# Using Roles in a Playbook

```yaml
# simple usage
- name: Configure web servers
  hosts: web
  roles:
    - nginx
    - { role: app, app_port: 8080 }   # pass vars inline

# with pre/post tasks
- name: Full deploy
  hosts: web
  pre_tasks:
    - name: Update apt cache
      ansible.builtin.apt:
        update_cache: true
      when: ansible_os_family == "Debian"
  roles:
    - nginx
    - app
  post_tasks:
    - name: Smoke test
      ansible.builtin.uri:
        url: http://localhost/health
        status_code: 200
```


# include_role vs import_role

| | `import_role` | `include_role` |
|---|---|---|
| Timing | Static (parsed at load time) | Dynamic (resolved at runtime) |
| Works with `loop` | No | Yes |
| Works with `when` | Evaluated once at parse | Evaluated per iteration |
| Tags apply to tasks inside | Yes | No (add tags inside role) |

```yaml
# dynamic: can use with when / loop
- name: Include role conditionally
  ansible.builtin.include_role:
    name: nginx
  when: enable_nginx | bool

# static: better for tags and predictability
- name: Import role always
  ansible.builtin.import_role:
    name: common
```


# Collections

```text
Collection namespace: vendor.collection_name
  e.g.  community.general
        amazon.aws
        ansible.posix
        kubernetes.core
```

- Collections bundle roles + modules + plugins into one installable package.
- Use FQCN in tasks: `amazon.aws.ec2_instance` (avoids ambiguity).

```yaml
# collections/requirements.yml
collections:
  - name: community.general
    version: ">=7.0.0"
  - name: amazon.aws
    version: ">=6.0.0"

roles:
  - name: geerlingguy.nginx
    version: "3.2.0"
```

Related notes:
- [009-dynamic-inventory-and-cloud](./009-dynamic-inventory-and-cloud.md) — amazon.aws collection for dynamic inventory

---

# Practical Command Set (Core)

```bash
# create role scaffold
ansible-galaxy role init roles/nginx

# install from requirements file
ansible-galaxy role install -r collections/requirements.yml
ansible-galaxy collection install -r collections/requirements.yml

# install single collection
ansible-galaxy collection install community.general

# list installed collections
ansible-galaxy collection list

# show role info
ansible-galaxy role info geerlingguy.nginx
```


# Troubleshooting Guide

```text
Problem: Role variable has wrong value
    |
    v
[1] Check precedence: defaults < group_vars < host_vars < vars < extra-vars
    |
    v
[2] Add debug task at start of role's tasks/main.yml to print key vars

---

Problem: Role not found error
    |
    v
[1] Check roles_path in ansible.cfg (default: ./roles)
    |
    v
[2] Run: ansible-galaxy role install -r requirements.yml

---

Problem: Module not found from collection
    |
    v
[1] Run: ansible-galaxy collection install <namespace.collection>
    |
    v
[2] Use FQCN: namespace.collection.module_name
```


# Quick Facts (Revision)

- Use `defaults/main.yml` for role inputs — they are easy for callers to override.
- Use `vars/main.yml` only for internal constants that should not be changed externally.
- `include_role` is dynamic (supports `loop`/`when` at runtime); `import_role` is static (better for tags).
- Always pin collection versions in `requirements.yml` for reproducible installs.
- Use FQCN (`namespace.collection.module`) to avoid module ambiguity in collections.
- `meta/main.yml` can declare role dependencies — Ansible installs them automatically.
- Keep roles small and single-purpose; compose them in playbooks rather than nesting deeply.
