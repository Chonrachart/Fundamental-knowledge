ansible
inventory
playbook
role
variables
vault
tags

---

# Ansible Core

- Ansible is agentless automation for configuration, deployment, and orchestration.
- Control node runs Ansible; managed nodes are reached by SSH (Linux) or WinRM (Windows).
- Playbooks describe desired state; modules try to be idempotent (safe to run repeatedly).

# Learning Path (Easy -> Hard)

# Easy

- [001-ansible-overview.md](001-ansible-overview.md)
- [002-inventory-and-ansible-cfg.md](002-inventory-and-ansible-cfg.md)
- [003-playbooks-tasks-handlers.md](003-playbooks-tasks-handlers.md)

# Medium

- [004-variables-facts-templating.md](004-variables-facts-templating.md)
- [005-loops-conditions-blocks.md](005-loops-conditions-blocks.md)
- [006-roles-collections-galaxy.md](006-roles-collections-galaxy.md)

# Hard

- [007-tags-strategies-debugging.md](007-tags-strategies-debugging.md)
- [008-vault-secrets.md](008-vault-secrets.md)
- [009-dynamic-inventory-and-cloud.md](009-dynamic-inventory-and-cloud.md)
- [010-best-practices-testing.md](010-best-practices-testing.md)

# Recommended Project Layout

```text
ansible/
  ansible.cfg
  inventory/
    hosts.ini
    group_vars/
    host_vars/
  playbooks/
    site.yml
  roles/
    nginx/
      tasks/main.yml
      handlers/main.yml
      defaults/main.yml
      templates/
      files/
  collections/
    requirements.yml
```

# CLI Cheat Sheet

```bash
ansible --version
ansible all -m ping -i inventory/hosts.ini
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# target selection
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit web

# run partial
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --tags install
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --skip-tags config

# dry run
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check --diff

# show inventory
ansible-inventory -i inventory/hosts.ini --graph
ansible-inventory -i inventory/hosts.ini --list
```
