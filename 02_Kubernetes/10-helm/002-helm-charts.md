# Helm Charts

# Overview
- **Why it exists** — Kubernetes applications need to be deployed across multiple environments with different configs (dev/staging/prod). Charts standardize this by providing reusable, parameterized templates so the same application package can be configured differently without duplicating YAML.

- **What it is** — A structured directory containing Kubernetes YAML templates, default configuration values, metadata, and helper functions. Charts enable templating, versioning, and dependency management for Kubernetes applications.

- **One-liner** — A chart is a Helm package that combines templates, configuration, and metadata to enable reusable Kubernetes application deployments.

### Architecture (ASCII where relevant)

```
Chart Directory Structure
─────────────────────────

mychart/
├── Chart.yaml              # Chart metadata (name, version, description)
├── values.yaml             # Default configuration values for templates
├── values.schema.json      # (Optional) JSON schema validating values
├── charts/                 # Subdirectory for chart dependencies
│   └── dependency-chart/
├── templates/              # Kubernetes YAML templates
│   ├── deployment.yaml     # Deployment template
│   ├── service.yaml        # Service template
│   ├── configmap.yaml      # ConfigMap template
│   ├── ingress.yaml        # Ingress template
│   ├── _helpers.tpl        # Reusable template snippets/functions
│   ├── NOTES.txt           # Post-install instructions
│   └── tests/              # (Optional) Test templates
├── .helmignore             # Files to exclude from packaging
├── LICENSE                 # License file
├── README.md               # Chart documentation
└── .gitignore              # Git ignore patterns

Template Rendering Flow
──────────────────────

values.yaml + CLI overrides
         ↓
    Merge values
         ↓
Load templates from templates/
         ↓
Inject values into {{ }} placeholders
         ↓
Include helpers from _helpers.tpl
         ↓
Render final YAML
         ↓
Apply to cluster with kubectl
```

# Mental Model

A Helm chart is like a **parameterized YAML package**:
- Think of Chart.yaml as the "package.json" (metadata)
- Think of values.yaml as "environment variables" (configuration)
- Think of templates/ as "source code with placeholders"
- Think of the rendering process as "template compilation"

The chart itself is **immutable** — values change, not the chart code.

# Core Building Blocks

### Chart.yaml
- **Why it exists** — Provides metadata about the chart so Helm can identify, version, and describe what it packages.

- **What it is** — A YAML file containing chart metadata such as name, version, description, maintainers, and optional dependencies. This is the "identity card" of the chart.

- **One-liner** — Chart.yaml defines chart metadata and versioning.

```yaml
apiVersion: v2                          # Helm 3 format
name: mychart                           # Chart name (must match directory)
description: A Helm chart for MyApp     # Description
type: application                       # 'application' or 'library'
version: 0.1.0                          # Chart version (SemVer)
appVersion: "1.0"                       # Application version being packaged
maintainers:
  - name: Your Name
    email: you@example.com
dependencies:                           # Chart dependencies
  - name: postgresql
    version: "11.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    alias: db                           # Alias for accessing in templates
```

### values.yaml
- **Why it exists** — Provides default configuration that templates can reference, allowing charts to be used out-of-the-box while remaining customizable.

- **What it is** — A YAML file defining default values for all template placeholders. Can be overridden at install/upgrade time via CLI flags or additional YAML files.

- **One-liner** — values.yaml provides default configuration injected into templates.

```yaml
# values.yaml - Default values for templates

replicaCount: 1
namespace: default

image:
  repository: nginx
  tag: "1.21"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80
  targetPort: 8080

ingress:
  enabled: false
  className: nginx
  host: example.com

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

nodeSelector: {}
tolerations: []
affinity: {}

# Feature flags
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
```

### templates/ Directory
- **Why it exists** — Separates template definitions from configuration, enabling the same chart to deploy across multiple environments by injecting different values.

- **What it is** — A directory containing Kubernetes YAML manifest templates with placeholders (`{{ }}` syntax) for values injection. When `helm install` runs, values are injected into these templates to produce final YAML.

- **One-liner** — templates/ contains parameterized Kubernetes manifests.

#### Templates Syntax Building Blocks

