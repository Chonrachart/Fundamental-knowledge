# Terraform

- Infrastructure as Code tool by HashiCorp; declarative HCL config defines desired infrastructure state.
- Provider-based architecture: plugins for AWS, GCP, Azure, Kubernetes, and hundreds of other platforms.
- Workflow: write `.tf` files, `init`, `plan`, `apply`; state tracks what Terraform manages.
- For detailed workflow, architecture, and examples: see [001-terraform-overview](./001-terraform-overview.md).

# Architecture

```text
.tf files (HCL config)
        │
  terraform init  → downloads providers, configures backend
        │
  terraform plan  → reads state + config, computes diff
        │
  terraform apply → executes changes via provider APIs, updates state
        │
terraform.tfstate → maps config addresses to real resource IDs
```

# Core Building Blocks

### Providers

- Plugins that interface with cloud/platform APIs (AWS, GCP, Azure, K8s, etc.).
- Defined in `terraform { required_providers {} }` with version constraints.

Related notes: [003-providers-data-sources](./003-providers-data-sources.md)

### Resources and Data Sources

- **Resource**: infrastructure Terraform creates and manages (e.g. `aws_instance`).
- **Data source**: read-only lookup of existing infrastructure (e.g. `data.aws_ami.ubuntu`).

Related notes: [002-hcl-syntax-resources](./002-hcl-syntax-resources.md), [003-providers-data-sources](./003-providers-data-sources.md)

### State

- Maps config to real infrastructure; stored in a backend (local file or remote).
- Remote backends (S3, GCS, Terraform Cloud) enable team collaboration and state locking.

Related notes: [005-state-backend](./005-state-backend.md)

### Variables and Outputs

- Variables parameterize config; outputs expose values for other modules or scripts.
- Locals are computed values within a module.

Related notes: [004-variables-outputs-locals](./004-variables-outputs-locals.md)

### Modules

- Reusable packages of `.tf` files; input via variables, output via outputs.
- Source: local path, Git URL, or Terraform Registry.

Related notes: [006-modules-workspaces](./006-modules-workspaces.md)

### CLI Workflow

- Core commands: `init`, `plan`, `apply`, `destroy`, `fmt`, `validate`.
- State manipulation: `state list`, `state show`, `state mv`, `state rm`, `import`.

Related notes: [007-cli-commands](./007-cli-commands.md)


- Terraform is declarative: describe desired state, not steps to get there.
- `terraform plan` is safe and read-only; always review before `apply`.
- State file is the source of truth — never edit manually.
- Provider versions pinned in `.terraform.lock.hcl` for reproducibility.
- `terraform destroy` removes all managed resources — use with caution.
---

# Troubleshooting Guide

### terraform init fails — provider not found
1. Check `required_providers` block: source must be `hashicorp/<name>` or full registry path.
2. Check network: Terraform downloads from `registry.terraform.io`.
3. Try `terraform init -upgrade` to refresh provider cache.

### terraform plan shows unexpected changes
1. Check for drift: someone changed infra outside Terraform.
2. Run `terraform apply -refresh-only` to update state from real infra.
3. Check `ignore_changes` in lifecycle if external process modifies attributes.

### State lock — "Error acquiring the state lock"
1. Another `terraform apply` may be running; wait for it to finish.
2. If stuck: `terraform force-unlock <LOCK_ID>` — only if certain no other process is running.

# Topic Map (basic to advanced)

- [001-terraform-overview](./001-terraform-overview.md) — What Terraform is, workflow, provider/resource/state concepts
- [002-hcl-syntax-resources](./002-hcl-syntax-resources.md) — HCL language, resource blocks, count, for_each, lifecycle
- [003-providers-data-sources](./003-providers-data-sources.md) — Provider config, version constraints, data sources, aliases
- [004-variables-outputs-locals](./004-variables-outputs-locals.md) — Variables, outputs, locals, validation, type constraints
- [005-state-backend](./005-state-backend.md) — State file, remote backends, locking, state manipulation
- [006-modules-workspaces](./006-modules-workspaces.md) — Modules, workspaces, import, dependency management
- [007-cli-commands](./007-cli-commands.md) — init, plan, apply, destroy, fmt, validate, state commands
- [008-expressions-functions](./008-expressions-functions.md) — Conditionals, loops, built-in functions, dynamic blocks
- [009-best-practices](./009-best-practices.md) — Directory structure, naming, CI/CD integration, tagging, DRY patterns
