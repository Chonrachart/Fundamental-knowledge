# Best Practices and Testing

- Ansible is easy to start but hard to scale without discipline — structure and testing prevent playbook rot.
- Key principles: idempotency, small roles, explicit variable scoping, version-pinned dependencies.
- Testing pyramid: `--check --diff` -> `ansible-lint` -> molecule (role-level integration test).


# Project Structure (Recommended)

```text
ansible/
  ansible.cfg                   <- project config (inventory, forks, pipelining)
  inventory/
    inventory.yaml              <- static or dynamic inventory config
    group_vars/
      all/
        vars.yml                <- non-sensitive vars for all hosts
        secrets.yml             <- vault-encrypted secrets
      web/
        vars.yml
    host_vars/
      web1.yml
  playbooks/
    site.yml                    <- main entry point (calls roles)
    bootstrap.yml               <- first-run setup (create users, SSH keys)
  roles/
    common/                     <- applied to every host
    nginx/
    app/
  collections/
    requirements.yml            <- pinned collection + role versions
  .vault_pass.txt               <- gitignored vault password file
  .gitignore
```


# Core Building Blocks

### Idempotency Rules

```text
Write playbook -> run it -> run it again -> second run must be all ok / skipped
```

```bash
# idempotency check: run twice, second run should be all ok
ansible-playbook site.yml && ansible-playbook site.yml

# pre-flight review
ansible-playbook site.yml --check --diff
```

- Use modules (`ansible.builtin.package`, `ansible.builtin.file`, `ansible.builtin.service`) over `shell`/`command` — modules check state.
- When `command`/`shell` is unavoidable, add `changed_when` and `creates`/`removes`.

```yaml
# bad: always reports changed
- ansible.builtin.command: mkdir -p /opt/app

# good: use file module (idempotent)
- ansible.builtin.file:
    path: /opt/app
    state: directory
    mode: "0755"

# acceptable: command with creates guard
- ansible.builtin.command: /opt/install.sh
  args:
    creates: /opt/app/.installed   # skip if this file exists
```

### Variable Discipline

```yaml
# role defaults/main.yml  -- document every input variable
nginx_port: 80              # port nginx listens on
nginx_worker_processes: auto  # number of worker processes
nginx_log_dir: /var/log/nginx

# group_vars/web/vars.yml  -- environment-specific values
nginx_port: 8080

# host_vars/web1.yml  -- host-specific overrides (use sparingly)
# nginx_port: 9090
```

- Keep `defaults/main.yml` well-commented — it is the role's public API.
- Avoid setting the same variable in multiple places; trace the precedence chain first.

Related notes:
- [004-variables-facts-templating](./004-variables-facts-templating.md)

### Linting with ansible-lint

```bash
# install
pip install ansible-lint

# run against a playbook
ansible-lint playbooks/site.yml

# run against all playbooks and roles
ansible-lint

# auto-fix safe issues
ansible-lint --fix

# syntax check only (catches YAML/Jinja2 errors without connecting)
ansible-playbook site.yml --syntax-check
```

Common issues caught:
- Tasks missing `name:`
- Using deprecated module names (e.g. `apt` instead of `ansible.builtin.apt`)
- `shell` used when a module exists
- Hardcoded passwords in vars files
- `become: true` at task level when it could be at play level

Related notes:
- [007-tags-strategies-debugging](./007-tags-strategies-debugging.md)

### Testing with Molecule (Role-level)

```text
Molecule test flow:
  create     -> spin up test instance (Docker / Vagrant / cloud VM)
  converge   -> run the role against it
  verify     -> run assertions (testinfra / ansible verify tasks)
  destroy    -> tear down the instance
```

```bash
# install
pip install molecule molecule-docker

# scaffold molecule in an existing role
cd roles/nginx
molecule init scenario

# run full test cycle
molecule test

# iterate: converge only (keep instance running)
molecule converge
molecule verify
molecule destroy
```

```yaml
# roles/nginx/molecule/default/verify.yml
- name: Verify nginx
  hosts: all
  tasks:
    - name: Check nginx is running
      ansible.builtin.service_facts:

    - name: Assert nginx service active
      ansible.builtin.assert:
        that: ansible_facts.services['nginx.service'].state == 'running'

    - name: Check port 80 is listening
      ansible.builtin.wait_for:
        port: 80
        timeout: 5
```



- Idempotency: second run must produce zero `changed` results.
- Use `args: creates:` as a guard for `command` tasks that are not natively idempotent.
- `ansible-lint` catches style and safety issues early — run it in CI.
- Molecule tests roles in isolation; use Docker for fast local iteration.
- Pin `requirements.yml` versions — unpinned installs break on Galaxy updates.
- `--syntax-check` catches YAML/Jinja2 errors without connecting to any host.
- Keep `defaults/main.yml` documented — it is the contract between the role and its callers.
# Troubleshooting Guide

### Playbook not idempotent (changed on second run)

1. Find the task(s) reporting changed.
2. Check if a module exists for that operation (replace `shell`/`command`).
3. Add `changed_when: false` if it is truly read-only.
4. Add `creates:` / `removes:` for command tasks with side effects.

### ansible-lint reports issues

1. Fix FQCN, add missing `name:`, and replace deprecated modules.

### Molecule converge fails

1. Run `molecule converge --debug` for full output.
2. Check if the Docker image matches the target OS (e.g. `ubuntu:22.04` vs `rocky:9`).