| Syntax | Purpose | Example |
|--------|---------|---------|
| `{{ .Values.key }}` | Reference a value from values.yaml | `{{ .Values.image.repository }}` |
| `{{ .Release.Name }}` | Built-in release name | `{{ .Release.Name }}-pod` |
| `{{ .Release.Namespace }}` | Deployment namespace | `namespace: {{ .Release.Namespace }}` |
| `{{ .Chart.Name }}` | Chart name from Chart.yaml | `app: {{ .Chart.Name }}` |
| `{{ .Chart.Version }}` | Chart version | `version: {{ .Chart.Version }}` |
| `{{ if .Values.enabled }} ... {{ end }}` | Conditional block | `{{ if .Values.ingress.enabled }}...{{ end }}` |
| `{{ range .Values.items }}...{{ end }}` | Loop over list values | Loop through array |
| `{{ include "name" . }}` | Call a helper template | `{{ include "mychart.fullname" . }}` |
| `{{- expr }}` | Trim whitespace before | Removes blank lines |
| `{{ expr -}}` | Trim whitespace after | Removes blank lines |
| `{{- with .Values.nodeSelector }} ... {{- end }}` | Scoped block | Set context to selector |

#### Example Deployment Template

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "mychart.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    app: {{ .Chart.Name }}
    version: {{ .Chart.Version }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Chart.Name }}
  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - name: http
          containerPort: {{ .Values.service.targetPort }}
        {{- if .Values.resources }}
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
        {{- end }}
        {{- with .Values.nodeSelector }}
        nodeSelector:
          {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- with .Values.affinity }}
        affinity:
          {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- with .Values.tolerations }}
        tolerations:
          {{- toYaml . | nindent 8 }}
        {{- end }}
```

#### Example Service Template

```yaml
# templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "mychart.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    app: {{ .Chart.Name }}
spec:
  type: {{ .Values.service.type }}
  ports:
  - port: {{ .Values.service.port }}
    targetPort: {{ .Values.service.targetPort }}
    protocol: TCP
    name: http
  selector:
    app: {{ .Chart.Name }}
```

### _helpers.tpl
- **Why it exists** — Defines reusable template snippets to avoid duplication of common patterns across multiple manifests.

- **What it is** — A template file (not rendered directly to Kubernetes) containing helper functions and partial templates that other templates include via `{{ include }}`.

- **One-liner** — _helpers.tpl provides reusable template functions to avoid duplication.

```yaml
# templates/_helpers.tpl

