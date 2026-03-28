# Helm Templating

# Overview
- **Why it exists** — Static YAML cannot adapt to different environments or configurations. Templating lets one chart generate environment-specific manifests by injecting values at render time, eliminating duplication and manual edits.
- **What it is** — Go's `text/template` engine embedded in Helm, extended with Sprig functions and Helm built-ins. Templates reference `.Values`, `.Release`, `.Chart`, and call helpers to produce final Kubernetes YAML.
- **One-liner** — Helm templating transforms parameterized YAML skeletons into environment-specific Kubernetes manifests by injecting values at install time.

# Architecture

```
Value Resolution Pipeline
─────────────────────────

Chart defaults (values.yaml)
        +
External file  (-f custom-values.yaml)
        +
CLI overrides  (--set key=value)
        ↓
  Merged value tree  (.Values.*)
        ↓
  Go template engine
        ↓
  Sprig / Helm built-in functions
        ↓
  Rendered Kubernetes YAML
        ↓
  kubectl apply (or dry-run)
```

# Mental Model

Override hierarchy — last writer wins, CLI is always highest priority:

```
values.yaml  (chart defaults, lowest priority)
    ↓  overridden by
-f base-values.yaml
    ↓  overridden by
-f prod-values.yaml
    ↓  overridden by
--set key=value  (CLI, highest priority)
```

Any key not overridden falls back to the chart default in values.yaml.

# Core Building Blocks

### Template Syntax Basics
- **Why it exists** — You need a way to reference values and built-in metadata inside YAML files without breaking YAML syntax.
- **What it is** — Double-brace `{{ }}` expressions that reference the values tree, release context, or chart metadata. Dash variants (`{{-` / `-}}`) trim surrounding whitespace to keep output clean.
- **One-liner** — `{{ }}` expressions are the injection points that turn static YAML into dynamic templates.

| Syntax | Purpose | Example |
|---|---|---|
| `{{ .Values.key }}` | Value from values.yaml | `{{ .Values.image.repository }}` |
| `{{ .Release.Name }}` | Release name set at install | `{{ .Release.Name }}-app` |
| `{{ .Release.Namespace }}` | Target namespace | `namespace: {{ .Release.Namespace }}` |
| `{{ .Chart.Name }}` | Chart name from Chart.yaml | `app: {{ .Chart.Name }}` |
| `{{ .Chart.Version }}` | Chart version | `version: {{ .Chart.Version }}` |
| `{{ include "helper" . }}` | Call a named helper template | `{{ include "mychart.fullname" . }}` |
| `{{- expr }}` | Trim whitespace/newline before | Removes blank lines in output |
| `{{ expr -}}` | Trim whitespace/newline after | Removes blank lines in output |

```yaml
# Basic value injection
metadata:
  name: {{ .Release.Name }}-app
  namespace: {{ .Release.Namespace }}
  labels:
    app: {{ .Chart.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
```

### Conditionals
- **Why it exists** — Not all resources or fields should exist in every environment; feature flags let operators turn pieces on or off via values.
- **What it is** — `{{- if }}` / `{{- else }}` / `{{- end }}` blocks that include or exclude YAML sections based on a value being truthy, falsy, or matching a condition.
- **One-liner** — Conditionals gate entire YAML blocks or fields based on values, enabling feature-flag-driven deployments.

```yaml
# Conditionally render entire resource
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "mychart.fullname" . }}
spec:
  rules:
  - host: {{ .Values.ingress.host }}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: {{ include "mychart.fullname" . }}
            port:
              number: {{ .Values.service.port }}
{{- end }}

# Conditional field within a resource
{{- if .Values.resources }}
resources:
  {{- toYaml .Values.resources | nindent 10 }}
{{- end }}

# Scoped block with {{- with }} (sets . to the given value)
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 8 }}
{{- end }}
```

### Loops
- **Why it exists** — Lists of items (env vars, ports, config keys, hosts) are dynamic by nature; hardcoding them breaks reusability.
- **What it is** — `{{- range }}` / `{{- end }}` blocks that iterate over a list or map from `.Values`, exposing each element as `.` inside the loop body.
- **One-liner** — `range` loops iterate over values lists or maps to generate repeated YAML blocks.

