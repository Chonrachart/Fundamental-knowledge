# Helm Chart Structure

# Overview
- **Why it exists** — A consistent directory layout makes charts portable, discoverable, and toolable. Any Helm user can open an unfamiliar chart and immediately know where the metadata, config, and templates live.
- **What it is** — A prescribed set of files and directories that Helm reads when rendering or packaging a chart: Chart.yaml (identity), values.yaml (defaults), templates/ (manifests), helpers, and docs.
- **One-liner** — Chart structure is the contract between chart authors and Helm: the right files in the right places means Helm can install, lint, package, and render without extra config.

# Architecture

```
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
│   ├── NOTES.txt           # Post-install instructions shown to user
│   └── tests/              # (Optional) Test templates
├── .helmignore             # Files to exclude from packaging
├── LICENSE
└── README.md
```

# Mental Model

Think of the chart as a **parameterized YAML package** compiled at render time:

- **Chart.yaml** = package.json (identity and version)
- **values.yaml** = environment variables (configuration defaults)
- **templates/** = source code with placeholders (rendered at install time)
- **_helpers.tpl** = shared utility functions (included by other templates)
- **NOTES.txt** = post-install stdout (user-facing instructions)

The chart itself is immutable — values change, not the chart code.

```
values.yaml  +  CLI overrides
        ↓   merge
Load templates from templates/
        ↓
Inject values into {{ }} placeholders
        ↓
Include helpers from _helpers.tpl
        ↓
Render final YAML  →  kubectl apply
```

# Core Building Blocks

### Chart.yaml
- **Why it exists** — Provides metadata so Helm can identify, version, and describe what the chart packages; also declares dependencies.
- **What it is** — A required YAML file at the chart root containing name, version, description, type, maintainers, and optional dependency declarations.
- **One-liner** — Chart.yaml is the identity card and version manifest of the chart.

```yaml
apiVersion: v2                          # Helm 3 format
name: mychart                           # Must match directory name
description: A Helm chart for MyApp
type: application                       # 'application' or 'library'
version: 0.1.0                          # Chart version (SemVer)
appVersion: "1.0"                       # Version of the packaged application
maintainers:
  - name: Your Name
    email: you@example.com
dependencies:
  - name: postgresql
    version: "11.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    alias: db
```

### values.yaml
- **Why it exists** — Provides defaults for all template placeholders so the chart works out-of-the-box while remaining fully customizable at install time.
- **What it is** — A YAML file at the chart root defining default values; every `{{ .Values.* }}` reference in templates resolves here unless overridden.
- **One-liner** — values.yaml is the default configuration layer injected into every template.

```yaml
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

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
```

### templates/ Directory
- **Why it exists** — Separates template definitions from configuration, enabling the same chart to render different Kubernetes manifests per environment.
- **What it is** — A directory of Kubernetes YAML files with Go template placeholders (`{{ }}`). At install time Helm injects values and renders each file into valid Kubernetes YAML.
- **One-liner** — templates/ holds parameterized Kubernetes manifests rendered at install/upgrade time.

Example deployment template:
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
        - containerPort: {{ .Values.service.targetPort }}
        {{- if .Values.resources }}
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
        {{- end }}
```

Example service template:
```yaml
# templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "mychart.fullname" . }}
  namespace: {{ .Release.Namespace }}
spec:
  type: {{ .Values.service.type }}
  ports:
  - port: {{ .Values.service.port }}
    targetPort: {{ .Values.service.targetPort }}
    protocol: TCP
  selector:
    app: {{ .Chart.Name }}
```

### _helpers.tpl
- **Why it exists** — Defines reusable named template snippets to avoid duplicating common patterns (e.g., full resource name, label sets) across multiple manifests.
- **What it is** — A file prefixed with `_` so Helm skips it during direct rendering; contains `{{- define "name" }}` blocks that other templates call via `{{ include "name" . }}`.
- **One-liner** — _helpers.tpl is the shared utility library for all templates in the chart.

```yaml
# templates/_helpers.tpl

{{- define "mychart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

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

{{- define "mychart.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "mychart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

### NOTES.txt
- **Why it exists** — Gives users immediate, context-aware post-installation guidance without having to read documentation separately.
- **What it is** — A template file in templates/ that supports `{{ }}` syntax; Helm prints its rendered output to stdout after a successful `helm install` or `helm upgrade`.
- **One-liner** — NOTES.txt renders and prints post-install instructions to the user.

```
# templates/NOTES.txt

1. Get the application URL:
{{- if .Values.ingress.enabled }}
  https://{{ .Values.ingress.host }}
{{- else if contains "NodePort" .Values.service.type }}
  export NODE_PORT=$(kubectl get --namespace {{ .Release.Namespace }} -o jsonpath="{.spec.ports[0].nodePort}" services {{ include "mychart.fullname" . }})
  export NODE_IP=$(kubectl get nodes --namespace {{ .Release.Namespace }} -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT
{{- else if contains "LoadBalancer" .Values.service.type }}
  kubectl get --namespace {{ .Release.Namespace }} svc -w {{ include "mychart.fullname" . }}
{{- else }}
  kubectl port-forward --namespace {{ .Release.Namespace }} svc/{{ include "mychart.fullname" . }} 8080:80
{{- end }}

2. Watch rollout status:
  kubectl rollout status deployment/{{ include "mychart.fullname" . }} -n {{ .Release.Namespace }}

3. View pod logs:
  kubectl logs -n {{ .Release.Namespace }} -l app={{ .Chart.Name }}
```

# Troubleshooting

### Template Syntax Error
- Validate chart structure: `helm lint mychart`
- Render with debug output to see the error location: `helm template mychart --debug`
- Common causes: missing spaces around `}}`, wrong variable path, undefined helper name

### Values Not Being Injected Into Templates
- Debug-render to see injected values: `helm template mychart --debug`
- Check default values in the chart: `helm show values ./mychart`
- Test a specific override: `helm template mychart --set replicaCount=5` and confirm it appears in output

### Chart Installation Fails
- Dry-run to see what would be sent to the API server: `helm install myapp ./mychart --dry-run --debug`
- Check for missing dependencies:
  ```bash
  helm dependency list ./mychart
  helm dependency update ./mychart
  ```
- Validate rendered YAML against the cluster:
  ```bash
  helm template myapp ./mychart > rendered.yaml
  kubectl apply -f rendered.yaml --dry-run=client
  ```

### Chart Dependencies Not Downloading
- List declared dependencies: `helm dependency list ./mychart`
- Fetch them into charts/: `helm dependency update ./mychart`
- Confirm charts/ is populated: `ls -la ./mychart/charts/`
- Reinstall after fetching: `helm install myapp ./mychart`
