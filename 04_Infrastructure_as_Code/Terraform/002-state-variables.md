state
backend
variable
output
data source

---

# State

- **terraform.tfstate**: Maps config addresses to real resource IDs and attributes.
- **Sensitive**: State may contain secrets; restrict access; use remote backend with encryption.
- **Locking**: Backend (e.g. S3 + DynamoDB) prevents concurrent apply; avoid corruption.
- **terraform state list**, **terraform state show <addr>**: Inspect state.

# Backend

- Where state is stored; **local** (default) or **remote** (s3, gcs, terraform cloud).
- Backend config: in block or **-backend-config**; often different per env.

```hcl
terraform {
  backend "s3" {
    bucket = "my-tfstate"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}
```

# Variable

- **variable** block: type, default, description; optional validation.
- Set via **-var**, **-var-file**, **TF_VAR_<name>**, or prompt (if no default).
- **var.name** in config.

```hcl
variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type"
}
```

# Output

- Expose values after apply; **terraform output**; other modules or scripts can consume.
- **sensitive = true** to hide in CLI.

```hcl
output "instance_id" {
  value       = aws_instance.web.id
  description = "EC2 instance ID"
}
```

# Data Source

- Read existing infrastructure or lookup (e.g. AMI, VPC); no create/update; **data "type" "name"**.
- Use **data.aws_ami.ubuntu.id** etc. in resources.

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["ubuntu/images/*22.04*"]
  }
}
```
