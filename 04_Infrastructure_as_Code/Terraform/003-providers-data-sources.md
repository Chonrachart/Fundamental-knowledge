# Providers and Data Sources

- Providers are plugins that connect Terraform to platforms (AWS, GCP, Azure, K8s); each provider defines resources and data sources.
- Version constraints and lock files ensure reproducible builds across team members and CI.
- Data sources query existing infrastructure without creating anything — read-only lookups.

# Core Building Blocks

### Required Providers and Versioning

- Declared in `terraform { required_providers {} }` with source and version constraint.
- `terraform init` downloads providers; `.terraform.lock.hcl` pins exact versions.
- Version constraints: `~> 5.0` (>= 5.0, < 6.0), `>= 5.0, < 5.5`, `= 5.0.0` (exact).

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}
```

### Provider Configuration

- `provider "name" { }` — configure credentials, region, endpoint.
- Credentials: env vars (`AWS_ACCESS_KEY_ID`), shared config (`~/.aws/config`), IAM role, OIDC.
- **alias**: Multiple configurations of the same provider (e.g. multi-region).

```hcl
provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "eu"
  region = "eu-west-1"
}

resource "aws_instance" "eu_web" {
  provider      = aws.eu
  ami           = "ami-eu-123"
  instance_type = "t3.micro"
}
```

### Data Sources

- `data "type" "name" { }` — read-only query of existing infrastructure.
- Returns attributes you can reference: `data.aws_ami.ubuntu.id`.
- Evaluated during plan; result cached in state; refreshed on next plan/apply.

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
}
```

### Common Data Sources

| Data Source | Use Case |
|------------|----------|
| `aws_ami` | Look up latest AMI by filters |
| `aws_vpc` / `aws_subnets` | Reference existing network |
| `aws_caller_identity` | Get current account ID |
| `aws_region` | Get current region |
| `aws_availability_zones` | List AZs in region |
| `terraform_remote_state` | Read outputs from another state |

### Data Source vs Resource

| | Resource | Data Source |
|-|----------|-------------|
| Creates infra | Yes | No |
| In state | Yes (full lifecycle) | Yes (cached result) |
| Prefix | `resource "type" "name"` | `data "type" "name"` |
| Reference | `type.name.attr` | `data.type.name.attr` |

### Provider Documentation

- Each provider has docs at `registry.terraform.io/providers/hashicorp/<name>/latest/docs`.
- Lists all resources and data sources with arguments (inputs) and attributes (outputs).

Related notes: [001-terraform-overview](./001-terraform-overview.md), [002-hcl-syntax-resources](./002-hcl-syntax-resources.md)

---

# Troubleshooting Guide

### "Failed to query available provider packages"
1. Check network connectivity to `registry.terraform.io`.
2. Check `required_providers` source spelling (e.g. `hashicorp/aws` not `aws`).
3. Behind proxy: set `HTTPS_PROXY` env var.

### Provider version conflict
1. Check `.terraform.lock.hcl` for pinned version vs constraint in config.
2. Run `terraform init -upgrade` to update within constraints.
3. If modules require different versions: not supported — align version constraints.

### Data source returns no results
1. Check filters: `filter` values must match exactly.
2. Check `owners` for AMI lookups — `["amazon"]`, `["self"]`, or specific account ID.
3. Check region: data source queries the provider's configured region.

# Quick Facts (Revision)

- Provider source format: `registry/namespace/type` (e.g. `hashicorp/aws`).
- `~> 5.0` means >= 5.0.0 and < 6.0.0 (pessimistic constraint).
- `.terraform.lock.hcl` should be committed to Git for reproducibility.
- `terraform init -upgrade` updates providers to latest within constraints.
- Provider `alias` enables multi-region or multi-account patterns.
- Data sources are read-only; they never create, update, or destroy infrastructure.
- `terraform_remote_state` data source reads outputs from another Terraform project's state.
