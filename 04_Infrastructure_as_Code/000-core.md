overview of

    IaC
    declarative
    state
    idempotent

---

# Infrastructure as Code (IaC)

- Manage infrastructure (servers, networks, cloud resources) via code and config.
- Versioned, reviewable, repeatable; reduces manual drift and errors.

# Declarative

- Describe desired state (e.g. "3 instances, this AMI"); tool reconciles to that state.
- Contrast with imperative scripts that run fixed commands.

# State

- Tool tracks current state (e.g. Terraform state file); compares with desired state and applies diff.
- State must be stored safely (remote backend, locking).

# Drift

- **Drift**: Real infrastructure diverges from code (manual change, provider bug).
- Terraform: plan shows drift; re-apply to correct. Ansible: re-run playbook to converge.
- Prevent: restrict manual changes; run IaC regularly (CI or scheduled).

# Topic Map (basic → advanced)

- [Ansible/001-ansible-overview](./Ansible/001-ansible-overview.md) — Playbooks, inventory, modules (start here)
- [Ansible/002-roles-vars](./Ansible/002-roles-vars.md) — Roles, variables, templates
- [Ansible/003-modules-handlers](./Ansible/003-modules-handlers.md) — Common modules, handlers
- [Ansible/004-inventory-dynamic-tags](./Ansible/004-inventory-dynamic-tags.md) — Inventory, dynamic, group_vars, tags
- [Terraform/001-terraform-overview](./Terraform/001-terraform-overview.md) — Provider, resource, plan/apply (start here)
- [Terraform/002-state-variables](./Terraform/002-state-variables.md) — State, variables, outputs, data sources
- [Terraform/003-modules-workspace](./Terraform/003-modules-workspace.md) — Modules, workspaces, import
- [Terraform/004-providers-data-sources](./Terraform/004-providers-data-sources.md) — Providers, data sources, version
- [Terraform/005-hcl-syntax-resources](./Terraform/005-hcl-syntax-resources.md) — HCL, count, for_each, lifecycle
- [Terraform/006-cli-commands-troubleshooting](./Terraform/006-cli-commands-troubleshooting.md) — CLI, state, refresh, troubleshooting
