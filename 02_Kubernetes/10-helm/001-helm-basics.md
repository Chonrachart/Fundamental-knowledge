# Helm Basics

## Overview
**Why it exists** — Managing raw Kubernetes YAML gets repetitive and hard to version. You need to maintain separate config files for dev/staging/prod, handle dependencies, and deploy updates consistently. Helm packages, versions, and deploys Kubernetes applications using templated manifests and configuration management.

**What it is** — A package manager for Kubernetes that bundles YAML templates with configuration values, version control, and release management. Helm acts like apt/npm but for Kubernetes applications.

**One-liner** — Helm = Kubernetes package manager that templates YAML, manages releases, and enables easy upgrades and rollbacks.

## Architecture (ASCII where relevant)

```
Helm Workflow
─────────────

1. Chart Repository (remote or local)
   ↓
2. helm install/upgrade
   ↓
3. Values Injection (from values.yaml or CLI)
   ↓
4. Template Rendering ({{ .Values.* }} → final YAML)
   ↓
5. kubectl apply (to cluster)
   ↓
6. Release Created (tracked by Helm in kube-system)
```

## Mental Model

Think of Helm as **templated package management**:
- **Chart** = source code (template + metadata)
- **Release** = compiled binary (deployed instance)
- **Repository** = package registry
- **Values** = configuration that gets baked into templates

One chart can be installed many times as different releases (e.g., `nginx-prod` and `nginx-staging` from the same nginx chart).

## Core Building Blocks

### Chart
**Why it exists** — Provides a standardized, reusable package format for Kubernetes applications with metadata, version control, and dependency management.

**What it is** — A directory structure containing YAML templates, a metadata file (Chart.yaml), default configuration (values.yaml), and optional dependency charts. Charts can be packaged as .tgz archives and stored in repositories.

**One-liner** — A chart is a template + metadata package for a Kubernetes application.

### Release
**Why it exists** — Allows the same chart to be deployed multiple times with different configurations without conflicts or collision.

**What it is** — A named instance of a chart deployed to a cluster. Helm tracks releases in the cluster and maintains a history of revisions, enabling easy upgrades and rollbacks.

**One-liner** — A release is a deployed instance of a chart with a unique name and version history.

### Repository
**Why it exists** — Centralizes and distributes charts so teams can discover, share, and version application packages across organizations.

**What it is** — A collection of charts, often hosted remotely (like Bitnami, stable, etc.) or stored locally. Repositories are indexed so `helm search` can discover charts.

**One-liner** — A repository is a searchable registry of Helm charts, like npm for Kubernetes.

### Values
**Why it exists** — Separates configuration from templates so the same chart can be deployed across environments without modifying source YAML.

**What it is** — YAML configuration injected into templates at install/upgrade time. Can come from default values.yaml, CLI `--set` flags, or separate YAML files.

**One-liner** — Values are template configuration passed to a chart at install time.

## Core Commands

### Repository Management

```bash
# Add a chart repository
helm repo add bitnami https://charts.bitnami.com/bitnami

# List configured repositories
helm repo list

# Update local cache of remote repositories
helm repo update

# Search for a chart in repositories
helm search repo bitnami/nginx

# View available versions of a chart
helm search repo bitnami/nginx --versions
```

### Installation & Inspection

```bash
# Install a chart with release name 'my-nginx'
helm install my-nginx bitnami/nginx

# Install to a specific namespace
helm install my-nginx bitnami/nginx -n my-namespace

# Preview what would be installed (dry-run)
helm install my-nginx bitnami/nginx --dry-run --debug

# Show default values for a chart
helm show values bitnami/nginx

# Show the Chart.yaml metadata
helm show chart bitnami/nginx

# Render templates locally without installing
helm template my-nginx bitnami/nginx
```

### Release Management

```bash
# List all releases in the cluster
helm list

# List releases in a specific namespace
helm list -n my-namespace

# Get status of a release
helm status my-nginx

# Get detailed info about a release
helm get values my-nginx        # currently set values
helm get manifest my-nginx      # rendered YAML deployed to cluster
helm get all my-nginx           # all above combined

# View release revision history
helm history my-nginx
```

### Updates & Rollbacks

