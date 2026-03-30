# Variables, Outputs, and Locals

- Variables parameterize Terraform config; set via CLI flags, files, env vars, or interactive prompt.
- Outputs expose values after apply — consumed by other modules, scripts, or CI pipelines.
- Locals are computed values within a module for DRY and readability.

# Mental Model

```text
Input:                              Inside module:              Output:
variable "env" { }                  locals {                    output "instance_id" {
variable "instance_type" { }          name = "${var.env}-web"     value = aws_instance.web.id
       │                            }                           }
       ▼                                   │                          │
  var.env                            local.name                       ▼
  var.instance_type                                             terraform output
                                                                module.web.instance_id
```

# Core Building Blocks

### Variables

- Defined in `variable` block with `type`, `default`, `description`, `validation`, `sensitive`.
- Referenced as `var.name` in config.
- Types: `string`, `number`, `bool`, `list(type)`, `map(type)`, `object({...})`, `tuple([...])`.

```hcl
variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type"
}

variable "allowed_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/8"]
}

variable "tags" {
  type = map(string)
  default = {
    Environment = "dev"
  }
}
```

### Setting Variables

| Method | Example | Priority |
|--------|---------|----------|
| CLI flag | `-var="env=prod"` | Highest |
| `.auto.tfvars` | Auto-loaded from `*.auto.tfvars` | High |
| `-var-file` | `-var-file="prod.tfvars"` | High |
| `terraform.tfvars` | Auto-loaded if present | Medium |
| `TF_VAR_<name>` | `export TF_VAR_env=prod` | Low |
| Default | `default = "dev"` in variable block | Lowest |
| Interactive | Prompt if no default and not set | Fallback |

### Variable Validation

```hcl
variable "env" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "env must be dev, staging, or prod"
  }
}
```

### Sensitive Variables

- `sensitive = true` — masks value in plan/apply output and logs.
- Still visible in state file — protect state file access.

### Outputs

- Expose values after apply; visible with `terraform output`.
- Used by parent modules: `module.web.instance_id`.
- `sensitive = true` hides output from CLI display.

```hcl
output "instance_id" {
  value       = aws_instance.web.id
  description = "EC2 instance ID"
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}
```

### Locals

- Computed values for reuse within a module; reduces repetition.
- Referenced as `local.name` (singular, not `locals`).

```hcl
locals {
  name_prefix = "${var.project}-${var.env}"
  common_tags = {
    Project     = var.project
    Environment = var.env
    ManagedBy   = "terraform"
  }
}

resource "aws_instance" "web" {
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-web" })
}
```

Related notes: [001-terraform-overview](./001-terraform-overview.md), [006-modules-workspaces](./006-modules-workspaces.md), [008-expressions-functions](./008-expressions-functions.md)


- Variables use `var.name`; locals use `local.name`; outputs use `module.<name>.<output>`.
- `terraform.tfvars` and `*.auto.tfvars` are auto-loaded; other files need `-var-file`.
- Variable types: `string`, `number`, `bool`, `list()`, `map()`, `object({})`, `tuple([])`.
- `sensitive = true` hides values in plan/apply output but NOT in state file.
- Locals are great for computed values like name prefixes and common tag maps.
- Variable validation with `condition` catches invalid input early at plan time.
- `TF_VAR_<name>` env vars are useful in CI pipelines.
