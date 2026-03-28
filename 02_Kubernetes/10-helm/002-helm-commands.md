# Helm Commands

# Overview
- **Why it exists** — Helm's value comes from being operable entirely from the CLI; a concise set of commands covers the full release lifecycle from search to uninstall without touching raw kubectl.
- **What it is** — The primary Helm CLI verbs: `install`, `upgrade`, `rollback`, `uninstall`, `list`, `status`, `get`, `history`, and repository management commands — each maps to a release lifecycle action.
- **One-liner** — Helm commands let you install, update, inspect, and roll back releases and manage chart repositories from the terminal.

# Architecture

```
Command Flow
────────────

User runs: helm install / upgrade / rollback / uninstall
                    ↓
          Helm Library resolves chart + values
                    ↓
          Template engine renders final YAML
                    ↓
          Kubernetes API receives the manifests
                    ↓
          Release record updated in cluster Secrets
```

# Mental Model

The release lifecycle follows a linear flow with a rollback escape hatch:

```
helm repo add / update   (register chart sources)
        ↓
helm install             (create release, revision 1)
        ↓
helm upgrade             (apply changes, revision 2, 3 …)
        ↓
helm rollback            (revert to earlier revision)
        ↓
helm uninstall           (destroy release)
```

Each upgrade creates a new revision number. `helm history` shows the full audit trail.

# Core Building Blocks

### Installation & Inspection
- **Why it exists** — You need to deploy a chart and verify what was rendered before and after installation.
- **What it is** — Commands that install a release and inspect chart metadata or rendered output without side effects.
- **One-liner** — Install a chart and preview or introspect what will be deployed.

```bash
# Install a chart with release name 'my-nginx'
helm install my-nginx bitnami/nginx

# Install to a specific namespace
helm install my-nginx bitnami/nginx -n my-namespace

# Preview what would be installed (dry-run, no cluster changes)
helm install my-nginx bitnami/nginx --dry-run --debug

# Show default values for a chart
helm show values bitnami/nginx

# Show Chart.yaml metadata
helm show chart bitnami/nginx

# Render templates locally without installing
helm template my-nginx bitnami/nginx
```

### Release Management
- **Why it exists** — You need visibility into what is running, what configuration it uses, and what manifests were applied.
- **What it is** — Commands that list, describe, and retrieve details of deployed releases.
- **One-liner** — Query the state of deployed releases and their rendered manifests.

```bash
# List all releases in the cluster
helm list

# List releases in a specific namespace
helm list -n my-namespace

# Get status of a release
helm status my-nginx

# Get detailed release info
helm get values my-nginx        # currently applied values
helm get manifest my-nginx      # rendered YAML deployed to cluster
helm get all my-nginx           # everything combined

# View release revision history
helm history my-nginx
```

### Updates & Rollbacks
- **Why it exists** — Applications change; you need to apply new config or chart versions and recover quickly when something breaks.
- **What it is** — Commands that modify an existing release (upgrade), revert it (rollback), or remove it entirely (uninstall).
- **One-liner** — Upgrade, roll back, or remove releases to manage the app lifecycle.

```bash
# Upgrade a release (new chart version or new values)
helm upgrade my-nginx bitnami/nginx

# Upgrade with CLI flag overrides
helm upgrade my-nginx bitnami/nginx --set replicaCount=3 --set image.tag=1.2.3

# Upgrade with a values file
helm upgrade my-nginx bitnami/nginx -f custom-values.yaml

# Rollback to a specific revision
helm rollback my-nginx 1

# Rollback to the previous revision
helm rollback my-nginx

# Uninstall a release (removes from cluster)
helm uninstall my-nginx

# Uninstall but keep history (allows future rollback)
helm uninstall my-nginx --keep-history
```

### Overriding Values
- **Why it exists** — The same chart needs different configuration per environment; you want to override defaults without editing the chart itself.
- **What it is** — Three override mechanisms applied in priority order: values.yaml (lowest) → `-f file` → `--set` (highest).
- **One-liner** — Override defaults at install/upgrade time using files or CLI flags; CLI always wins.

```bash
# Override with a values file
helm install myapp bitnami/nginx -f prod-values.yaml

# Override with --set (simple key=value)
helm install myapp bitnami/nginx --set replicaCount=5
helm install myapp bitnami/nginx --set image.tag=1.2.3 --set replicaCount=5

# Override with --set-string (force string type, prevents YAML type parsing)
helm install myapp bitnami/nginx --set-string someKey=stringval

# Multiple files (later files override earlier ones)
helm install myapp bitnami/nginx -f base-values.yaml -f prod-overrides.yaml

# Combine file + CLI (CLI takes precedence over file)
helm install myapp bitnami/nginx -f base-values.yaml --set replicaCount=10
```

# Troubleshooting

### Release Deployment Failed
- Check release state: `helm list` and `helm status my-nginx`
- Inspect what was applied: `helm get manifest my-nginx`
- Check Kubernetes pod events:
  ```bash
  kubectl get pods -n default
  kubectl describe pod <pod-name>
  kubectl logs <pod-name>
  ```
- Validate first next time: `helm install my-nginx bitnami/nginx --dry-run --debug`

### Template Rendering Issues
- Render locally to see the output: `helm template my-nginx bitnami/nginx`
- Render with specific values: `helm template my-nginx bitnami/nginx -f custom-values.yaml`
- Check for lint errors: `helm lint mychart`

### Need to Revert to Previous Release
- View history: `helm history my-nginx`
- Roll back: `helm rollback my-nginx 1`
- Confirm: `helm status my-nginx`

### Values Not Taking Effect After Upgrade
- Check what the release sees: `helm get values my-nginx`
- Compare against chart defaults: `helm show values bitnami/nginx`
- Re-upgrade with explicit values:
  ```bash
  helm upgrade my-nginx bitnami/nginx --set replicaCount=5 --set image.tag=1.2.3
  ```
