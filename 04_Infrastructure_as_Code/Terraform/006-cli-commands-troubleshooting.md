terraform init
terraform plan
terraform apply
terraform destroy
terraform fmt
terraform validate
terraform state
troubleshooting
refresh
taint
replace

---

# terraform init

- **Downloads** providers and (if used) modules; **initializes backend**; creates **.terraform/** and lock file.
- **-upgrade**: Upgrade providers/modules to latest within constraints.
- **-reconfigure**: Reconfigure backend (e.g. switch from local to S3) without migrating state.
- **-migrate-state**: When changing backend; copy state to new backend.
- Run **init** after adding provider or module; after clone before plan/apply.

# terraform plan

- **Reads** state and config; **proposes** changes; **no modifications** to real infra or state.
- **-out=file**: Save plan to file; **terraform apply file** applies that plan (no new plan).
- **-refresh=false**: Skip refresh (use state as-is for planning); faster but may be inaccurate.
- **-target=resource**: Plan only resource and dependencies; **partial apply**; use sparingly.
- **-destroy**: Plan for destroy (what would be removed).
- **-var**, **-var-file**: Pass variables.

# terraform apply

- **Applies** changes; by default runs plan first and prompts; **-auto-approve** skip prompt (CI).
- **terraform apply plan_file**: Apply saved plan; no prompt.
- **-parallelism=n**: Limit concurrent operations (default 10); reduce for rate limits.
- **-target**: Apply only specific resource (and deps); can create **incomplete** state; fix with full apply later.
- **-replace=address**: Force replace one resource (recreate) even if no config change.

# terraform destroy

- **Destroys** all resources in state; **-target** to destroy subset; **-auto-approve** for non-interactive.
- **Order**: Terraform computes destroy order from dependencies; **create_before_destroy** affects replace, not destroy.

# terraform fmt and validate

- **fmt**: Format .tf files; **-recursive** for dirs; **-check** to only verify (CI).
- **validate**: Config syntax and internal consistency; **no** provider API calls; fast check.

# terraform state

- **list**: List resources in state; **state show address**: Show one resource state.
- **mv**: Move resource in state (rename or move to module); **rm**: Remove from state (does **not** destroy real resource).
- **pull**: Output state as JSON; **push**: Upload state (dangerous; use with care).
- **state rm**: When resource was imported wrongly or you're handing it to another state.

# refresh and -refresh

- **terraform apply -refresh-only**: Update state from real infrastructure without applying config changes; use after manual change or to fix drift.
- **plan/apply** normally **refresh** first (read current state from provider); **-refresh=false** skips it.

# taint and replace

- **terraform taint address** (deprecated): Mark resource for **recreation** on next apply; use **terraform apply -replace=address** instead.
- **-replace**: Force replace one or more resources; useful when resource is broken or immutable attribute changed.

# Troubleshooting — Common Errors

- **Error: No value for required variable**: Set **-var**, **-var-file**, or **TF_VAR_name**; or default in variable.
- **Error: Resource already exists**: Import with **terraform import address id**; or remove from config if managed elsewhere.
- **Error: Invalid for_each argument**: **for_each** must be map or set of strings; use **toset()** for list.
- **Error: Cycle**: Circular dependency between resources; fix with **depends_on** or split resource.
- **State lock**: Backend holds lock; **force-unlock lock_id** only if you're sure no other process is running.
- **Provider schema / version**: **terraform init -upgrade** or fix **required_providers** version.
