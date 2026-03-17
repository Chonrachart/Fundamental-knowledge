# YAML Syntax

- YAML (YAML Ain't Markup Language) represents data using indentation-based structure with scalars, sequences, and mappings.
- It is designed for human readability and is the dominant config format in DevOps (Ansible, Kubernetes, Docker Compose, GitHub Actions).
- Indentation must use spaces (never tabs), and structure is whitespace-sensitive.

# Architecture

```text
YAML Document Structure:

+----------------------------------------------------------+
|  --- (document start marker, optional)                   |
+----------------------------------------------------------+
|                                                          |
|  mapping:                   # key-value pairs            |
|    scalar_key: scalar_val   # string, number, bool, null |
|    sequence_key:            # list of items              |
|      - item1                                             |
|      - item2                                             |
|    nested_map:              # map inside a map           |
|      inner_key: inner_val                                |
|                                                          |
+----------------------------------------------------------+
|  ... (document end marker, optional)                     |
+----------------------------------------------------------+
```

# Mental Model

```text
YAML parsing flow:

  Raw text
      |
      v
  [1] Tokenize  -->  identify indentation levels, colons, dashes
      |
      v
  [2] Parse     -->  build tree of mappings, sequences, scalars
      |
      v
  [3] Resolve   -->  apply type rules (unquoted true = boolean, 42 = int)
      |
      v
  [4] Construct -->  language-native objects (dict, list, str, int, bool)
```

```yaml
# example: Kubernetes pod spec showing all basic structures
apiVersion: v1                    # scalar (string)
kind: Pod
metadata:
  name: web                       # nested mapping
  labels:
    app: frontend                 # deeper nesting
spec:
  containers:                     # sequence of mappings
    - name: nginx
      image: nginx:1.25
      ports:
        - containerPort: 80       # scalar (integer)
```

# Core Building Blocks

### Scalars

- Scalars are single values: strings, integers, floats, booleans, null.
- Strings do not require quotes unless they contain special characters (`:`, `#`, `{`, `[`, etc.).
- Quoting rules:
  - `"double quotes"` -- processes escape sequences (`\n`, `\t`)
  - `'single quotes'` -- literal text, no escape processing (use `''` to escape a single quote)
  - unquoted -- most common, but subject to type coercion

```yaml
string_plain: hello world
string_quoted: "contains: colon"
string_single: 'no \n escape here'
integer: 42
float: 3.14
boolean_true: true
boolean_false: false
null_value: null
null_tilde: ~
empty_value:                      # also null
```

Related notes: [000-core](./000-core.md)

### Boolean Trap

- YAML 1.1 (used by many tools) treats these as booleans:
  - `true`, `false`, `yes`, `no`, `on`, `off`, `True`, `False`, `YES`, `NO`, `ON`, `OFF`
- This causes real bugs in DevOps configs.

```yaml
# DANGEROUS -- these are all booleans, not strings:
country_code: NO        # parsed as false (not "NO" for Norway)
feature_flag: on        # parsed as true  (not the string "on")
answer: yes             # parsed as true  (not the string "yes")

# SAFE -- quote them:
country_code: "NO"      # string "NO"
feature_flag: "on"      # string "on"
answer: "yes"           # string "yes"
```

- YAML 1.2 (strict spec) only recognizes `true` and `false`, but most tools still use YAML 1.1 rules.
- Rule of thumb: if a string value could be mistaken for a boolean, quote it.

Related notes: [003-tools-and-validation](./003-tools-and-validation.md)

### Multi-line Strings

- `|` (literal block) -- preserves newlines exactly as written.
- `>` (folded block) -- folds newlines into spaces (like a paragraph).
- Chomping indicators control trailing newlines:
  - `|` or `>` -- keep one trailing newline (default, "clip")
  - `|-` or `>-` -- strip all trailing newlines ("strip")
  - `|+` or `>+` -- keep all trailing newlines ("keep")

```yaml
# literal block: newlines preserved
script: |
  #!/bin/bash
  echo "line 1"
  echo "line 2"

# folded block: newlines become spaces
description: >
  This is a long description
  that wraps across multiple lines
  but becomes a single paragraph.

# strip trailing newline
command: |-
  echo "no trailing newline after this"
```

Related notes: [000-core](./000-core.md)

### Sequences (Lists)

- Block sequence: items prefixed with `- ` (dash + space).
- Flow sequence: `[item1, item2, item3]` (inline, JSON-like).
- Items can be any type: scalars, mappings, or nested sequences.

```yaml
# block sequence
fruits:
  - apple
  - banana
  - cherry

# flow sequence (inline)
colors: [red, green, blue]

# sequence of mappings (common in K8s and Ansible)
containers:
  - name: app
    image: myapp:v1
  - name: sidecar
    image: proxy:v2
```

Related notes: [002-json-syntax](./002-json-syntax.md)

### Mappings (Dictionaries)

- Block mapping: `key: value` pairs, one per line, at the same indentation level.
- Flow mapping: `{key1: val1, key2: val2}` (inline, JSON-like).
- Keys are usually strings but can technically be any scalar.

```yaml
# block mapping
metadata:
  name: my-app
  namespace: production
  version: "2.1"

# flow mapping (inline)
labels: {app: web, tier: frontend}
```

Related notes: [002-json-syntax](./002-json-syntax.md)

### Nested Structures

- Nesting is expressed purely through indentation (2 spaces is conventional).
- Sequences can contain mappings, mappings can contain sequences, to arbitrary depth.

```yaml
# real-world nesting: Ansible task
- name: Install and start nginx
  hosts: webservers
  become: true
  tasks:
    - name: Install nginx
      ansible.builtin.apt:
        name: nginx
        state: present
    - name: Start nginx
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true
```

Related notes: [000-core](./000-core.md)

### Comments

- Comments start with `#` and continue to end of line.
- Can appear on their own line or inline after a value.
- No block/multi-line comment syntax exists in YAML.

```yaml
# this is a full-line comment
name: web    # this is an inline comment
```

Related notes: [000-core](./000-core.md)

### Indentation Rules

- Use spaces only -- tabs are forbidden and cause parse errors.
- Consistent indent within a block (2 spaces is the community standard).
- Child elements must be indented further than their parent.
- Misaligned indentation is the single most common YAML error.

```text
WRONG (tabs or inconsistent):       CORRECT (2-space indent):
metadata:                            metadata:
[TAB]name: web                         name: web
   namespace: prod                     namespace: prod
```

Related notes: [003-tools-and-validation](./003-tools-and-validation.md)

### Anchors and Aliases

- `&name` defines an anchor (saves a node for reuse).
- `*name` creates an alias (references the anchored node).
- `<<: *name` merges an anchored mapping into the current mapping (merge key).
- Useful for DRY configs (e.g., shared defaults in Docker Compose).

```yaml
# define shared defaults
defaults: &defaults
  restart: always
  networks:
    - backend

services:
  app:
    <<: *defaults              # merge defaults into this mapping
    image: myapp:v1
    ports:
      - "8080:8080"

  worker:
    <<: *defaults              # reuse same defaults
    image: myworker:v1
```

Related notes: [000-core](./000-core.md)

### Multiple Documents

- `---` starts a new document within the same file.
- `...` optionally marks the end of a document.
- Commonly used in Kubernetes manifests to bundle multiple resources.

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: web-svc
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deploy
```

Related notes: [002-json-syntax](./002-json-syntax.md)

### Common Gotchas for DevOps

- **Norway problem**: `NO` is parsed as `false` -- always quote country codes and similar values.
- **Colon in strings**: `url: http://example.com` works, but `key: value: extra` breaks -- quote if ambiguous.
- **Tabs**: any tab character causes a parse error -- configure your editor to insert spaces.
- **Trailing spaces**: can cause subtle issues -- enable "show whitespace" in your editor.
- **Version numbers**: `version: 1.0` is a float (1.0), not string "1.0" -- use `version: "1.0"`.
- **Octal numbers**: `0777` is parsed as octal (511 decimal) in YAML 1.1 -- quote if you mean the string.
- **Timestamps**: `2024-01-01` is parsed as a date object -- quote if you want a string.

Related notes: [003-tools-and-validation](./003-tools-and-validation.md)

---

# Practical Command Set (Core)

```bash
# lint a YAML file for syntax and style issues
yamllint playbook.yml

# parse and re-emit YAML (catches syntax errors)
yq '.' config.yml

# check what type YAML assigns to a value
yq '.country_code | type' data.yml

# validate an Ansible playbook's YAML syntax
ansible-playbook --syntax-check playbook.yml

# validate a Kubernetes manifest
kubectl apply --dry-run=client -f deployment.yml

# show invisible characters (tabs show as ^I)
cat -A config.yml
```

# Troubleshooting Flow (Quick)

```text
Problem: YAML file causes parse error or unexpected behavior
    |
    v
[1] Syntax error on specific line?
    yamllint <file>  -->  check for tabs, bad indent, missing colon
    |
    v
[2] Value has wrong type?
    yq '.key | type' <file>
    |
    +-- expected string but got bool --> quote the value ("yes", "no", "on", "off")
    +-- expected string but got int  --> quote the value ("1.0", "0777")
    |
    v
[3] Multi-line string not rendering correctly?
    check block scalar indicator: | (literal) vs > (folded)
    check chomping: default (clip) vs - (strip) vs + (keep)
    |
    v
[4] Anchor/alias not merging?
    ensure <<: *alias syntax is correct
    verify the anchor (&name) is defined before the alias (*name)
```

# Quick Facts (Revision)

- YAML uses indentation (spaces only, never tabs) to denote structure.
- Unquoted `yes`, `no`, `on`, `off`, `true`, `false` are all booleans -- quote when you mean strings.
- `|` preserves newlines (literal); `>` folds newlines into spaces (folded).
- `-` after block indicator (`|-`, `>-`) strips the trailing newline.
- `&anchor` defines, `*alias` references, `<<: *merge` merges a mapping.
- `---` separates multiple documents in one file.
- Keys containing `:`, `#`, `{`, `[` or starting with `- ` must be quoted.
- YAML 1.1 (PyYAML, most tools) has more boolean values than YAML 1.2 (strict spec).
