# Expressions and Functions

- Terraform expressions compute values dynamically: string interpolation, conditionals, loops, and references.
- Built-in functions transform data: `merge`, `lookup`, `cidrsubnet`, `join`, `flatten`, `file`, etc.
- Dynamic blocks generate repeated nested blocks from collections — replacing repetitive config.

# Core Building Blocks

### String Interpolation and Templates

```hcl
# Interpolation
name = "web-${var.env}-${count.index}"

# Directive (conditionals/loops in strings)
user_data = <<-EOF
  #!/bin/bash
  %{ if var.env == "prod" }
  echo "Production mode"
  %{ endif }
EOF
```

### Conditional Expression

```hcl
# condition ? true_val : false_val
instance_type = var.env == "prod" ? "t3.large" : "t3.micro"

# Conditional resource creation with count
count = var.enable_monitoring ? 1 : 0
```

### for Expressions

```hcl
# Transform list
upper_names = [for name in var.names : upper(name)]

# Transform map
instance_ids = { for k, v in aws_instance.web : k => v.id }

# Filter
prod_instances = [for i in aws_instance.all : i.id if i.tags["Env"] == "prod"]
```

### Splat Expression

```hcl
# Shorthand for [for x in list : x.attr]
instance_ids = aws_instance.web[*].id            # count
all_ips      = [for k, v in aws_instance.web : v.public_ip]  # for_each
```

### Dynamic Blocks

- Generate repeated nested blocks from a collection.

```hcl
resource "aws_security_group" "web" {
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidrs
    }
  }
}
```

### Common Functions — String

| Function | Example | Result |
|----------|---------|--------|
| `upper(s)` | `upper("hello")` | `"HELLO"` |
| `lower(s)` | `lower("HELLO")` | `"hello"` |
| `format(fmt, ...)` | `format("web-%02d", 1)` | `"web-01"` |
| `join(sep, list)` | `join(",", ["a","b"])` | `"a,b"` |
| `split(sep, s)` | `split(",", "a,b")` | `["a","b"]` |
| `replace(s, old, new)` | `replace("a-b", "-", "_")` | `"a_b"` |
| `trimspace(s)` | `trimspace(" hi ")` | `"hi"` |

### Common Functions — Collection

| Function | Example | Result |
|----------|---------|--------|
| `length(col)` | `length(["a","b"])` | `2` |
| `merge(m1, m2)` | `merge({a=1}, {b=2})` | `{a=1, b=2}` |
| `lookup(map, key, default)` | `lookup({a=1}, "b", 0)` | `0` |
| `flatten(list_of_lists)` | `flatten([[1,2],[3]])` | `[1,2,3]` |
| `distinct(list)` | `distinct([1,1,2])` | `[1,2]` |
| `toset(list)` | `toset(["a","b","a"])` | `set("a","b")` |
| `keys(map)` / `values(map)` | `keys({a=1,b=2})` | `["a","b"]` |
| `zipmap(keys, values)` | `zipmap(["a","b"],[1,2])` | `{a=1,b=2}` |

### Common Functions — Networking and Encoding

| Function | Use Case |
|----------|----------|
| `cidrsubnet(prefix, bits, num)` | Calculate subnet CIDRs from VPC CIDR |
| `cidrhost(prefix, num)` | Calculate host IP within subnet |
| `file(path)` | Read file content as string |
| `filebase64(path)` | Read file as base64 (user data) |
| `base64encode(s)` / `base64decode(s)` | Encode/decode base64 |
| `jsonencode(val)` / `jsondecode(s)` | JSON conversion |
| `yamlencode(val)` / `yamldecode(s)` | YAML conversion |
| `templatefile(path, vars)` | Render template file with variables |

### cidrsubnet Example

```hcl
# VPC: 10.0.0.0/16
# Create /24 subnets: 10.0.0.0/24, 10.0.1.0/24, 10.0.2.0/24
variable "vpc_cidr" { default = "10.0.0.0/16" }

resource "aws_subnet" "private" {
  count      = 3
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index)
  # cidrsubnet("10.0.0.0/16", 8, 0) = "10.0.0.0/24"
  # cidrsubnet("10.0.0.0/16", 8, 1) = "10.0.1.0/24"
}
```

Related notes: [002-hcl-syntax-resources](./002-hcl-syntax-resources.md), [004-variables-outputs-locals](./004-variables-outputs-locals.md)

---

# Troubleshooting Guide

### "Invalid value for for_each — must be known at plan time"
1. `for_each` cannot use values computed during apply (e.g. resource IDs).
2. Solution: use a variable or data source that's known at plan time.
3. Alternative: use `count` with a known number if `for_each` can't work.

### cidrsubnet produces unexpected range
1. Second argument (`newbits`) is bits to ADD, not total prefix length.
2. `cidrsubnet("10.0.0.0/16", 8, 0)` → `/24` (16 + 8 = 24).
3. Use `terraform console` to test: `cidrsubnet("10.0.0.0/16", 8, 0)`.

### Dynamic block not generating expected blocks
1. Check `for_each` value — must be a collection (list, map, set).
2. Inside `content {}`, use `<block_name>.value` (not `each.value`).
3. Empty collection produces no blocks — verify input is not empty.

# Quick Facts (Revision)

- `condition ? true : false` is the only conditional expression — no if/else blocks.
- `for` expressions can transform, filter, and reshape lists and maps.
- Splat `[*].attr` is shorthand for `[for x in list : x.attr]`.
- `merge()` combines maps; later keys override earlier ones.
- `cidrsubnet()` is essential for VPC/subnet design — test in `terraform console`.
- `dynamic` blocks replace repeated nested blocks but should be used sparingly for readability.
- `templatefile()` renders external template files with variable substitution.
- `terraform console` is an interactive REPL for testing expressions and functions.
