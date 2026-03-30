# Vault and Secrets

- Ansible Vault encrypts files or individual string values so secrets can be safely committed to git.
- Common pattern: encrypt `group_vars/*/secrets.yml`; leave non-secret vars in plain `vars.yml`.
- Vault password is required at runtime; supply via prompt, file, or external script.


# How Vault Works

```text
Plaintext secret  ->  ansible-vault encrypt  ->  AES-256 encrypted file (safe to commit)

At runtime:
ansible-playbook site.yml --vault-password-file .vault_pass
        |
        v
Ansible decrypts vault files in memory
        |
        v
Variables available to tasks/templates as normal
        |
        v
Never written to disk in plaintext
```

- Encrypted files look like `$ANSIBLE_VAULT;1.1;AES256\n...` in git — unreadable without the key.
- `rekey` changes the password without decrypting to disk permanently.


# Core Building Blocks

### Vault Commands

```bash
# create a new encrypted file
ansible-vault create group_vars/prod/secrets.yml

# encrypt an existing file in-place
ansible-vault encrypt group_vars/prod/secrets.yml

# decrypt a file in-place (use carefully -- don't commit plaintext)
ansible-vault decrypt group_vars/prod/secrets.yml

# view encrypted file content without decrypting to disk
ansible-vault view group_vars/prod/secrets.yml

# open encrypted file in editor
ansible-vault edit group_vars/prod/secrets.yml

# change vault password
ansible-vault rekey group_vars/prod/secrets.yml

# rekey with a new password file
ansible-vault rekey group_vars/prod/secrets.yml --new-vault-password-file new_pass.txt

# check if a file is vault-encrypted (first line shows $ANSIBLE_VAULT if encrypted)
head -1 group_vars/prod/secrets.yml

# encrypt all secrets files at once
find . -name "secrets.yml" | xargs ansible-vault encrypt
```

### Encrypt a Single String (inline secret)

```bash
ansible-vault encrypt_string 'supersecret123' --name 'db_password'
```

Output (paste directly into vars file):

```yaml
db_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  3938386636313963653366...
```

### Running Playbooks with Vault

```bash
# prompt for password at runtime
ansible-playbook site.yml --ask-vault-pass

# read password from file (use in CI/CD)
ansible-playbook site.yml --vault-password-file .vault_pass.txt

# use environment variable (CI/CD pipelines)
echo "mypassword" > .vault_pass.txt
export ANSIBLE_VAULT_PASSWORD_FILE=.vault_pass.txt
ansible-playbook site.yml
```

Add to `ansible.cfg` to set a default password file:

```ini
[defaults]
vault_password_file = .vault_pass.txt   # path relative to ansible.cfg
```

### Vault IDs (Multiple Passwords)

```bash
# label vaults by environment
ansible-vault encrypt group_vars/prod/secrets.yml --vault-id prod@prompt
ansible-vault encrypt group_vars/dev/secrets.yml  --vault-id dev@prompt

# run with multiple vault IDs
ansible-playbook site.yml --vault-id prod@prompt --vault-id dev@.vault_dev_pass.txt
```

- Vault IDs allow different passwords per environment (dev/staging/prod) in one run.

### Recommended Secrets Layout

```text
group_vars/
  prod/
    vars.yml         <- non-sensitive vars (committed plaintext)
    secrets.yml      <- vault-encrypted: db_password, api_keys, etc.
  dev/
    vars.yml
    secrets.yml
```

Related notes:
- [002-inventory-and-ansible-cfg](./002-inventory-and-ansible-cfg.md) — group_vars layout



- Never commit plaintext secrets — always encrypt before `git add`.
- `ansible-vault view` is safer than `decrypt` — reads without writing plaintext to disk.
- Separate secrets from non-secrets (`secrets.yml` + `vars.yml`) for readable diffs.
- Vault IDs allow per-environment passwords — use `prod@prompt`, `dev@file`.
- Add `.vault_pass.txt` to `.gitignore` — never commit the password file.
- `rekey` rotates the vault password; run it when a team member leaves.
- `encrypt_string` is useful for single values; full file encryption is better for many secrets.
