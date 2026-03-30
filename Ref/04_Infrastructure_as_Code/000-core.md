# Infrastructure as Code (IaC)

- Manage infrastructure (servers, networks, cloud resources) via code and config files.
- Versioned, reviewable, repeatable; reduces manual drift and errors.
- Key property: infrastructure changes follow the same review process as application code (PR, CI, audit trail).

# Declarative vs Imperative

- **Declarative**: Describe desired state (e.g. "3 instances, this AMI"); tool reconciles to that state (Terraform, CloudFormation).
- **Imperative**: Run fixed commands in order (shell scripts, ad-hoc Ansible tasks).
- **Convergent**: Declare desired state but with procedural steps (Ansible playbooks — idempotent tasks).

# State and Drift

- **State**: Tool tracks current infrastructure state; compares with desired state and applies diff.
- **Drift**: Real infrastructure diverges from code (manual change, provider bug).
- Terraform: `plan` shows drift; re-apply to correct. Ansible: re-run playbook to converge.
- Prevent: restrict manual changes; run IaC regularly (CI or scheduled).

# Topic Map (basic → advanced)

### Ansible
- [Ansible/001-ansible-overview](./Ansible/001-ansible-overview.md) — Concepts, terms, first playbook (start here)
- [Ansible/002-inventory-and-ansible-cfg](./Ansible/002-inventory-and-ansible-cfg.md) — Inventory, groups, `ansible.cfg`
- [Ansible/003-playbooks-tasks-handlers](./Ansible/003-playbooks-tasks-handlers.md) — Tasks, handlers, notify/restart
- [Ansible/004-variables-facts-templating](./Ansible/004-variables-facts-templating.md) — Vars, facts, Jinja2 templates
- [Ansible/005-loops-conditions-blocks](./Ansible/005-loops-conditions-blocks.md) — loop, when, block/rescue
- [Ansible/006-roles-collections-galaxy](./Ansible/006-roles-collections-galaxy.md) — Roles, structure, reuse
- [Ansible/007-tags-strategies-debugging](./Ansible/007-tags-strategies-debugging.md) — Tags, limit, debug, verbosity
- [Ansible/008-vault-secrets](./Ansible/008-vault-secrets.md) — Secrets, vault encrypt/decrypt
- [Ansible/009-dynamic-inventory-and-cloud](./Ansible/009-dynamic-inventory-and-cloud.md) — Dynamic inventory, plugins
- [Ansible/010-best-practices-testing](./Ansible/010-best-practices-testing.md) — Structure, lint, molecule
- [Ansible/011-command-shell-execution](./Ansible/011-command-shell-execution.md) — command, shell, raw, script modules

### Terraform
- [Terraform/001-terraform-overview](./Terraform/001-terraform-overview.md) — What Terraform is, workflow, provider/resource/state
- [Terraform/002-hcl-syntax-resources](./Terraform/002-hcl-syntax-resources.md) — HCL language, resource blocks, count, for_each, lifecycle
- [Terraform/003-providers-data-sources](./Terraform/003-providers-data-sources.md) — Provider config, version constraints, data sources, aliases
- [Terraform/004-variables-outputs-locals](./Terraform/004-variables-outputs-locals.md) — Variables, outputs, locals, validation, type constraints
- [Terraform/005-state-backend](./Terraform/005-state-backend.md) — State file, remote backends, locking, state manipulation
- [Terraform/006-modules-workspaces](./Terraform/006-modules-workspaces.md) — Modules, workspaces, import, dependency management
- [Terraform/007-cli-commands](./Terraform/007-cli-commands.md) — init, plan, apply, destroy, fmt, validate, state commands
- [Terraform/008-expressions-functions](./Terraform/008-expressions-functions.md) — Conditionals, loops, built-in functions, dynamic blocks
- [Terraform/009-best-practices](./Terraform/009-best-practices.md) — Directory structure, naming, CI/CD, tagging, DRY patterns
