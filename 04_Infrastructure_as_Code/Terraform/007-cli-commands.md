# CLI Commands

- Terraform CLI follows a workflow: `init` → `plan` → `apply` → (iterate) → `destroy`.
- State commands (`state list`, `state mv`, `state rm`) manage the mapping without touching infrastructure.
- `fmt` and `validate` enforce code quality; `import` brings existing resources under management.

# Core Building Blocks

### terraform init

```bash
terraform init              # download providers, modules, init backend
terraform init -upgrade     # upgrade providers/modules to latest within constraints
terraform init -reconfigure # reconfigure backend without migrating state
terraform init -migrate-state  # migrate state to new backend
```

- Must run after: cloning repo, adding provider/module, changing backend.
- Creates `.terraform/` directory and `.terraform.lock.hcl`.

### terraform plan

```bash
terraform plan              # show proposed changes
terraform plan -out=plan.tfplan  # save plan to file
terraform plan -target=aws_instance.web  # plan one resource + deps
terraform plan -var="env=prod"   # pass variable
terraform plan -var-file="prod.tfvars"  # pass variable file
terraform plan -destroy     # preview what destroy would do
terraform plan -refresh=false  # skip API refresh (use cached state)
```

### terraform apply

```bash
terraform apply             # plan + prompt + apply
terraform apply plan.tfplan # apply saved plan (no prompt)
terraform apply -auto-approve  # skip prompt (CI)
terraform apply -target=aws_instance.web  # apply one resource
terraform apply -replace=aws_instance.web  # force recreate
terraform apply -parallelism=5  # limit concurrent operations
terraform apply -refresh-only   # update state from real infra only
```

### terraform destroy

```bash
terraform destroy           # destroy all managed resources (prompts)
terraform destroy -auto-approve  # no prompt
terraform destroy -target=aws_instance.web  # destroy one resource
```

### terraform fmt and validate

```bash
terraform fmt               # format .tf files in current dir
terraform fmt -recursive    # format all subdirs
terraform fmt -check        # check formatting (CI — exits 1 if unformatted)
terraform validate          # syntax + internal consistency check (no API calls)
```

### terraform state

```bash
terraform state list        # list all resources
terraform state show aws_instance.web  # show one resource
terraform state mv aws_instance.old aws_instance.new  # rename in state
terraform state rm aws_instance.web  # remove from state (no destroy)
terraform state pull        # output state as JSON (pipe to file)
terraform state push        # upload state (dangerous)
```

### terraform output

```bash
terraform output            # show all outputs
terraform output instance_id  # show one output
terraform output -json      # JSON format (for scripts)
```

### terraform import

```bash
terraform import aws_instance.web i-0abc123  # import by resource ID
```

- Requires matching `resource` block in config.
- After import: run `plan` and adjust config until "No changes."

### terraform taint / replace

```bash
# Deprecated:
terraform taint aws_instance.web     # mark for recreation
terraform untaint aws_instance.web   # undo taint

# Modern:
terraform apply -replace=aws_instance.web  # force recreate
```

Related notes: [001-terraform-overview](./001-terraform-overview.md), [005-state-backend](./005-state-backend.md)

---

# Troubleshooting Guide

### "Error: No configuration files"
1. You're in the wrong directory — `cd` to the folder with `.tf` files.
2. Files must have `.tf` extension.

### Plan shows changes you didn't make (drift)
1. Someone changed infra outside Terraform.
2. Run `terraform apply -refresh-only` to update state.
3. Then `terraform plan` to align config.

### Apply fails with rate limiting
1. Reduce parallelism: `terraform apply -parallelism=2`.
2. Add retries in provider config if supported.
3. Split large configs into smaller root modules.

### "Error: Resource already exists"
1. Resource exists in cloud but not in Terraform state.
2. Import it: `terraform import <address> <id>`.
3. Or: if managed elsewhere, remove the resource block from your config.

# Quick Facts (Revision)

- `terraform plan -out=file` + `terraform apply file` is the safest CI workflow.
- `-target` should be used sparingly — creates incomplete state.
- `-auto-approve` is for CI only; always review plan interactively in development.
- `state rm` removes from state without destroying real infrastructure.
- `state mv` renames resources in state — essential during refactoring.
- `fmt -check` returns exit code 1 if files are unformatted — use in CI.
- `validate` checks syntax without API calls — fast pre-commit check.
- `taint` is deprecated; use `-replace` instead.
