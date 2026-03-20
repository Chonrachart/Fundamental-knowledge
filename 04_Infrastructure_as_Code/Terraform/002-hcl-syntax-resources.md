# HCL Syntax and Resources

- HCL (HashiCorp Configuration Language) is a declarative language using blocks, arguments, and expressions.
- Resources are the primary building block — each resource block declares one piece of infrastructure.
- Meta-arguments (`count`, `for_each`, `lifecycle`, `depends_on`) control how resources are created and managed.

# Core Building Blocks

### HCL Basics

- **Block**: `type "label" "label" { ... }` — containers for config (resource, variable, output, etc.).
- **Argument**: `key = value` inside a block — sets a parameter.
- **Expression**: Right-hand side of `=` — can be string, number, bool, list, map, or reference.
- **Comments**: `#` or `//` for line; `/* */` for block.
- **Multi-line string**: `<<EOF ... EOF` or `<<-EOF` (strips leading indent).

```hcl
# This is a comment
resource "aws_instance" "web" {      # block with two labels
  ami           = "ami-123"          # argument
  instance_type = var.instance_type  # expression referencing variable
  tags = {                           # map argument
    Name = "web-${terraform.workspace}"
  }
}
```

### Resource Block

- `resource "provider_type" "local_name" { }` — declares infrastructure.
- **Required arguments**: defined by provider (e.g. `ami`, `instance_type` for `aws_instance`).
- **Computed attributes**: returned by provider after creation (e.g. `id`, `arn`, `public_ip`).
- **Reference**: `aws_instance.web.id` — creates implicit dependency.

### count — Multiple Instances

- `count = N` creates N instances; access via `aws_instance.web[0]`, `aws_instance.web[count.index]`.
- Conditional creation: `count = var.enable ? 1 : 0`.
- **Caveat**: Adding/removing items in the middle shifts indices — prefer `for_each` for stable keys.

```hcl
resource "aws_instance" "web" {
  count         = 3
  ami           = "ami-123"
  instance_type = "t3.micro"
  tags = { Name = "web-${count.index}" }
}
```

### for_each — Map or Set of Instances

- `for_each = map_or_set` creates one instance per key; access via `each.key`, `each.value`.
- Stable keys: adding/removing doesn't affect other instances (unlike `count`).
- Must be map or set of strings; use `toset()` to convert a list.

```hcl
resource "aws_instance" "web" {
  for_each      = toset(["web1", "web2"])
  ami           = "ami-123"
  instance_type = "t3.micro"
  tags = { Name = each.key }
}
# Reference: aws_instance.web["web1"].id
```

### lifecycle Block

- `create_before_destroy = true` — create replacement before destroying old (avoids downtime).
- `prevent_destroy = true` — block `terraform destroy` on this resource (safety).
- `ignore_changes = [attr]` — don't track changes to these attributes (external process manages them).
- `replace_triggered_by = [ref]` — force replace when referenced value changes.

```hcl
resource "aws_instance" "web" {
  # ...
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [tags["ManagedBy"]]
  }
}
```

### depends_on

- Explicit ordering without value dependency: `depends_on = [aws_iam_role_policy.x]`.
- Implicit dependency: referencing `aws_iam_role.x.arn` automatically creates dependency.
- Use `depends_on` only when Terraform can't infer the dependency from references.

Related notes: [001-terraform-overview](./001-terraform-overview.md), [008-expressions-functions](./008-expressions-functions.md)

---

# Troubleshooting Guide

### "Error: Invalid for_each argument"
1. `for_each` must be a map or set of strings — not a list.
2. Convert list: `for_each = toset(var.my_list)`.
3. Computed values: `for_each` value must be known at plan time — can't depend on resource outputs.

### count causes unexpected destroy/recreate
1. Adding/removing items shifts indices: item at `[2]` becomes `[1]`.
2. Solution: switch to `for_each` with stable string keys.
3. After switching: use `terraform state mv` to migrate state entries.

### "Cycle detected" in dependency graph
1. Resource A references B and B references A — circular dependency.
2. Break the cycle: remove one reference and use `depends_on` instead.
3. Or split into separate `terraform apply` steps.

# Quick Facts (Revision)

- HCL blocks: `resource`, `data`, `variable`, `output`, `locals`, `module`, `terraform`, `provider`.
- `count` creates a list of instances; `for_each` creates a map — `for_each` is more stable.
- `lifecycle.prevent_destroy` protects critical resources like databases from accidental deletion.
- `ignore_changes` is useful when external tools (autoscaling, CI) modify attributes.
- Implicit dependencies (from references) are preferred over explicit `depends_on`.
- Resource addresses: `type.name` (single), `type.name[0]` (count), `type.name["key"]` (for_each).
- `create_before_destroy` is essential for resources that must have zero-downtime replacement.
