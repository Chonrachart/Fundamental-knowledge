Ansible
playbook
inventory
module
idempotent

---

# Ansible

- Agentless automation; uses SSH (or WinRM) to manage hosts.
- Config and app deployment; YAML playbooks describe desired state.

# Playbook

- List of plays; each play has hosts, roles or tasks.
- Tasks call modules (e.g. `yum`, `copy`, `template`, `service`).

```yaml
- name: Install nginx
  hosts: webservers
  tasks:
  - name: Install nginx package
    yum:
      name: nginx
      state: present
  - name: Start nginx
    service:
      name: nginx
      state: started
```

# Inventory

- Defines hosts and groups; can be static file or dynamic (e.g. from cloud).
- `hosts: webservers` refers to inventory group.

# Module

- Unit of work (e.g. `copy`, `template`, `lineinfile`, `command`).
- Most are idempotent: safe to run multiple times.

# Idempotent

- Running the same playbook again produces the same result; no duplicate changes.
- Ansible modules are designed to be idempotent where possible.

# Key Commands

```bash
ansible-playbook playbook.yml
ansible all -m ping
ansible webservers -a "systemctl status nginx"
```