```bash
# Upgrade a release with new values
helm upgrade my-nginx bitnami/nginx

# Upgrade with CLI flags
helm upgrade my-nginx bitnami/nginx --set replicaCount=3 --set image.tag=1.2.3

# Upgrade with a values file
helm upgrade my-nginx bitnami/nginx -f custom-values.yaml

# Rollback to a previous revision
helm rollback my-nginx 1        # rollback to revision 1
helm rollback my-nginx          # rollback to previous revision

# Uninstall a release
helm uninstall my-nginx

# Uninstall but keep release history (for rollback)
helm uninstall my-nginx --keep-history
```

### Chart Development

```bash
# Create a new chart from template
helm create mychart

# Validate chart syntax and structure
helm lint mychart

# Package chart into a .tgz archive
helm package mychart            # creates mychart-0.1.0.tgz

# Install from local chart directory
helm install myapp ./mychart

# Install from packaged chart
helm install myapp ./mychart-0.1.0.tgz
```

## Overriding Values

Values can be overridden at install/upgrade time in priority order (CLI highest priority):

```bash
# Override with a values file
helm install myapp bitnami/nginx -f prod-values.yaml

# Override with CLI --set (simple types)
helm install myapp bitnami/nginx --set replicaCount=5
helm install myapp bitnami/nginx --set image.tag=1.2.3
helm install myapp bitnami/nginx --set image.tag=1.2.3 --set replicaCount=5

# Override with --set-string (force string type, avoid parsing)
helm install myapp bitnami/nginx --set-string someKey=stringval

# Combine file + CLI (CLI takes precedence)
helm install myapp bitnami/nginx -f base-values.yaml --set replicaCount=10
```

## Common Patterns

### Installing Multiple Releases from Same Chart

```bash
# Deploy nginx for web tier and API tier
helm install nginx-web bitnami/nginx --set replicaCount=3
helm install nginx-api bitnami/nginx --set replicaCount=2 --set port=8080
```

### Viewing Rendered YAML Before Installation

```bash
# See exactly what will be deployed
helm template my-nginx bitnami/nginx --set replicaCount=3
```

### Environment-Specific Deployments

```bash
# Use separate values files per environment
helm install myapp ./mychart -f values-dev.yaml
helm install myapp ./mychart -f values-prod.yaml

# Or use CLI overrides
helm install myapp ./mychart --set environment=production --set replicas=5
```

## Troubleshooting

### Release Deployment Failed

1. Check if release exists:
   ```bash
   helm list
   helm status my-nginx
   ```

2. Review the deployed manifest:
   ```bash
   helm get manifest my-nginx
   ```

3. Check pod status:
   ```bash
   kubectl get pods -n default
   kubectl describe pod <pod-name>
   kubectl logs <pod-name>
   ```

4. Dry-run before upgrading to validate:
   ```bash
   helm install my-nginx bitnami/nginx --dry-run --debug
   ```

### Chart Not Found in Repository

1. List configured repositories:
   ```bash
   helm repo list
   ```

2. Update repository index:
   ```bash
   helm repo update
   ```

3. Search again:
   ```bash
   helm search repo nginx
   ```

4. If still not found, add the repository:
   ```bash
   helm repo add bitnami https://charts.bitnami.com/bitnami
   helm repo update
   ```

### Need to Revert to Previous Release

1. View revision history:
   ```bash
   helm history my-nginx
   ```

2. Rollback to specific revision:
   ```bash
   helm rollback my-nginx 1
   ```

3. Verify rollback:
   ```bash
   helm status my-nginx
   helm get manifest my-nginx
   ```

### Values Not Being Applied

1. Verify which values are set in the release:
   ```bash
   helm get values my-nginx
   ```

2. Check default values in the chart:
   ```bash
   helm show values bitnami/nginx
   ```

3. Re-upgrade with correct values:
   ```bash
   helm upgrade my-nginx bitnami/nginx --set replicaCount=5 --set image.tag=1.2.3
   ```

### Template Rendering Issues

1. Render templates locally to see output:
   ```bash
   helm template my-nginx bitnami/nginx
   ```

2. Render with specific values:
   ```bash
   helm template my-nginx bitnami/nginx -f custom-values.yaml
   ```

3. Check for validation errors:
   ```bash
   helm lint mychart
   ```
