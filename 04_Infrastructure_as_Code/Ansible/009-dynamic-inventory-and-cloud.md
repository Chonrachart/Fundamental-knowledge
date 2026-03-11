dynamic inventory
inventory plugin
cloud
aws_ec2

---

# Dynamic Inventory

- Dynamic inventory is used when hosts change often.
- Ansible inventory plugins can query cloud or CMDB and build groups automatically.
- Inventory plugins usually come from collections (install them first).

# Inventory Plugin File

- You create a YAML config file for the plugin and pass it with `-i`.

```yaml
plugin: amazon.aws.aws_ec2
regions:
  - ap-southeast-1
keyed_groups:
  - key: tags.Environment
    prefix: env
```

```bash
ansible-galaxy collection install amazon.aws
```

```bash
ansible-inventory -i aws_ec2.yml --graph
ansible-inventory -i aws_ec2.yml --list
```

# Tips

- Use `keyed_groups` to group by tags/labels.
- Use `compose` to create variables from metadata.
- Enable inventory cache if the API is slow.

# Keep Playbooks Stable

- Even if inventory is dynamic, keep playbooks stable by targeting groups:
  - `hosts: env_prod`
  - `hosts: role_web`