```yaml
# Loop over a list of config key/value pairs
# values.yaml:
#   configKeys:
#     - name: DB_HOST
#       value: "postgres"
#     - name: APP_ENV
#       value: "production"

apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "mychart.fullname" . }}
data:
  {{- range .Values.configKeys }}
  {{ .name }}: {{ .value | quote }}
  {{- end }}

# Loop over a map
{{- range $key, $val := .Values.annotations }}
{{ $key }}: {{ $val | quote }}
{{- end }}
```

### Helper Functions
- **Why it exists** — Common operations like name truncation, label generation, and YAML serialization would be duplicated in every template without shared helpers.
- **What it is** — Named templates defined in `_helpers.tpl` (called via `{{ include }}`), plus Sprig stdlib functions (`quote`, `upper`, `default`, `trunc`, `trimSuffix`) and Helm built-ins (`toYaml`, `nindent`, `contains`).
- **One-liner** — Helper functions and named templates are the reusable building blocks that keep individual templates clean and DRY.

Commonly used functions:
```yaml
# toYaml + nindent — serialize a values sub-tree as indented YAML
resources:
  {{- toYaml .Values.resources | nindent 10 }}

# default — fallback when a value is empty
image: {{ .Values.image.tag | default "latest" }}

# quote — force string quoting (prevents YAML type coercion)
env: {{ .Values.environment | quote }}

# trunc / trimSuffix — safe Kubernetes name generation
{{- $name | trunc 63 | trimSuffix "-" }}

# contains — string membership test
{{- if contains "NodePort" .Values.service.type }}

# printf — string formatting
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 }}
```

Calling a named helper:
```yaml
# defined in _helpers.tpl
{{- define "mychart.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

# used in any template
metadata:
  name: {{ include "mychart.fullname" . }}
```

### Environment-Specific Patterns
- **Why it exists** — Real deployments require different replica counts, resource limits, feature flags, and endpoints per environment without maintaining duplicate charts.
- **What it is** — A pattern of layered values files (one per environment) combined with a single chart; CLI `--set` provides final overrides for one-off changes.
- **One-liner** — Separate values files per environment + the same chart = safe, auditable, environment-specific deployments.

```bash
# One chart, one values file per environment
helm install myapp ./mychart -f values-dev.yaml
helm install myapp ./mychart -f values-staging.yaml
helm install myapp ./mychart -f values-prod.yaml

# Layer a base + environment-specific override
helm install myapp ./mychart -f base-values.yaml -f values-prod.yaml

# Emergency one-off override on top of everything
helm upgrade myapp ./mychart -f values-prod.yaml --set replicaCount=10

# Preview rendered output for a specific environment before applying
helm template myapp ./mychart -f values-prod.yaml
```

Example values-prod.yaml:
```yaml
replicaCount: 5
image:
  tag: "2.1.0"
ingress:
  enabled: true
  host: app.example.com
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2
    memory: 2Gi
```

# Troubleshooting

### Template Renders Blank or Unexpected Output
- Render with debug to see the value tree: `helm template mychart --debug`
- Check the exact value path: confirm `.Values.image.tag` matches the key in values.yaml
- Whitespace trimming side effects: add or remove `{{-` / `-}}` dashes carefully

### Values Override Not Applying
- Check priority: `--set` beats `-f file` beats values.yaml
- Inspect merged values used in the render:
  ```bash
  helm template mychart -f custom-values.yaml --debug 2>&1 | head -30
  ```
- Verify key path matches exactly (YAML is case-sensitive)

### YAML Indentation Errors After toYaml
- Always pair `toYaml` with `nindent` matching the current indentation level:
  ```yaml
  resources:
    {{- toYaml .Values.resources | nindent 4 }}   # top-level key = 4 spaces
  ```
- Use `helm template mychart | kubectl apply -f - --dry-run=client` to catch YAML structure errors

### Conditional Block Always Renders / Never Renders
- Test the value directly: `helm template mychart --set ingress.enabled=true`
- Remember: empty string `""`, `0`, `false`, and `null` are all falsy in Go templates
- Use `{{- if .Values.someKey }}` for existence checks, not equality — use `{{- if eq .Values.someKey "value" }}` for equality
