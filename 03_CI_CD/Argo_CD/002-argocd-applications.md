# ArgoCD Applications

- An Application is ArgoCD's core CRD that maps a Git source (repo + path + revision) to a Kubernetes destination (cluster + namespace).
- ApplicationSets generate multiple Applications from templates — enabling dynamic, scalable multi-cluster and multi-tenant deployments.
- The app-of-apps pattern uses one root Application to manage other Application manifests, forming a deployment hierarchy.

# Architecture

```text
Application Hierarchy:

Root Application (app-of-apps)
    |
    +--> Application: frontend
    |       source: git/manifests/frontend
    |       dest: cluster-prod/frontend
    |
    +--> Application: backend-api
    |       source: git/manifests/backend
    |       dest: cluster-prod/backend
    |
    +--> Application: database
    |       source: git/manifests/database
    |       dest: cluster-prod/database
    |
    +--> Application: monitoring
            source: git/manifests/monitoring
            dest: cluster-prod/monitoring

ApplicationSet (generates Applications from template):
    Generator: Git directories
    Template: Application per directory

    manifests/
      apps/
        app-a/ ----> Application: app-a
        app-b/ ----> Application: app-b
        app-c/ ----> Application: app-c
```

# Mental Model

```text
Choosing an application management approach:

  [1] How many applications do you have?
      |
      +-- Few (1-5): create Application CRDs manually
      |
      +-- Many (5-50): app-of-apps pattern
      |
      +-- Dynamic/many (50+): ApplicationSet with generators
      |
      v
  [2] How are manifests organized?
      |
      +-- Plain YAML: source.path points to directory
      |
      +-- Helm chart: source.chart or source.path + values
      |
      +-- Kustomize: source.path with kustomization.yaml
      |
      +-- Multiple sources: multi-source Application
      |
      v
  [3] How many clusters/environments?
      |
      +-- Single cluster: destination.server = in-cluster
      |
      +-- Multi-cluster: ApplicationSet with cluster generator
      |
      v
  [4] How do you handle per-environment config?
      |
      +-- Kustomize overlays: base/ + overlays/staging/ + overlays/prod/
      |
      +-- Helm values: values-staging.yaml, values-prod.yaml
      |
      +-- Multi-source: app manifests from one repo, values from another
```

# Core Building Blocks

### Application CRD — Detailed

- Defines a single deployment unit managed by ArgoCD.
- Key fields:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
  # Finalizer ensures cleanup when Application is deleted
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  # SOURCE: where to get manifests
  source:
    repoURL: https://github.com/org/manifests.git
    targetRevision: main        # branch, tag, or commit SHA
    path: apps/myapp            # directory in the repo

    # For Helm:
    # chart: mychart            # chart name (from Helm repo)
    # helm:
    #   valueFiles: [values-prod.yaml]
    #   parameters:
    #     - name: image.tag
    #       value: "v1.2.3"

    # For Kustomize:
    # kustomize:
    #   namePrefix: prod-
    #   images: [myapp=myregistry/myapp:v1.2.3]

  # DESTINATION: where to deploy
  destination:
    server: https://kubernetes.default.svc   # in-cluster
    namespace: myapp

  # SYNC POLICY
  syncPolicy:
    automated:
      prune: true           # delete resources removed from Git
      selfHeal: true        # revert manual changes
    syncOptions:
      - CreateNamespace=true
      - PruneLast=true      # prune after all other syncs
      - ApplyOutOfSyncOnly=true  # only apply changed resources
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```
- Application CRD = source (Git) + destination (cluster/namespace) + sync policy.
- Helm, Kustomize, plain YAML, and Jsonnet are all supported manifest sources.
- Always test ignoreDifferences in staging before applying to production apps.

Related notes: [001-argocd-overview](./001-argocd-overview.md)

### Helm Source

- ArgoCD can deploy Helm charts from Git repos or Helm chart repositories.
- From Helm repo:

```yaml
source:
  repoURL: https://charts.example.com
  chart: myapp
  targetRevision: 1.2.3
  helm:
    valueFiles:
      - values.yaml
      - values-prod.yaml
    parameters:
      - name: image.tag
        value: "abc123f"
    releaseName: myapp
```

- From Git repo (chart in a directory):

```yaml
source:
  repoURL: https://github.com/org/manifests.git
  path: charts/myapp
  targetRevision: main
  helm:
    valueFiles:
      - values-staging.yaml
```

- Values file priority: later files override earlier ones.
- Parameters override values files.

Related notes: [003-argocd-sync-strategies](./003-argocd-sync-strategies.md)

### Kustomize Source

- ArgoCD natively renders Kustomize overlays.
- Directory must contain a `kustomization.yaml`.

```yaml
source:
  repoURL: https://github.com/org/manifests.git
  path: apps/myapp/overlays/production
  targetRevision: main
  kustomize:
    namePrefix: prod-
    nameSuffix: ""
    commonLabels:
      env: production
    images:
      - myapp=ghcr.io/org/myapp:v1.2.3
```

- Overlay structure:

```text
apps/myapp/
  base/
    deployment.yaml
    service.yaml
    kustomization.yaml
  overlays/
    staging/
      kustomization.yaml     # patches for staging
      replicas-patch.yaml
    production/
      kustomization.yaml     # patches for production
      replicas-patch.yaml
      hpa.yaml
