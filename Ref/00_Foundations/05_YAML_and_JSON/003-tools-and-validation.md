# Tools and Validation

- Linting and validation tools catch YAML/JSON errors before they reach production (shift-left).
- `yamllint` validates YAML syntax and style; `jq` queries/transforms JSON; `yq` does the same for YAML.
- IDE integrations with JSON Schema provide real-time feedback while editing config files.

# Architecture

```text
+------------------+     +------------------+     +------------------+
|   Author         |     |   CI Pipeline    |     |   Deploy Tool    |
|   (IDE + schema) | --> |   (lint + test)  | --> |   (parse + run)  |
+------------------+     +------------------+     +------------------+
        |                        |                        |
   JSON Schema            yamllint / jq             ansible-playbook
   YAML extension         pre-commit hooks          kubectl apply
   autocomplete           schema validation         terraform plan
        |                        |                        |
        v                        v                        v
   catch errors            catch errors             catch errors
   at write time           at commit time           at deploy time
   (fastest feedback)      (automated gate)         (last resort)
```

# Mental Model

```text
Validation layers (shift-left):

  [1] IDE        -->  schema-aware autocomplete + inline errors (fastest)
  [2] Pre-commit -->  yamllint / jsonlint run before code is committed
  [3] CI         -->  automated lint + dry-run in pipeline
  [4] Runtime    -->  tool rejects invalid config at execution time (slowest)

  Goal: catch errors at layer [1] or [2], never at [4].
```

```bash
# example: full validation pipeline for a Kubernetes manifest
yamllint deployment.yml                                  # [1] syntax lint
yq '.' deployment.yml > /dev/null                        # [2] parse check
kubectl apply --dry-run=client -f deployment.yml         # [3] schema check
kubectl apply -f deployment.yml                          # [4] actual deploy
```

# Core Building Blocks

### yamllint

- A Python-based linter for YAML files -- checks syntax and enforces style rules.
- Configurable via `.yamllint` or `.yamllint.yml` in the project root.
- Common rules: line length, indentation size, trailing spaces, truthy values.

```bash
# install
pip install yamllint

# lint a file
yamllint playbook.yml

# lint all YAML in a directory
yamllint .

# lint with a specific config
yamllint -c .yamllint.yml playbook.yml
```

```yaml
# .yamllint.yml -- example config
---
extends: default

rules:
  line-length:
    max: 120
  indentation:
    spaces: 2
  truthy:
    check-keys: false
    allowed-values: ['true', 'false']
  comments:
    min-spaces-from-content: 1
  document-start: disable
```

- CI integration: add `yamllint .` as a step in your CI pipeline or pre-commit hook.

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/adrienverge/yamllint
    rev: v1.35.1
    hooks:
      - id: yamllint
        args: [-c, .yamllint.yml]
```

Related notes: [001-yaml-syntax](./001-yaml-syntax.md)

### yq

- A command-line YAML/JSON/XML processor -- like `jq` but for YAML.
- Two major versions exist: Mike Farah's Go-based `yq` (v4, recommended) and the older Python `yq`.
- Can read, query, update, merge, and convert between YAML, JSON, and XML.

```bash
# install (Go version, v4)
# snap:
snap install yq
# or download binary from https://github.com/mikefarah/yq

# read a field
yq '.metadata.name' deployment.yml

# read nested field
yq '.spec.template.spec.containers[0].image' deployment.yml

# update a field (in-place)
yq -i '.spec.replicas = 5' deployment.yml

# add a new field
yq -i '.metadata.labels.env = "staging"' deployment.yml

# delete a field
yq -i 'del(.metadata.annotations)' deployment.yml

# merge two YAML files (override values)
yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' base.yml override.yml

# iterate over a list
yq '.spec.template.spec.containers[].name' deployment.yml

# output as JSON
yq -o=json deployment.yml

# evaluate expression on multiple files
yq '.metadata.name' deployment.yml service.yml
```

Related notes: [000-core](./000-core.md)

### jq

- A lightweight command-line JSON processor with a powerful filter language.
- Essential for scripting with REST APIs, kubectl, aws cli, terraform output.
- Filters are composable with `|` (pipe) -- similar to Unix pipes.

```bash
# install
sudo apt install jq    # Debian/Ubuntu
brew install jq        # macOS

# pretty-print
jq '.' input.json

# select a field
jq '.name' input.json

# raw output (no quotes around strings)
jq -r '.name' input.json

