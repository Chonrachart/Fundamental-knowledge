# Modules and Workspaces

- Modules are reusable packages of `.tf` files — input via variables, output via outputs; the primary mechanism for DRY infrastructure.
- Workspaces provide multiple state files for the same config — useful for environment separation (dev/staging/prod).
- Every Terraform directory is a "root module"; called modules are "child modules."

# Mental Model

```text
Root module (your project)
  └── main.tf
        │
        ├── module "vpc" {
        │     source = "./modules/vpc"     ← local module
        │     cidr   = "10.0.0.0/16"
        │   }
        │
        └── module "eks" {
              source  = "terraform-aws-modules/eks/aws"  ← registry module
              version = "~> 20.0"
              vpc_id  = module.vpc.vpc_id   ← output from vpc module
            }

Workspace: dev  → state: dev.tfstate
Workspace: prod → state: prod.tfstate
  (same config, different state)
```

# Core Building Blocks

### Module Structure

```text
modules/vpc/
  ├── main.tf        # resources
  ├── variables.tf   # input variables
  ├── outputs.tf     # outputs for parent
  └── README.md      # usage docs
```

### Calling a Module

```hcl
module "vpc" {
  source = "./modules/vpc"

  cidr_block  = "10.0.0.0/16"
  environment = var.env
}

# Use outputs from the module
resource "aws_instance" "web" {
  subnet_id = module.vpc.public_subnet_ids[0]
}
```

### Module Sources

| Source | Example |
|--------|---------|
| Local path | `source = "./modules/vpc"` |
| Terraform Registry | `source = "terraform-aws-modules/vpc/aws"` |
| GitHub | `source = "github.com/org/repo//modules/vpc"` |
| S3 | `source = "s3::https://bucket.s3.amazonaws.com/vpc.zip"` |
| Git | `source = "git::https://example.com/repo.git//modules/vpc?ref=v1.0"` |

### Workspaces

- Multiple state files per backend config; isolate environments.
- `terraform.workspace` value available in config for naming and logic.

```bash
terraform workspace list          # show workspaces (* = current)
terraform workspace new dev       # create workspace
terraform workspace select prod   # switch to workspace
terraform workspace show          # print current workspace
```

```hcl
resource "aws_instance" "web" {
  instance_type = terraform.workspace == "prod" ? "t3.large" : "t3.micro"
  tags = {
    Environment = terraform.workspace
  }
}
```

### Workspaces vs Directory Per Environment

| Approach | Workspaces | Separate dirs |
|----------|-----------|---------------|
| State isolation | ✅ Per workspace | ✅ Per directory |
| Config differences | Limited (same config) | Full (different config per env) |
| Backend config | Shared | Independent |
| Best for | Simple env separation | Complex multi-env with different resources |

### Import and Moved Blocks

```bash
# Import existing resource into Terraform
terraform import aws_instance.web i-0abc123
```

```hcl
# Moved block (Terraform 1.1+) — refactor without destroy/recreate
moved {
  from = aws_instance.web
  to   = module.web.aws_instance.main
}
```

### Dependency Management

- Terraform builds a dependency graph from references; resource A referencing B → B created first.
- `depends_on` for ordering without value reference.
- Module dependencies follow the same pattern: output of one module feeds into another.

Related notes: [001-terraform-overview](./001-terraform-overview.md), [004-variables-outputs-locals](./004-variables-outputs-locals.md), [009-best-practices](./009-best-practices.md)

---

# Troubleshooting Guide

### Module source not found
1. Local module: check relative path from root module.
2. Registry module: check name format `namespace/name/provider` and version exists.
3. Git module: check URL, authentication, and `?ref=` tag/branch.
4. Run `terraform init` after adding or changing module source.

### "Module output not found"
1. Check output is defined in the child module's `outputs.tf`.
2. Check spelling: `module.<name>.<output_name>` — case-sensitive.
3. Run `terraform apply` — some outputs only exist after resources are created.

### Workspace state confusion
1. Check current workspace: `terraform workspace show`.
2. Accidentally modified wrong environment: check state with `terraform state list`.
3. Resources have wrong names/tags: verify `terraform.workspace` is used correctly in config.

# Quick Facts (Revision)

- Every Terraform project is a root module; called modules are child modules.
- Module inputs are variables; module outputs are outputs — explicit interface.
- Registry modules use version constraints: `version = "~> 5.0"`.
- `terraform init` must be re-run after adding or changing module sources.
- Workspaces share the same config but have separate state files.
- `terraform.workspace` returns the current workspace name as a string.
- `moved` blocks let you refactor resource addresses without destroy/recreate.
- Prefer separate directories over workspaces when environments need different resource sets.
