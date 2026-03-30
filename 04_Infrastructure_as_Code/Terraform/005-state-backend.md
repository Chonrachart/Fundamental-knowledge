# State and Backend

- Terraform state (`terraform.tfstate`) maps config addresses to real resource IDs — it's the source of truth for what Terraform manages.
- Remote backends (S3, GCS, Terraform Cloud) enable team collaboration with state locking and encryption.
- State manipulation commands (`state mv`, `state rm`, `import`) manage the mapping without touching real infrastructure.

# Mental Model

```text
terraform apply
        │
        ▼
Provider creates resource → returns ID + attributes
        │
        ▼
State file records:
  aws_instance.web → i-0abc123 (id)
                   → t3.micro (instance_type)
                   → 10.0.1.5 (private_ip)
        │
        ▼
Next plan:
  config says aws_instance.web should exist
  state says it's i-0abc123
  API says i-0abc123 exists with these attributes
  → compare all three → compute diff
```

# Core Building Blocks

### State File

- JSON file mapping config to real infrastructure.
- Contains resource IDs, attributes, metadata, and dependencies.
- **Sensitive data**: passwords, keys may appear in state — treat state as secret.
- **Never edit manually** — use `terraform state` commands.

### Remote Backend

- Default: local `terraform.tfstate` file — not suitable for teams.
- Remote backends: S3, GCS, Azure Blob, Terraform Cloud, Consul.
- **Locking**: Prevents concurrent `apply` (S3 uses DynamoDB for locks).
- **Encryption**: Enable server-side encryption on the storage bucket.

```hcl
terraform {
  backend "s3" {
    bucket         = "my-tfstate"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### Backend Migration

```bash
# Switch from local to S3 backend
# 1. Add backend config to terraform block
# 2. Run:
terraform init -migrate-state    # copies state to new backend

# Reconfigure without migrating:
terraform init -reconfigure
```

### State Commands

```bash
terraform state list                    # list all resources in state
terraform state show aws_instance.web   # show one resource's state
terraform state mv old.name new.name    # rename in state (no infra change)
terraform state rm aws_instance.web     # remove from state (doesn't destroy)
terraform state pull                    # output state as JSON
```

### terraform import

- Bring existing infrastructure under Terraform management.
- Write the resource block first, then import.

```bash
# 1. Add resource block to config
# resource "aws_instance" "web" { ... }

# 2. Import
terraform import aws_instance.web i-0abc123

# 3. Run plan — adjust config until "No changes"
terraform plan
```

### Import Block (Terraform 1.5+)

```hcl
import {
  to = aws_instance.web
  id = "i-0abc123"
}
# terraform plan -generate-config-out=generated.tf
```

### Refresh

- `terraform apply -refresh-only` — update state from real infrastructure without applying config changes.
- Use when someone changed infra manually (drift detection).

Related notes: [001-terraform-overview](./001-terraform-overview.md), [007-cli-commands](./007-cli-commands.md)


- State is Terraform's mapping of config to real infrastructure — source of truth.
- Remote backend with locking is mandatory for team use (S3 + DynamoDB is the AWS standard).
- State may contain secrets (passwords, keys) — encrypt and restrict access.
- `state rm` removes from state without destroying the real resource.
- `state mv` renames a resource in state — use when refactoring config.
- `terraform import` brings existing infra under management — requires a matching config block.
- Enable S3 bucket versioning for state file recovery.
- `-refresh-only` apply detects and records drift without changing infrastructure.
