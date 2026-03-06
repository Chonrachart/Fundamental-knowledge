provider
required_providers
data source
provider configuration
alias
version constraint

---

# Provider — Required and Version

- **terraform** block: **required_providers** lists provider source and version constraint.
- **Source**: **hashicorp/aws** = registry.terraform.io/hashicorp/aws; **version**: `"~> 5.0"` (>= 5.0, < 6.0).
- **terraform init** downloads providers; lock file (**.terraform.lock.hcl**) pins exact versions for reproducibility.

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

# Provider Configuration

- **provider "aws" { ... }**: Configure provider; **region**, **profile**, **shared_credentials_files**, or **assume_role**.
- Credentials: env vars (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY), shared config, IAM role (EC2/ECS/Lambda), OIDC.
- **alias**: Multiple provider configs (e.g. **provider "aws" { alias = "eu"; region = "eu-west-1" }**); in resource: **provider = aws.eu**.

# Data Sources — Read-Only Lookup

- **data "type" "name"** — query existing infrastructure or lookup (AMI, VPC, subnet); no create/update; can **read** during plan.
- Use **data.aws_ami.ubuntu.id** in resource; data source is evaluated and result cached in state (refreshed on plan/apply unless **-refresh=false**).
- Common: **aws_ami**, **aws_vpc**, **aws_subnets**, **aws_caller_identity**, **aws_region**; **kubernetes_*** for K8s; **http** for API lookup.

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
  instance_type = var.instance_type
}
```

# Data Source vs Resource

- **Resource**: Creates/updates/destroys; has **id** and attributes; state tracks it.
- **Data source**: No create; only **read**; result in state for refresh; used to feed into resources or outputs.
- **Depends on**: Data source can depend on resource (e.g. data "aws_instances" after aws_instance); resource can depend on data (implicit if you reference data.xxx).

# Provider Documentation

- Each provider has **resources** and **data sources** in its docs (registry.terraform.io).
- **Arguments** and **attributes** (arguments = input; attributes = output); use **attributes** in expressions (e.g. **data.aws_vpc.main.cidr_block**).
