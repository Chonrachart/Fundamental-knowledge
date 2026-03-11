tags
limit
check mode
diff
strategy
debug

---

# Tags

- Tag tasks or roles to run only part of a playbook.
- Useful for `install`, `config`, `deploy`, `restart`, etc.

```yaml
- name: Install nginx
  package:
    name: nginx
    state: present
  tags: install
```

```bash
ansible-playbook playbooks/site.yml --tags install
ansible-playbook playbooks/site.yml --skip-tags config
```

# limit and start-at-task

```bash
ansible-playbook playbooks/site.yml --limit web
ansible-playbook playbooks/site.yml --start-at-task "Deploy config"
```

# Check Mode and Diff

- `--check` runs in dry-run mode (not perfect for all modules).
- `--diff` shows changes for templated/copied files.

```bash
ansible-playbook playbooks/site.yml --check --diff
```

# Strategy and Serial

- `strategy: linear` default; hosts run task-by-task together.
- `strategy: free` hosts run as fast as possible (can be harder to read).
- `serial` does rolling updates (batch by batch).

```yaml
- name: Rolling deploy
  hosts: web
  serial: 2
  strategy: linear
  tasks:
  - debug:
      msg: "deploy"
```

# Debugging

- Use `-v`, `-vv`, `-vvv` for more detail.
- Use `debug:` to print vars.
- Use `assert:` to fail early with clear message.

```yaml
- debug:
    var: some_var

- assert:
    that:
      - app_port is defined
```
