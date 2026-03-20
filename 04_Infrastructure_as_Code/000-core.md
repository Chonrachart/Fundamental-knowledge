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
- [Ansible/001-ansible-overview](./Ansible/001-ansible-overview.md) — Playbooks, inventory, modules (start here)
- [Ansible/002-roles-vars](./Ansible/002-roles-vars.md) — Roles, variables, templates
- [Ansible/003-modules-handlers](./Ansible/003-modules-handlers.md) — Common modules, handlers
- [Ansible/004-inventory-dynamic-tags](./Ansible/004-inventory-dynamic-tags.md) — Inventory, dynamic, group_vars, tags

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
