# Best Practices and Patterns

- Standard directory structure and naming conventions make Terraform projects navigable and maintainable.
- CI/CD integration (plan on PR, apply on merge) prevents manual errors and enforces review.
- Tagging strategy and module reuse are critical for production infrastructure at scale.

# Core Building Blocks

### Standard File Layout

```text
project/
  ├── main.tf            # resources and module calls
  ├── variables.tf       # all variable definitions
  ├── outputs.tf         # all output definitions
  ├── providers.tf       # provider config and terraform block
  ├── locals.tf          # local values (optional)
  ├── data.tf            # data sources (optional)
  ├── terraform.tfvars   # default variable values (not committed for secrets)
  ├── prod.tfvars        # environment-specific values
  ├── dev.tfvars         # environment-specific values
  └── modules/
        └── vpc/
              ├── main.tf
              ├── variables.tf
              └── outputs.tf
```

### Naming Conventions

- Resources: `<provider>_<type>` with descriptive local name: `aws_instance.web_server`.
- Variables: snake_case, descriptive: `instance_type`, `vpc_cidr`, `enable_monitoring`.
- Outputs: match what they expose: `instance_id`, `public_ip`, `vpc_id`.
- Tags: consistent across all resources; automate with `locals` and `merge()`.

### Tagging Strategy

```hcl
locals {
  common_tags = {
    Project     = var.project
    Environment = var.env
    ManagedBy   = "terraform"
    Owner       = var.team
  }
}

resource "aws_instance" "web" {
  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.env}-web"
    Role = "webserver"
  })
}
```

### CI/CD Integration

```text
PR opened → terraform plan → post plan output as PR comment
PR merged → terraform apply -auto-approve → deploy
```

- **Plan on PR**: Reviewers see what changes before merge.
- **Apply on merge**: Automated, auditable deployment.
- **State locking**: Remote backend prevents concurrent applies.
- Tools: GitHub Actions, GitLab CI, Atlantis, Terraform Cloud.

```yaml
# GitHub Actions example
jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: hashicorp/setup-terraform@v3
    - run: terraform init
    - run: terraform plan -no-color
      id: plan
```

### DRY Patterns

- **Modules for reuse**: Common patterns (VPC, EKS, RDS) as modules.
- **Locals for computed values**: Name prefixes, tag maps, CIDR calculations.
- **Variables for differences**: Instance types, counts, regions per environment.
- **Don't over-abstract**: If a module is used once, inline it.

### Environment Management

| Pattern | How | When |
|---------|-----|------|
| Workspaces | Same config, different state | Simple env differences (size, count) |
| Directory per env | Separate dirs, shared modules | Complex differences between envs |
| Terragrunt | DRY wrapper around Terraform | Many environments, large teams |
| Variable files | `-var-file=prod.tfvars` | Different values, same resources |

### Security Best Practices

- **State**: Encrypt at rest, restrict access, enable versioning.
- **Secrets**: Use vault, SSM Parameter Store, or environment variables — not `.tfvars` in Git.
- **OIDC**: Use OIDC for CI/CD auth instead of long-lived access keys.
- **Least privilege**: IAM roles for Terraform with minimum needed permissions.
- **Review plans**: Never `apply -auto-approve` without automated plan review.

### Code Quality

```bash
# Pre-commit checks
terraform fmt -check -recursive     # formatting
terraform validate                  # syntax
tflint                              # linting (external tool)
tfsec / checkov                     # security scanning
```

Related notes: [001-terraform-overview](./001-terraform-overview.md), [004-variables-outputs-locals](./004-variables-outputs-locals.md), [006-modules-workspaces](./006-modules-workspaces.md)


- Split config into `main.tf`, `variables.tf`, `outputs.tf`, `providers.tf` — standard convention.
- Always tag resources with Project, Environment, ManagedBy, Owner at minimum.
- Plan on PR + apply on merge is the standard CI/CD workflow.
- Never commit secrets to `.tfvars` files — use env vars, vault, or SSM.
- `tflint` catches provider-specific errors that `validate` misses.
- `tfsec` and `checkov` scan for security misconfigurations.
- Use `locals` with `merge()` for DRY tagging across all resources.
- Module versioning prevents breaking changes from propagating silently.
---

# Troubleshooting Guide

### Inconsistent tagging across resources
1. Use `locals` block with `common_tags` map.
2. Apply to all resources with `merge(local.common_tags, {...})`.
3. Lint with `tflint` rules to enforce required tags.

### CI pipeline apply fails — state lock
1. Ensure only one pipeline runs `apply` at a time.
2. Use concurrency groups in GitHub Actions or pipeline locks.
3. Set up DynamoDB table for S3 backend locking.

### Module changes break consumers
1. Use semantic versioning for modules: `version = "~> 2.0"`.
2. Don't remove outputs or variables without major version bump.
3. Use `moved` blocks for resource renames instead of destroy/recreate.
