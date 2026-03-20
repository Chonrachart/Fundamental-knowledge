# Dynamic Inventory and Cloud

- Dynamic inventory queries a live source (cloud API, CMDB, DNS) at runtime instead of a static file.
- Inventory plugins (from collections) handle the query and auto-build groups from tags/labels/metadata.
- Playbooks remain stable by targeting group names; only the inventory source changes.


# Static vs Dynamic Inventory

```text
Static inventory                    Dynamic inventory
  hosts.ini / inventory.yaml          aws_ec2.yml / gcp_compute.yml
  hand-edited host list               queries cloud API at runtime
  fine for fixed infra                required for auto-scaling, ephemeral VMs
  no dependencies                     requires collection + cloud credentials
        |                                       |
        v                                       v
  ansible-playbook -i inventory/    ansible-playbook -i aws_ec2.yml
```


# How Inventory Plugins Work

```text
ansible-inventory -i aws_ec2.yml --list
        |
        v
Ansible loads inventory plugin declared in YAML config
        |
        v
Plugin calls cloud API (AWS EC2, GCP, Azure, etc.)
        |
        v
Returns JSON: hosts + groups + hostvars
        |
        v
keyed_groups: group hosts by tag/label/attribute
compose: create custom variables from metadata
        |
        v
Ansible builds in-memory inventory
        |
        v
Playbook targets groups as normal: hosts: env_prod
```


# Core Building Blocks

### AWS EC2 Plugin (amazon.aws)

```bash
# install collection first
ansible-galaxy collection install amazon.aws
```

```yaml
# inventory/aws_ec2.yml
plugin: amazon.aws.aws_ec2

regions:
  - ap-southeast-1              # query these AWS regions

filters:
  instance-state-name: running  # only running instances

keyed_groups:
  - key: tags.Environment       # group by EC2 tag "Environment"
    prefix: env                 # -> groups: env_prod, env_staging, env_dev
  - key: tags.Role
    prefix: role                # -> groups: role_web, role_db

compose:
  ansible_host: public_ip_address   # use public IP to connect
  # ansible_host: private_ip_address  # use this inside VPC

hostnames:
  - tag:Name                    # use EC2 Name tag as hostname in inventory
  - private-ip-address          # fallback

# enable cache to avoid hammering the API every run
cache: true
cache_plugin: jsonfile
cache_connection: /tmp/ansible_aws_cache
cache_timeout: 300              # seconds
```

```bash
# verify dynamic inventory
ansible-inventory -i inventory/aws_ec2.yml --graph
ansible-inventory -i inventory/aws_ec2.yml --list

# test connectivity
ansible -i inventory/aws_ec2.yml env_prod -m ping
```

Related notes:
- [002-inventory-and-ansible-cfg](./002-inventory-and-ansible-cfg.md) — static inventory + host patterns

### Other Common Plugins

| Plugin | Collection | Source |
|---|---|---|
| `amazon.aws.aws_ec2` | amazon.aws | AWS EC2 |
| `google.cloud.gcp_compute` | google.cloud | GCP Compute |
| `azure.azcollection.azure_rm` | azure.azcollection | Azure VMs |
| `community.vmware.vmware_vm_inventory` | community.vmware | VMware vCenter |
| `ansible.builtin.script` | builtin | Custom script output |
| `ansible.builtin.constructed` | builtin | Build groups from existing inventory |

### Stable Playbooks with Dynamic Inventory

```yaml
# playbook stays the same regardless of inventory source
- name: Configure web servers
  hosts: role_web          # group built from EC2 tag Role=web
  become: true
  roles:
    - nginx

- name: Configure databases
  hosts: role_db           # group built from EC2 tag Role=db
  roles:
    - postgresql
```

- Tag/label your cloud resources consistently — these become Ansible group names.
- Recommended EC2 tags: `Environment`, `Role`, `Project`, `Owner`.

---

# Practical Command Set (Core)

```bash
# inspect dynamic inventory
ansible-inventory -i inventory/aws_ec2.yml --graph
ansible-inventory -i inventory/aws_ec2.yml --list
ansible-inventory -i inventory/aws_ec2.yml --host <hostname>

# test plugin works (needs AWS credentials in env or ~/.aws)
AWS_PROFILE=myprofile ansible-inventory -i inventory/aws_ec2.yml --graph

# clear inventory cache
rm -f /tmp/ansible_aws_cache/*

# run playbook against dynamic inventory
ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml --limit env_prod
```


# Troubleshooting Guide

### "No hosts matched" with dynamic inventory

1. Run `ansible-inventory -i <plugin>.yml --graph` to check groups returned.
2. Check cloud credentials (`AWS_ACCESS_KEY_ID` / AWS profile / IAM role).
3. Check that the region matches where instances are running.
4. Check filters (`instance-state-name: running` may exclude stopped instances).
5. Check that the `keyed_groups` key path matches the actual tag/attribute name.
6. Clear cache and retry: `rm /tmp/ansible_aws_cache/*`.
7. Run with `-vvv` for plugin debug output.


# Quick Facts (Revision)

- Dynamic inventory requires the collection installed: `ansible-galaxy collection install <collection>`.
- Cloud credentials must be available at runtime (env vars, `~/.aws`, IAM role, etc.).
- `keyed_groups` builds groups from tags; consistent tagging strategy is critical.
- `compose` creates hostvars from instance metadata (e.g. set `ansible_host`).
- Enable `cache: true` to avoid hammering the cloud API on every run.
- Playbooks should target group names (e.g. `env_prod`) — not IPs — so they work with any inventory.
- `ansible.builtin.constructed` can layer additional groups on top of existing inventory.
