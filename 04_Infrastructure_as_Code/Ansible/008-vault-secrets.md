vault
secrets
vault id
encrypt_string

---

# Ansible Vault

- Vault encrypts files or variables for secrets.
- Common use: keep `group_vars/` secrets encrypted in git.

# Common Commands

```bash
ansible-vault create secret.yml
ansible-vault edit secret.yml
ansible-vault encrypt secret.yml
ansible-vault decrypt secret.yml
ansible-vault rekey secret.yml
```

# Use Vault in Playbook

```bash
ansible-playbook playbooks/site.yml --ask-vault-pass
```

### Vault Password File

```bash
ansible-playbook playbooks/site.yml --vault-password-file .vault_pass.txt
```

# Vault IDs (multiple vault passwords)

```bash
ansible-playbook playbooks/site.yml --vault-id prod@prompt --vault-id dev@prompt
```

# encrypt_string (secret in file)

```bash
ansible-vault encrypt_string 'mysecret' --name 'db_password'
```

# Best Practices

- Do not commit plaintext secrets.
- Separate secrets file (vaulted) from non-secret vars file.
- Prefer per-environment vault files (dev/prod).
- Rotate secrets with `rekey` when needed.
