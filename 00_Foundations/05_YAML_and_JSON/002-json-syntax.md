# JSON Syntax

- JSON (JavaScript Object Notation) is a lightweight, text-based data interchange format with strict syntax rules.
- It is the standard format for REST APIs, logging, configuration (package.json, tsconfig), and machine-to-machine communication.
- JSON has six data types: object, array, string, number, boolean (true/false), and null.

# Architecture

```text
JSON Document Structure:

+----------------------------------------------------------+
|  {                          <-- root must be object or    |
|                                 array                     |
|    "key": "string_value",   <-- all keys must be quoted   |
|    "number": 42,                                          |
|    "float": 3.14,                                         |
|    "bool": true,            <-- only true/false           |
|    "nothing": null,                                       |
|    "list": [1, 2, 3],      <-- array                     |
|    "nested": {              <-- object inside object      |
|      "inner": "value"                                     |
|    }                                                      |
|  }                                                        |
+----------------------------------------------------------+

No comments.  No trailing commas.  Keys always double-quoted.
```

# Mental Model

```text
JSON processing in DevOps:

  API request / tool output
      |
      v
  [1] Raw JSON string
      |
      v
  [2] Parse (jq / python json / language library)
      |
      v
  [3] Navigate: .key, .array[0], .nested.field
      |
      v
  [4] Filter / Transform: select, map, reduce
      |
      v
  [5] Output: pretty-print, extract value, feed to next tool
```

```bash
# real-world example: get pod names from kubectl JSON output
kubectl get pods -o json | jq -r '.items[].metadata.name'
```

# Core Building Blocks

### Objects

- An object is an unordered collection of key-value pairs wrapped in `{}`.
- Keys must be double-quoted strings; values can be any JSON type.
- Duplicate keys are technically allowed by spec but cause undefined behavior -- avoid them.

```json
{
  "name": "nginx",
  "version": "1.25.3",
  "ports": [80, 443],
  "metadata": {
    "team": "platform",
    "env": "production"
  }
}
```

Related notes: [001-yaml-syntax](./001-yaml-syntax.md)

### Arrays

- An ordered list of values wrapped in `[]`.
- Elements can be any type (including mixed types, though discouraged).
- Accessed by zero-based index.

```json
{
  "servers": [
    {"host": "web01", "port": 8080},
    {"host": "web02", "port": 8080}
  ],
  "tags": ["production", "web", "us-east-1"]
}
```

Related notes: [001-yaml-syntax](./001-yaml-syntax.md)

### Data Types

| Type    | Example              | Notes                            |
| :------ | :------------------- | :------------------------------- |
| String  | `"hello"`            | Must use double quotes           |
| Number  | `42`, `3.14`, `-1`   | No octal, no hex, no NaN        |
| Boolean | `true`, `false`      | Lowercase only, no yes/no       |
| Null    | `null`               | Lowercase only                   |
| Object  | `{"k": "v"}`         | Unordered key-value pairs        |
| Array   | `[1, 2, 3]`          | Ordered list                     |

- No date type -- dates are represented as strings (ISO 8601: `"2024-01-15T10:30:00Z"`).
- No comment syntax -- use `"_comment"` keys as a workaround if needed.
- No undefined -- only `null` for absent values.

Related notes: [001-yaml-syntax](./001-yaml-syntax.md)

### No Comments (Workarounds)

- The JSON spec does not allow comments of any kind.
- Common workarounds:
  - `"_comment"` or `"//comment"` keys (ignored by most tools)
  - JSONC (JSON with Comments) -- supported by VSCode, tsconfig, but not standard
  - Use YAML instead when human-authored comments are needed

```json
{
  "_comment": "This configures the web server",
  "port": 8080,
  "host": "0.0.0.0"
}
```

Related notes: [000-core](./000-core.md)

### No Trailing Commas

- A trailing comma after the last element is a syntax error.
- This is the most common JSON syntax mistake when hand-editing.

```text
WRONG:                              CORRECT:
{                                   {
  "a": 1,                            "a": 1,
  "b": 2,    <-- trailing comma      "b": 2
}                                   }
```

Related notes: [003-tools-and-validation](./003-tools-and-validation.md)

### JSON vs YAML Comparison

| Feature            | JSON                       | YAML                          |
| :----------------- | :------------------------- | :---------------------------- |
| Readability        | Moderate (verbose)         | High (clean, minimal syntax)  |
| Comments           | Not supported              | Supported (`#`)               |
| Trailing commas    | Not allowed                | N/A (no commas)               |
| Data types         | 6 types                    | Same + dates, timestamps      |
| Boolean values     | `true` / `false` only      | true/false/yes/no/on/off      |
| Multi-line strings | Not native (use `\n`)      | `\|` and `>` block scalars    |
| Multiple docs      | Not supported              | `---` separator               |
| Key quoting        | Required (double quotes)   | Optional                      |
| Parsing speed      | Faster (simpler grammar)   | Slower (complex grammar)      |
| Superset relation  | --                         | YAML is a superset of JSON    |
| Primary use        | APIs, machine interchange  | Human-authored config files   |

Related notes: [001-yaml-syntax](./001-yaml-syntax.md)

### When to Use JSON vs YAML

- **Use JSON for:**
  - REST API request/response bodies
  - Tool output (kubectl, aws cli, terraform output)
  - Machine-generated config (package.json, lock files)
  - Logging (structured logs)
  - Data interchange between services

- **Use YAML for:**
  - Human-authored configuration (Ansible, K8s manifests, Docker Compose)
  - CI/CD pipeline definitions (GitHub Actions, GitLab CI)
  - Helm charts and values files
  - Any config where comments and readability matter

Related notes: [000-core](./000-core.md)

### JSON Schema Basics

- JSON Schema is a vocabulary for annotating and validating JSON documents.
- Defines expected structure: required fields, data types, allowed values, patterns.
- Used by IDEs (VSCode) to provide autocomplete and validation for K8s manifests, Ansible, etc.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "name": {"type": "string"},
    "replicas": {"type": "integer", "minimum": 1},
    "enabled": {"type": "boolean"}
  },
  "required": ["name", "replicas"]
}
```

- Tools that use JSON Schema:
  - VSCode YAML extension (validates K8s, Ansible, Docker Compose)
  - `ajv` CLI for standalone validation
  - Kubernetes API server (validates manifests against OpenAPI/JSON Schema)

Related notes: [003-tools-and-validation](./003-tools-and-validation.md)

### jq Basics for DevOps
```bash
# identity: pretty-print JSON
echo '{"a":1}' | jq '.'

# select a field
echo '{"name":"web","port":80}' | jq '.name'         # "web"

# raw output (no quotes)
echo '{"name":"web"}' | jq -r '.name'                 # web

# array indexing
echo '{"items":["a","b","c"]}' | jq '.items[0]'       # "a"

# iterate array
echo '{"items":["a","b","c"]}' | jq '.items[]'        # "a" "b" "c"

# nested access
echo '{"meta":{"labels":{"app":"web"}}}' | jq '.meta.labels.app'

# filter with select
cat pods.json | jq '.items[] | select(.status.phase == "Running") | .metadata.name'

# construct new object
cat pods.json | jq '.items[] | {name: .metadata.name, status: .status.phase}'
```

Related notes: [003-tools-and-validation](./003-tools-and-validation.md)
- `jq` is a command-line JSON processor -- essential for scripting with APIs and tool output.
- Key operations:

```bash
# count array elements
jq '.items | length' resources.json

# get all keys of an object
jq 'keys' config.json

# merge two JSON objects
jq -s '.[0] * .[1]' base.json override.json
```
