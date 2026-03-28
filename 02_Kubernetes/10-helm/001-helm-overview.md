# Helm Overview

# Overview
- **Why it exists** — Managing raw Kubernetes YAML gets repetitive and hard to version. You need to maintain separate config files for dev/staging/prod, handle dependencies, and deploy updates consistently. Helm packages, versions, and deploys Kubernetes applications using templated manifests and configuration management.
- **What it is** — A package manager for Kubernetes that bundles YAML templates with configuration values, version control, and release management. Helm acts like apt/npm but for Kubernetes applications.
- **One-liner** — Helm = Kubernetes package manager that templates YAML, manages releases, and enables easy upgrades and rollbacks.

# Architecture

```
Helm Component Flow
───────────────────

Helm CLI  (helm install / upgrade / rollback)
    ↓
Helm Library  (template engine, release tracker)
    ↓
Kubernetes API  (kubectl apply under the hood)
    ↓
Cluster  (Deployments, Services, ConfigMaps …)

Release History stored in cluster Secrets (kube-system or target namespace)
```

# Mental Model

- **Chart** = source code (templates + metadata)
- **Release** = compiled binary (deployed instance of a chart)
- **Repository** = package registry (like npm registry for Kubernetes)
- **Values** = configuration baked into templates at install time

One chart can be installed many times as different releases (e.g., `nginx-prod` and `nginx-staging` from the same nginx chart).

```
Chart  ──(helm install + values)──▶  Release
         (name it, configure it)      (tracked in cluster)
```

# Core Building Blocks

### Chart
- **Why it exists** — Provides a standardized, reusable package format for Kubernetes applications with metadata, version control, and dependency management.
- **What it is** — A directory structure containing YAML templates, a metadata file (Chart.yaml), default configuration (values.yaml), and optional dependency charts. Charts can be packaged as .tgz archives and stored in repositories.
- **One-liner** — A chart is a template + metadata package for a Kubernetes application.

Example — install a public chart:
```bash
helm install my-nginx bitnami/nginx
```

### Release
- **Why it exists** — Allows the same chart to be deployed multiple times with different configurations without conflicts.
- **What it is** — A named instance of a chart deployed to a cluster. Helm tracks releases in the cluster and maintains a history of revisions, enabling upgrades and rollbacks.
- **One-liner** — A release is a deployed instance of a chart with a unique name and version history.

Example — two releases from the same chart:
```bash
helm install nginx-web bitnami/nginx --set replicaCount=3
helm install nginx-api bitnami/nginx --set replicaCount=2 --set port=8080
```

### Repository
- **Why it exists** — Centralizes and distributes charts so teams can discover, share, and version application packages across organizations.
- **What it is** — A collection of charts, often hosted remotely (Bitnami, stable, etc.) or stored locally. Repositories are indexed so `helm search` can discover charts.
- **One-liner** — A repository is a searchable registry of Helm charts, like npm for Kubernetes.

Example — add and search a repository:
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo bitnami/nginx
```

### Values
- **Why it exists** — Separates configuration from templates so the same chart can be deployed across environments without modifying source YAML.
- **What it is** — YAML configuration injected into templates at install/upgrade time. Can come from the default values.yaml, CLI `--set` flags, or separate YAML files.
- **One-liner** — Values are template configuration passed to a chart at install time.

Example — override values at install:
```bash
# From a file
helm install myapp bitnami/nginx -f prod-values.yaml

# From CLI flags
helm install myapp bitnami/nginx --set replicaCount=5 --set image.tag=1.2.3
```

# Troubleshooting

### Chart Not Found in Repository
1. List configured repositories: `helm repo list`
2. Update the local index: `helm repo update`
3. Search again: `helm search repo nginx`
4. If still missing, add the repository:
  ```bash
  helm repo add bitnami https://charts.bitnami.com/bitnami
  helm repo update
  ```

### Release Deployment Failed
1. Check whether the release exists: `helm list` and `helm status my-nginx`
2. Review deployed manifest: `helm get manifest my-nginx`
3. Inspect pod events:
  ```bash
  kubectl get pods -n default
  kubectl describe pod <pod-name>
  kubectl logs <pod-name>
  ```
- Validate before re-deploying: `helm install my-nginx bitnami/nginx --dry-run --debug`

### Need to Revert to Previous Release
1. View revision history: `helm history my-nginx`
2. Roll back: `helm rollback my-nginx 1`
3. Verify: `helm status my-nginx` and `helm get manifest my-nginx`

### Values Not Being Applied
1. Check what the release currently has: `helm get values my-nginx`
2. Compare against chart defaults: `helm show values bitnami/nginx`
3. Re-upgrade with the correct values:
  ```bash
  helm upgrade my-nginx bitnami/nginx --set replicaCount=5 --set image.tag=1.2.3
  ```
