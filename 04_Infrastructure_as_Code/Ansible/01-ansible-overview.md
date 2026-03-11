ansible
control node
managed node
playbook
inventory
module
idempotent

---

# Ansible

- Agentless automation tool.
- Control node runs Ansible.
- Managed nodes are reached via SSH (Linux) or WinRM (Windows).
- You define desired state; modules try to make it idempotent.

# Core Concepts

### Inventory

- Inventory is the list of target hosts and groups.
- Can be static (INI/YAML) or dynamic (cloud/plugin).
- `hosts: webservers` means "run against group webservers in inventory".

### Playbook

- Playbook is YAML with one or more plays.
- A play targets hosts and runs tasks (or roles).
- A task calls a module.

### Module

- Module is the unit of work (package, file, service, template, user, etc.).
- Prefer modules over `shell` and `command` because modules are safer and idempotent.

### Idempotent

- Idempotent means running again does not create extra changes.
- Example: "ensure nginx is installed" can be run many times.

# Basic Example

```yaml
- name: Install and start nginx
  hosts: webservers
  become: true
  tasks:
  - name: Install nginx
    package:
      name: nginx
      state: present
  - name: Start nginx
    service:
      name: nginx
      state: started
      enabled: true
```
[setup-user.yaml](https://github.com/Chonrachart/Script/blob/main/Ansible/Bootstrap/playbooks/setup-user.yaml)

# How Ansible Runs

- Ansible connects to each host (SSH/WinRM).
- Copies a small module payload and executes it.
- Collects output and reports `ok`, `changed`, `failed`, `skipped`.

# Common Commands

```bash
# ad-hoc (one command / one module)
# all mean pattern in inventory (all host) can use other name 
# like web to match just web
ansible all -m ping -i inventory/hosts.ini
ansible web -m ping 

# run a playbook
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
# if set in config like inventory = ./inventory/inventory.yaml
ansible-playbook playbooks/site.yaml # can skip -i

# debug selection
ansible-inventory -i inventory/hosts.ini --graph
```

# Things You Should Know Early

- Host patterns: `all`, `web`, `web[0]`, `web:&prod`, `web:!canary`.
- Variables are everywhere, and precedence matters.
- Handlers run when notified (restart service only when config changed).
