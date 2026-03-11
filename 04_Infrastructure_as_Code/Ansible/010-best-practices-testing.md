best practices
idempotent
lint
testing
molecule

---

# Best Practices

- Prefer modules over shell commands.
- Keep playbooks small; move reusable logic into roles.
- Use `handlers` for restarts and reloads.
- Use `defaults` for role inputs; avoid hardcoding.
- Keep inventory and vars organized (group_vars/host_vars).

# Idempotency

- Your playbook should be safe to run multiple times.
- Use `changed_when` only when needed and with clear logic.

# Testing and Quality

- `--check --diff` for quick dry-run review.
- Use `ansible-lint` to catch common issues.
- Use `molecule` to test roles in isolated environments.

```bash
ansible-playbook playbooks/site.yml --check --diff
ansible-lint
```

# Troubleshooting Ideas

- Increase verbosity: `-vvv`
- Print variables: `debug: var=...`
- Validate assumptions early with `assert:`.
