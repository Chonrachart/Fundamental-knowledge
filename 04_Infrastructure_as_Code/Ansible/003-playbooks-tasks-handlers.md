playbook
task
module
handler
notify
idempotent

---

# Playbook Structure

- Playbook contains one or more plays.
- Each play targets hosts and runs tasks.

```yaml
- name: Configure web
  hosts: web
  become: true
  tasks:
  - name: Install nginx
    package:
      name: nginx
      state: present
```

# Task

- A task calls a module with arguments.
- Task result is `ok`, `changed`, `failed`, or `skipped`.
- Use `name:` for readability.

### Common Task Fields

- `become: true` run with privilege escalation
- `register: result` store output
- `when: condition` run conditionally
- `changed_when:` override changed detection (careful)
- `failed_when:` override failure detection (careful)
- `tags:` label tasks for partial runs

# Modules (common)

- `package`: install/remove packages
- `service` or `systemd`: manage services
- `copy` / `template`: deploy files
- `file`: permissions, directory, symlink
- `user` / `group`: manage users
- `lineinfile` / `blockinfile`: edit files safely
- `get_url` / `unarchive`: download and extract
- `command` / `shell`: last option when module does not exist

```yaml
- name: Create dir
  file:
    path: /opt/app
    state: directory
    mode: "0755"
```

# Handlers

- Handler is a special task that runs only when notified.
- Use it for "restart service when config changed".
- Handlers run at end of play (per host) by default.

```yaml
tasks:
- name: Deploy config
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: restart nginx

handlers:
- name: restart nginx
  service:
    name: nginx
    state: restarted
```

### Handler Notes

- Multiple `notify` calls for same handler -> runs once.
- `meta: flush_handlers` runs handlers immediately (use carefully).