# array operations
jq '.items | length' input.json          # count
jq '.items[0]' input.json               # first element
jq '.items[-1]' input.json              # last element
jq '.items[2:5]' input.json             # slice

# iterate and select
jq '.items[] | select(.status == "active")' input.json

# map: transform each element
jq '.items | map(.name)' input.json

# construct new objects
jq '.items[] | {name: .metadata.name, ns: .metadata.namespace}' input.json

# multiple filters with comma
jq '.name, .version' input.json

# conditional
jq 'if .replicas > 1 then "scaled" else "single" end' input.json

# slurp multiple files into array
jq -s '.' file1.json file2.json

# compact output (one line)
jq -c '.' input.json
```

Related notes: [002-json-syntax](./002-json-syntax.md)

### Python Tools

- Python's standard library includes `json` module; `PyYAML` is the standard YAML library.
- Useful for quick validation, conversion, and scripting.

```bash
# pretty-print JSON (built-in, no install needed)
python3 -m json.tool < input.json
python3 -m json.tool input.json

# validate JSON (non-zero exit on error)
python3 -m json.tool < input.json > /dev/null

# convert JSON to YAML (one-liner)
python3 -c "
import sys, json, yaml
data = json.load(sys.stdin)
print(yaml.dump(data, default_flow_style=False))
" < input.json

# convert YAML to JSON (one-liner)
python3 -c "
import sys, json, yaml
data = yaml.safe_load(sys.stdin)
print(json.dumps(data, indent=2))
" < input.yml

# parse and inspect YAML (check for boolean trap)
python3 -c "
import yaml
with open('config.yml') as f:
    data = yaml.safe_load(f)
    print(type(data['country_code']), data['country_code'])
"
```

- Always use `yaml.safe_load()` (not `yaml.load()`) to prevent arbitrary code execution.

Related notes: [001-yaml-syntax](./001-yaml-syntax.md)

### IDE Support

- **VSCode YAML extension** (Red Hat):
  - Provides JSON Schema validation for K8s, Ansible, Docker Compose, GitHub Actions.
  - Autocomplete for known schemas via SchemaStore.
  - Settings in `.vscode/settings.json`:

```json
{
  "yaml.schemas": {
    "https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json": "docker-compose*.yml",
    "kubernetes": "k8s/**/*.yml"
  },
  "yaml.validate": true,
  "yaml.format.enable": true
}
```

- **VSCode JSON Schema validation**:
  - Built-in for `package.json`, `tsconfig.json`, etc.
  - Add `"$schema"` key to any JSON file for automatic validation.

- **Other editors**:
  - Vim/Neovim: `coc-yaml`, `yaml-language-server`
  - JetBrains: built-in YAML/JSON support with schema detection

Related notes: [002-json-syntax](./002-json-syntax.md)

### Conversion Between Formats

- YAML to JSON and back is lossless for data (comments and formatting are lost).

```bash
# YAML to JSON (yq)
yq -o=json input.yml

# YAML to JSON (yq, compact)
yq -o=json -I=0 input.yml

# JSON to YAML (yq)
yq -P input.json

# YAML to JSON (python)
python3 -c "import sys,json,yaml; print(json.dumps(yaml.safe_load(sys.stdin),indent=2))" < input.yml

# JSON to YAML (python)
python3 -c "import sys,json,yaml; print(yaml.dump(json.load(sys.stdin),default_flow_style=False))" < input.json

# verify round-trip
yq -o=json input.yml | yq -P    # should match original (minus comments)
```

Related notes: [000-core](./000-core.md)

### Practical DevOps Examples

```bash
# validate an Ansible playbook
yamllint playbook.yml
ansible-playbook --syntax-check playbook.yml

# extract image names from a Kubernetes deployment
yq '.spec.template.spec.containers[].image' deployment.yml

# get all running pod names
kubectl get pods -o json | jq -r '.items[] | select(.status.phase=="Running") | .metadata.name'

# extract specific fields from AWS CLI output
aws ec2 describe-instances --output json | jq -r \
  '.Reservations[].Instances[] | {id: .InstanceId, state: .State.Name, type: .InstanceType}'

# parse Terraform output
terraform output -json | jq -r '.vpc_id.value'

# check GitHub Actions workflow syntax
yamllint .github/workflows/*.yml

# extract all unique labels from K8s resources
kubectl get all -o json | jq '[.items[].metadata.labels // {} | to_entries[]] | unique_by(.key) | from_entries'
```

Related notes: [000-core](./000-core.md)
