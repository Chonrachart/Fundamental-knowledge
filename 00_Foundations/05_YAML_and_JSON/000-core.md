# YAML and JSON

- YAML and JSON are human-readable data serialization formats used to represent structured data as text.
- DevOps tools (Ansible, Kubernetes, Docker Compose, Terraform, CI/CD pipelines) rely on these formats for configuration, manifests, and API communication.
- YAML is a superset of JSON -- every valid JSON document is also valid YAML.

# Architecture

```text
+------------------------------------------------------------------+
|                     Human / Developer                            |
|             writes config file (YAML or JSON)                    |
+------------------------------------------------------------------+
                          |
                          v
+------------------------------------------------------------------+
|                       Parser                                     |
|    yamllint / yq / jq / language library (PyYAML, json)          |
|    validates syntax, resolves anchors/aliases                    |
+------------------------------------------------------------------+
                          |
                          v
+------------------------------------------------------------------+
|                Internal Data Structure                           |
|         dict / list / scalar  (language-native objects)           |
+------------------------------------------------------------------+
                          |
                          v
+------------------------------------------------------------------+
|                     Execution Engine                             |
|   Ansible  |  kubectl  |  docker compose  |  terraform           |
|   reads structured data --> takes action on infrastructure       |
+------------------------------------------------------------------+
```

# Mental Model

```text
DevOps config lifecycle:

  [1] Author    -->  write YAML/JSON in editor (with schema validation)
  [2] Lint      -->  yamllint / jsonlint catches syntax errors early
  [3] Commit    -->  version control (git diff works well with YAML)
  [4] Parse     -->  tool reads file into internal data structures
  [5] Execute   -->  tool applies desired state to infrastructure
  [6] Output    -->  API responses and tool output often come back as JSON
```

```bash
# round-trip example: write YAML, validate, convert to JSON
cat <<'YAML' > deploy.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
YAML

yamllint deploy.yml                  # lint the YAML
yq -o=json deploy.yml               # convert YAML to JSON
```

# Core Building Blocks

### YAML Syntax

- YAML uses indentation (spaces only) to represent structure, with scalars, sequences (lists), and mappings (dicts).
- Supports comments, multi-line strings, anchors/aliases, and multiple documents in one file.
- Common pitfalls: boolean coercion (`yes`/`no`), tab characters, unquoted colons.

Related notes: [001-yaml-syntax](./001-yaml-syntax.md)

### JSON Syntax

- JSON uses braces `{}` for objects, brackets `[]` for arrays, and strict quoting rules.
- No comments, no trailing commas -- stricter than YAML but unambiguous.
- Primary format for REST APIs, logging, and machine-to-machine communication.

Related notes: [002-json-syntax](./002-json-syntax.md)

### Tools and Validation

- `yamllint` lints YAML files; `jq` queries and transforms JSON; `yq` does the same for YAML.
- `python3 -m json.tool` pretty-prints JSON; `yaml.safe_load()` parses YAML safely in Python.
- IDE extensions provide real-time schema validation for Kubernetes, Ansible, Docker Compose files.

Related notes: [003-tools-and-validation](./003-tools-and-validation.md)

---

# Practical Command Set (Core)

```bash
# validate YAML syntax
yamllint playbook.yml

# pretty-print JSON
cat response.json | python3 -m json.tool

# query a YAML field (yq v4 syntax)
yq '.metadata.name' deployment.yml

# query a JSON field
jq '.status.conditions[0].type' pod.json

# convert YAML to JSON
yq -o=json values.yml

# convert JSON to YAML
yq -P input.json

# validate JSON syntax (returns non-zero on error)
python3 -m json.tool < input.json > /dev/null

# merge two YAML files
yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' base.yml override.yml
```

# Troubleshooting Guide

```text
Problem: tool rejects your YAML/JSON config file
    |
    v
[1] Syntax error?
    yamllint <file>  /  python3 -m json.tool < <file>
    |
    +-- fix reported line/column errors (tabs, bad indent, missing quotes)
    |
    v
[2] Unexpected value type?
    yq '.the.field' <file>   # check what the parser actually sees
    |
    +-- boolean trap: unquoted yes/no/on/off parsed as true/false
    +-- number trap: version "1.0" vs number 1.0
    |
    v
[3] Schema validation error?
    check tool docs for required fields and types
    |
    +-- Kubernetes: kubectl apply --dry-run=client -f <file>
    +-- Ansible: ansible-playbook --syntax-check <file>
    |
    v
[4] Encoding / invisible characters?
    cat -A <file>   # shows tabs as ^I, line endings
    file <file>     # check encoding (should be UTF-8)
```

# Quick Facts (Revision)

- YAML is a superset of JSON -- any valid JSON is valid YAML, but not vice versa.
- YAML uses indentation for structure; JSON uses braces and brackets.
- YAML supports comments (`#`); JSON does not.
- Unquoted `yes`, `no`, `on`, `off` in YAML are parsed as booleans -- always quote ambiguous strings.
- `jq` is for JSON; `yq` is for YAML (and can convert between them).
- JSON is preferred for APIs and machine output; YAML is preferred for human-authored config.
- Both formats represent the same data types: scalars, sequences (arrays), and mappings (objects).
- `yamllint` catches style and syntax issues; schema validation catches structural/semantic issues.

# Topic Map

- [001-yaml-syntax](./001-yaml-syntax.md) -- YAML scalars, collections, multi-line, anchors, gotchas
- [002-json-syntax](./002-json-syntax.md) -- JSON objects, arrays, comparison with YAML, jq basics
- [003-tools-and-validation](./003-tools-and-validation.md) -- yamllint, yq, jq, python, IDE support, conversion
