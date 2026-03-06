module
workspace
import
taint
dependency

---

# Module

- Reusable package of .tf files; input via **variable**, output via **output**.
- **module** block: source (path, git, registry), arguments = variables.
- Call: `module "vpc" { source = "./modules/vpc"; ... }`; use `module.vpc.outputs.x`.

```hcl
module "web" {
  source = "./modules/web"
  instance_type = var.instance_type
  env = var.env
}
output "web_ip" {
  value = module.web.instance_public_ip
}
```

# Workspace

- Multiple state files per backend config; **terraform workspace list**, **select**, **new**.
- Use case: same config, different envs (dev, staging, prod) with separate state.
- **terraform.workspace** in config; often used in resource naming or backend key.

```hcl
resource "aws_instance" "web" {
  tags = {
    Env = terraform.workspace
  }
}
```

# Import

- Bring existing resource under Terraform management; **terraform import <addr> <id>**.
- Add **resource** block to config (can be minimal); import fills state; then refine config and plan (no change if correct).

# Taint / Replace

- **terraform taint <addr>**: Mark resource for recreation on next apply (deprecated in favor of replace).
- **terraform apply -replace=<addr>**: Recreate single resource.
- Use when resource is broken or must be recreated (e.g. change immutable attribute).

# Dependency

- Terraform builds dependency graph from references; resource A referencing B → B created first.
- **depends_on** for ordering without value dependency (e.g. IAM role before instance that uses it).
