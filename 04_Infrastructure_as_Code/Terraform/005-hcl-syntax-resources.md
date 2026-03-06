HCL
syntax
block
argument
attribute
resource
count
for_each
lifecycle
depends_on

---

# HCL — HashiCorp Configuration Language

- **Blocks**: **type "label" "label" { ... }**; e.g. **resource "aws_instance" "web" { }**.
- **Arguments** inside block: **key = value**; value can be string, number, bool, list, map, or expression.
- **Multi-line string**: **<<EOF ... EOF** or **<<-EOF** (strip indent); **"line1\nline2"** for newlines.
- **Comments**: **#** or **//** line; **/* */** block.

# Resource Block — Full Shape

- **resource "provider_type" "local_name" { }**; **local_name** is for reference in same module (e.g. **aws_instance.web.id**).
- **Arguments**: required and optional; see provider docs; **computed** attributes (e.g. **id**) come from provider after create.
- **Meta-arguments**: **count**, **for_each**, **provider**, **depends_on**, **lifecycle**, **provisioner** (legacy).

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  tags = {
    Name = "web-${terraform.workspace}"
  }
}
```

# count — Multiple Instances

- **count** = number; resource becomes **list**; access: **aws_instance.web[0].id**, **aws_instance.web[count.index]**.
- **count** can be from variable: **count = var.enable ? 1 : 0** to conditionally create.
- **Problem**: Adding/removing item in middle changes indices; prefer **for_each** for stability when possible.

# for_each — Map or Set of Instances

- **for_each** = map or set of strings; each key (or set element) gets one instance.
- **each.key**, **each.value** in block; **aws_instance.web["a"].id** (map) or **aws_instance.web["a"]** (set).
- **for_each = toset(["a","b"])** or **for_each = var.subnets** (map); changing map doesn't reorder like count.

```hcl
resource "aws_instance" "web" {
  for_each = toset(["web1", "web2"])
  ami      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  tags = {
    Name = each.key
  }
}
```

# lifecycle Block

- **create_before_destroy = true**: Create replacement before destroying old; good for resources that can't be updated in place.
- **prevent_destroy = true**: Block **terraform destroy** (safety).
- **ignore_changes = [tags]**: Don't update state for these attributes; use when external process changes them.
- **replace_triggered_by**: Force replace when another resource changes (e.g. replace instance when AMI id changes).

```hcl
lifecycle {
  ignore_changes = [tags["ManagedBy"]]
  create_before_destroy = true
}
```

# depends_on

- **depends_on = [aws_iam_role_policy.x]** — Terraform waits for dependency before creating this resource; use when there's no **value** dependency (e.g. IAM role for instance profile used by instance).
- Implicit dependency: reference **aws_instance.x.id** creates dependency; **depends_on** for ordering only.