{{/*
Expand the name of the chart.
*/}}
{{- define "mychart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "mychart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mychart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mychart.labels" -}}
helm.sh/chart: {{ include "mychart.chart" . }}
{{ include "mychart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mychart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mychart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

### NOTES.txt
- **Why it exists** — Provides post-installation instructions and helpful information printed to the user after `helm install` or `helm upgrade` completes.

- **What it is** — A template file (supports the same `{{ }}` syntax) that outputs text instructions. Helm displays this after successful installation.

- **One-liner** — NOTES.txt displays post-installation instructions to the user.

```
# templates/NOTES.txt

1. Get the application URL by running these commands:
{{- if .Values.ingress.enabled }}
  https://{{ .Values.ingress.host }}
{{- else if contains "NodePort" .Values.service.type }}
  export NODE_PORT=$(kubectl get --namespace {{ .Release.Namespace }} -o jsonpath="{.spec.ports[0].nodePort}" services {{ include "mychart.fullname" . }})
  export NODE_IP=$(kubectl get nodes --namespace {{ .Release.Namespace }} -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT
{{- else if contains "LoadBalancer" .Values.service.type }}
  NOTE: It may take a few minutes for the LoadBalancer IP to be available.
  You can watch the status by running 'kubectl get --namespace {{ .Release.Namespace }} svc -w {{ include "mychart.fullname" . }}'
{{- else if contains "ClusterIP" .Values.service.type }}
  kubectl port-forward --namespace {{ .Release.Namespace }} svc/{{ include "mychart.fullname" . }} 8080:80
  echo "Visit http://127.0.0.1:8080 to use your application"
{{- end }}

2. Watch the deployment status:
  kubectl rollout status deployment/{{ include "mychart.fullname" . }} -n {{ .Release.Namespace }}

3. View pod logs:
  kubectl logs -n {{ .Release.Namespace }} -l app={{ .Chart.Name }}
```

### Value Overriding

Values can be overridden at install/upgrade time using multiple methods (CLI highest priority):

```bash
# Override with external values file
helm install myapp ./mychart -f custom-values.yaml
helm install myapp ./mychart -f values-prod.yaml

# Override with CLI --set flag
helm install myapp ./mychart --set replicaCount=3
helm install myapp ./mychart --set image.tag=1.2.3
helm install myapp ./mychart --set image.tag=1.2.3 --set replicaCount=5

# Override with --set-string (force string, prevent parsing as YAML type)
helm install myapp ./mychart --set-string someKey=stringval

# Multiple files (later files override earlier ones)
helm install myapp ./mychart -f base-values.yaml -f prod-overrides.yaml

# Combine files + CLI (CLI takes precedence)
helm install myapp ./mychart -f base-values.yaml --set replicaCount=10
```

### Chart Development Commands

### Create a New Chart

```bash
# Generate a basic chart structure
helm create mychart

# List generated files
ls -la mychart/
```

### Validate Chart Syntax

```bash
# Check chart structure, templates, and values
helm lint mychart

# Show any validation issues
helm lint mychart --strict    # Fail on warnings too
```

### Render Templates Locally

```bash
# See final rendered YAML without installing to cluster
helm template mychart

# Render with custom values
helm template mychart -f custom-values.yaml

# Render with CLI overrides
helm template mychart --set replicaCount=5 --set image.tag=1.2.3

# Output formatted for review
helm template mychart > rendered.yaml
cat rendered.yaml
```

### Package Chart

```bash
# Create .tgz archive for distribution or storage
helm package mychart

# Output: mychart-0.1.0.tgz

# Package with specific version override
helm package mychart --version 1.0.0

# Create chart repository index (for multiple charts)
helm repo index ./charts    # creates charts/index.yaml
```

### Install from Packaged Chart

```bash
# Install from local .tgz file
helm install myapp ./mychart-0.1.0.tgz

# Install from remote .tgz URL
helm install myapp https://example.com/charts/mychart-0.1.0.tgz
```

### Common Patterns

### Conditional Features

```yaml
# templates/ingress.yaml
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
```

### Looping Over Lists

```yaml
# templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "mychart.fullname" . }}
data:
  {{- range .Values.configKeys }}
  {{ .name }}: {{ .value | quote }}
  {{- end }}
```

### Resource Requests/Limits

```yaml
# Part of templates/deployment.yaml
{{- if .Values.resources }}
resources:
  {{- toYaml .Values.resources | nindent 10 }}
{{- end }}

# In values.yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### Environment-Specific Deployments

```bash
# Deploy same chart to different environments
helm install myapp-dev ./mychart -f values-dev.yaml
helm install myapp-staging ./mychart -f values-staging.yaml
helm install myapp-prod ./mychart -f values-prod.yaml

# Or with CLI overrides
helm install myapp ./mychart --set environment=production --set replicas=5
```

# Troubleshooting

### Template Syntax Error

1. Validate chart structure:
   ```bash
   helm lint mychart
   ```

2. Render templates to see errors:
   ```bash
   helm template mychart --debug
   ```

3. Check template syntax (common issues: missing spaces, wrong variable names):
   ```bash
   helm template mychart
   # Look for error output
   ```

### Values Not Being Injected

1. Check what values are actually set:
   ```bash
   helm template mychart --debug
   # Review the values injected into templates
   ```

2. Verify default values in values.yaml:
   ```bash
   helm show values ./mychart
   ```

3. Verify overrides are correct:
   ```bash
   helm template mychart --set replicaCount=5
   # Check if replicaCount: 5 appears in output
   ```

### Chart Installation Fails

1. Do a dry-run to see what would be deployed:
   ```bash
   helm install myapp ./mychart --dry-run --debug
   ```

2. Check for missing dependencies:
   ```bash
   helm dependency list ./mychart
   helm dependency update ./mychart
   ```

3. Validate rendered YAML manually:
   ```bash
   helm template myapp ./mychart > rendered.yaml
   kubectl apply -f rendered.yaml --dry-run=client
   ```

### Need to Debug Template Rendering

1. Render with debug output:
   ```bash
   helm template mychart --debug
   ```

2. Render to file for inspection:
   ```bash
   helm template mychart > rendered.yaml
   cat rendered.yaml
   ```

3. Test with different values:
   ```bash
   helm template mychart -f test-values.yaml --debug
   ```

### Chart Dependencies Not Installing

1. Check chart dependencies:
   ```bash
   helm dependency list ./mychart
   ```

2. Update dependencies (fetch them):
   ```bash
   helm dependency update ./mychart
   ```

3. Verify charts/ directory is populated:
   ```bash
   ls -la ./mychart/charts/
   ```

4. Reinstall with dependencies:
   ```bash
   helm install myapp ./mychart
   ```
