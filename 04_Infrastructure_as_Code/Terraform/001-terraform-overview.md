# Terraform Overview

- IaC tool that provisions and manages infrastructure declaratively using HCL configuration files.
- Builds a dependency graph of resources, computes a diff against current state, and applies changes via provider APIs.
- Workflow: write `.tf` files → `init` → `plan` → `apply`; state tracks what Terraform manages.

# Mental Model

```text
Developer writes .tf config
        │
        ▼
terraform plan
  → reads state file (what exists)
  → reads config (what should exist)
  → compares: create / update / destroy
        │
        ▼
terraform apply
  → calls provider API (e.g. AWS EC2 CreateInstance)
  → provider returns resource ID + attributes
  → state file updated with new mapping
        │
        ▼
Next run: plan reads state + config again
  → if config unchanged → "No changes"
  → if config changed → shows diff
```

# Core Building Blocks

### Terraform vs Other IaC Tools

| Feature | Terraform | Ansible | CloudFormation |
|---------|-----------|---------|----------------|
| Approach | Declarative | Procedural + Declarative | Declarative |
| State | Explicit state file | No state (idempotent tasks) | Managed by AWS |
| Multi-cloud | Yes (any provider) | Yes (modules) | AWS only |
| Language | HCL | YAML | JSON/YAML |

### Provider

- Plugin for a platform (AWS, GCP, Azure, K8s, etc.); defines available resources and data sources.
- Configured in `provider` block; credentials via env vars, shared config, or IAM roles.

```hcl
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}
provider "aws" {
  region = var.region
}
```

### Resource

- One piece of infrastructure Terraform creates and manages.
- Address: `<type>.<name>` (e.g. `aws_instance.web`).

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0abcdef1234567890"
  instance_type = "t3.micro"
  tags = { Name = "web-server" }
}
```

### State

- `terraform.tfstate` maps config addresses to real resource IDs and attributes.
- Stored locally (default) or in remote backend (S3, GCS, Terraform Cloud).
- Never edit state manually; use `terraform state` commands.

### Plan and Apply

```bash
terraform init          # download providers, init backend
terraform plan          # preview changes (read-only)
terraform apply         # execute changes (prompts for confirmation)
terraform destroy       # remove all managed resources
```

- `plan` is always safe; `apply` modifies real infrastructure.
- `-auto-approve` skips prompt (use in CI only).

Related notes: [002-hcl-syntax-resources](./002-hcl-syntax-resources.md), [005-state-backend](./005-state-backend.md), [007-cli-commands](./007-cli-commands.md)


- Terraform is declarative: describe what, not how.
- `terraform plan` is read-only and safe; always run before `apply`.
- State file is the link between config and real infrastructure.
- Providers are downloaded during `init` and cached in `.terraform/`.
- `.terraform.lock.hcl` pins exact provider versions — commit it to Git.
- `terraform destroy` removes ALL managed resources — use `-target` for selective removal.
- HCL files are typically split: `main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`.