```

Related notes: [003-argocd-sync-strategies](./003-argocd-sync-strategies.md)

### Multi-Source Applications

- A single Application can pull from multiple Git repos or chart repos.
- Use case: application manifests in one repo, Helm values in another.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  sources:
    - repoURL: https://charts.example.com
      chart: myapp
      targetRevision: 1.2.3
      helm:
        valueFiles:
          - $values/apps/myapp/values-prod.yaml
    - repoURL: https://github.com/org/config.git
      targetRevision: main
      ref: values        # reference name used above as $values
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp
```

- `ref` creates a named reference to a source; `$ref` prefix accesses files from it.
- Multi-source: pull manifests from one repo, values from another.

Related notes: [001-argocd-overview](./001-argocd-overview.md)

### Projects

- Projects provide logical grouping and access control for Applications.
- Control:
  - **Source repos**: which Git repos applications in this project can use.
  - **Destinations**: which clusters and namespaces applications can deploy to.
  - **Cluster resources**: can applications create cluster-scoped resources (ClusterRole, Namespace)?
  - **Namespaced resources**: whitelist/blacklist specific resource kinds.
- Default project: `default` — allows all sources, all destinations (lock down for production).

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
  namespace: argocd
spec:
  description: Production applications
  sourceRepos:
    - https://github.com/org/manifests.git
  destinations:
    - server: https://kubernetes.default.svc
      namespace: 'prod-*'
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
  namespaceResourceBlacklist:
    - group: ''
      kind: ResourceQuota
  roles:
    - name: deployer
      description: Can sync production apps
      policies:
        - p, proj:production:deployer, applications, sync, production/*, allow
```
- Projects: access control boundaries (allowed repos, destinations, resource kinds).

Related notes: [005-argocd-admin-operations](./005-argocd-admin-operations.md)

### App-of-Apps Pattern

- One root Application manages a directory of Application manifests.
- Adding a new service: add an Application YAML to the directory; root app syncs it.

```text
Repository structure:
argocd-apps/
  root-app.yaml              # root Application (points to apps/ dir)
  apps/
    frontend.yaml             # Application CRD for frontend
    backend.yaml              # Application CRD for backend
    database.yaml             # Application CRD for database
```

```yaml
# root-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/argocd-apps.git
    path: apps
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

- Benefits: single entry point, consistent management, easy to add/remove apps.
- Drawback: deleting root app can cascade-delete all child apps (use finalizers carefully).
- App-of-apps: root Application manages child Application manifests.

Related notes: [001-argocd-overview](./001-argocd-overview.md)

### ApplicationSet

- Controller that generates Application CRDs from templates + generators.
- Generators:
  - **List**: explicit list of parameters.
  - **Git directory**: one Application per directory in a Git repo.
  - **Git file**: read parameters from JSON/YAML files in Git.
  - **Cluster**: one Application per registered cluster.
  - **Matrix**: combine two generators (e.g., clusters x apps).
  - **Merge**: merge parameters from multiple generators.
  - **Pull Request**: one Application per open PR (preview environments).
- ApplicationSet: generate Applications dynamically from templates + generators.
- PR generator: create ephemeral preview environments per pull request.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: all-apps
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/org/manifests.git
        revision: main
        directories:
          - path: apps/*
  template:
    metadata:
      name: '{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/org/manifests.git
        targetRevision: main
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

- PR generator for ephemeral environments:

```yaml
generators:
  - pullRequest:
      github:
        owner: org
        repo: myapp
        tokenRef:
          secretName: github-token
          key: token
      requeueAfterSeconds: 60
template:
  metadata:
    name: 'myapp-pr-{{number}}'
  spec:
    source:
      path: k8s/overlays/preview
      targetRevision: '{{head_sha}}'
    destination:
      namespace: 'preview-pr-{{number}}'
```

Related notes: [004-argocd-advanced-patterns](./004-argocd-advanced-patterns.md)

---

# Troubleshooting Guide

### Application stuck in "OutOfSync" after sync

1. Check diff: `argocd app diff myapp` — look at what ArgoCD thinks is different.
2. Common: Kubernetes adds default fields (annotations, labels) not in Git manifests.
3. Solution: add `ignoreDifferences` for auto-generated fields.
4. Check mutating webhooks: they may modify resources after ArgoCD applies them.
5. Check Helm: non-deterministic template output (random, date functions).

```yaml
# Ignore differences for specific fields
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas     # HPA manages replicas
    - group: ""
      kind: Service
      jqPathExpressions:
        - .metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"]
```

### ApplicationSet not generating expected Applications

1. Check generator output: `kubectl get applicationsets -n argocd -o yaml`.
2. Verify Git repo structure matches generator expectations (directory paths, file names).
3. Check template variable names match generator output fields.
4. Check RBAC: ApplicationSet controller needs permissions to create Applications.
5. Check logs: `kubectl logs -n argocd deploy/argocd-applicationset-controller`.

### App-of-apps cascade delete

1. Use `resources-finalizer.argocd.argoproj.io` finalizer on child apps only if you want cascade delete.
2. Remove finalizer from child apps if you want them to survive root app deletion.
3. To safely delete root app without deleting children: remove the finalizer first, then delete.
