Terraform
provider
resource
state
plan
apply

---

# Terraform

- IaC tool; declarative config (HCL); supports many providers (AWS, GCP, Azure, etc.).
- Builds a graph of resources; creates/updates/destroys to match desired state.

# Provider

- Plugin for a platform (e.g. AWS, Kubernetes); defines resources and data sources.
- Configure in provider block; often with env vars or variables for credentials.

```hcl
terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}
provider "aws" {
  region = var.region
}
```

# Resource

- One piece of infrastructure (e.g. instance, VPC, S3 bucket).
- Resource type and name form address: `aws_instance.web`.

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
}
```

# State

- Terraform state tracks mapping from config to real resource IDs.
- Stored in backend (local file or remote: S3, Terraform Cloud); use locking to avoid concurrent changes.

# Plan and Apply

- `terraform plan`: show what would change (no changes applied).
- `terraform apply`: apply changes (prompt or `-auto-approve`).
- `terraform destroy`: tear down managed resources.

```bash
terraform init
terraform plan
terraform apply
```
