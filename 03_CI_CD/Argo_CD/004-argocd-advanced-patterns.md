# ArgoCD Advanced Patterns

- ArgoCD's advanced patterns extend basic GitOps with progressive delivery (canary/blue-green via Argo Rollouts), automated image updates, and multi-cluster deployments.
- Notifications integrate ArgoCD events with Slack, email, and webhooks for team visibility.
- These patterns transform ArgoCD from a simple sync tool into a full deployment platform.

# Architecture

```text
Advanced ArgoCD Ecosystem:

+-------------------+     +------------------+     +-------------------+
| Git Repository    |     | ArgoCD           |     | Kubernetes        |
|                   |     |                  |     | Cluster           |
| Rollout manifests |---->| Application      |---->| Argo Rollouts     |
| (canary steps,    |     | Controller       |     | Controller        |
|  analysis)        |     +------------------+     |   |               |
+-------------------+            |                 |   v               |
                                 |            +----+----------+       |
+-------------------+            |            | Rollout CRD   |       |
| Container         |            |            | (replaces     |       |
| Registry          |            |            |  Deployment)  |       |
|                   |<-----------+            +----+----------+       |
| new image pushed  |    Image Updater             |                  |
|                   |    detects new tag            v                  |
+-------------------+    updates Git          +----------+            |
                                              | Analysis |            |
+-------------------+                         | Run      |            |
| Notification      |<---- ArgoCD events      | (metrics |            |
| Channels          |                         |  check)  |            |
| (Slack, email,    |                         +----------+            |
|  webhook)         |                                                 |
+-------------------+                                                 |
                                                                      |
Multi-Cluster:                                                        |
+-------------------+     +-------------------+                       |
| Cluster A         |<----| ApplicationSet    |                       |
| (staging)         |     | (cluster          |                       |
+-------------------+     |  generator)       |                       |
+-------------------+     |                   |                       |
| Cluster B         |<----|                   |                       |
| (production)      |     +-------------------+                       |
+-------------------+                                                 +
```

# Mental Model

```text
Progressive delivery with ArgoCD + Argo Rollouts:

  [1] Developer pushes new image tag to Git manifests
      |
      v
  [2] ArgoCD detects change, syncs Rollout CRD
      |
      v
  [3] Argo Rollouts controller starts canary
      |   - Creates canary ReplicaSet (new version)
      |   - Routes small % of traffic to canary
      |
      v
  [4] Analysis Run executes
      |   - Queries Prometheus for error rate, latency
      |   - Compares canary metrics vs stable
      |
      +---> FAIL: auto-rollback to stable, notify team
      |
      v (PASS)
  [5] Promote: increase canary traffic %
      |   - Repeat analysis at each step
      |
      v
  [6] Full promotion: canary becomes stable
      |   - Old ReplicaSet scaled down
      |   - Notification sent: deployment complete
```

# Core Building Blocks

### Argo Rollouts — Canary

- Replaces Kubernetes Deployment with Rollout CRD for progressive delivery.
- Canary: route a percentage of traffic to the new version, monitor, and expand.
- Requires a traffic management solution: `Istio`, `NGINX Ingress`, `ALB`, `SMI`, `Traefik`.
- Argo Rollouts: Rollout CRD replaces Deployment for canary and blue-green strategies.
- Canary steps: setWeight, pause, analysis — controlled traffic shifting.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  replicas: 10
  strategy:
    canary:
      canaryService: myapp-canary      # Service for canary pods
      stableService: myapp-stable      # Service for stable pods
      trafficRouting:
        nginx:
          stableIngress: myapp-ingress
      steps:
        - setWeight: 10                # 10% traffic to canary
        - pause: { duration: 5m }      # wait 5 min
        - analysis:                    # run metrics check
            templates:
              - templateName: success-rate
        - setWeight: 30
        - pause: { duration: 5m }
        - setWeight: 60
        - pause: { duration: 5m }
        - setWeight: 100               # full rollout
      analysis:
        successfulRunHistoryLimit: 3
        unsuccessfulRunHistoryLimit: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: ghcr.io/org/myapp:v1.2.3
```

Related notes: [003-argocd-sync-strategies](./003-argocd-sync-strategies.md)

### Argo Rollouts — Blue-Green

- Two full ReplicaSets: active (serving traffic) and preview (new version).
- Switch traffic instantly after preview is verified.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  replicas: 5
  strategy:
    blueGreen:
      activeService: myapp-active        # current production Service
      previewService: myapp-preview      # new version Service
      autoPromotionEnabled: false        # require manual promotion
      previewReplicaCount: 5             # full scale preview
      scaleDownDelaySeconds: 300         # keep old version 5 min after switch
      prePromotionAnalysis:
        templates:
          - templateName: smoke-test
      postPromotionAnalysis:
        templates:
          - templateName: success-rate
```

- Promotion: `kubectl argo rollouts promote myapp` or via ArgoCD UI.
- Rollback: `kubectl argo rollouts abort myapp` switches back to stable.
- Blue-Green: activeService + previewService; instant switch with auto/manual promotion.

Related notes: [003-argocd-sync-strategies](./003-argocd-sync-strategies.md)

### Analysis Templates and Runs

- AnalysisTemplate defines metrics to evaluate during canary/blue-green deployments.
- AnalysisRun is a concrete execution of a template.
- Metric providers: `Prometheus`, `Datadog`, `NewRelic`, `CloudWatch`, Web (custom HTTP).

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
    - name: service-name
  metrics:
    - name: success-rate
      interval: 1m
      count: 5
      successCondition: result[0] >= 0.95      # 95% success rate
      failureLimit: 3
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            sum(rate(http_requests_total{status=~"2..",service="{{args.service-name}}"}[5m]))
            /
            sum(rate(http_requests_total{service="{{args.service-name}}"}[5m]))
```

- Success/failure conditions use expr language.
- `failureLimit`: how many metric failures before rollback.
- `count` + `interval`: how many times to check over what duration.
- AnalysisTemplate: define metrics (Prometheus, Datadog) to evaluate during rollout.

Related notes: [003-argocd-sync-strategies](./003-argocd-sync-strategies.md)

### ArgoCD Image Updater

- Automatically detects new container image tags in registries and updates Git manifests.
- Eliminates the CI step of "update image tag in Git repo."
- Flow: new image pushed to registry --> Image Updater detects --> updates Git --> ArgoCD syncs.
- Update strategies:
  - `semver`: follow semantic versioning (latest semver tag).
  - `latest`: most recently pushed tag.
  - `digest`: always use the latest digest for a tag.
  - `name`: alphabetical/lexicographic ordering.

```yaml
# Annotation on Application to enable Image Updater
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  annotations:
    argocd-image-updater.argoproj.io/image-list: myapp=ghcr.io/org/myapp
    argocd-image-updater.argoproj.io/myapp.update-strategy: semver
    argocd-image-updater.argoproj.io/myapp.allow-tags: regexp:^v[0-9]+\.[0-9]+\.[0-9]+$
    argocd-image-updater.argoproj.io/write-back-method: git
    argocd-image-updater.argoproj.io/write-back-target: kustomization
```

- Write-back methods: `git` (commits to repo) or `argocd` (parameter override, no Git change).
- Image Updater: auto-detect new tags in registry, update Git, trigger sync.

Related notes: [002-argocd-applications](./002-argocd-applications.md)

### ArgoCD Notifications

- Send notifications on ArgoCD events (sync started, sync succeeded, sync failed, health degraded).
- Channels: Slack, email, webhook, Teams, Telegram, Grafana.
- Configure via `argocd-notifications-cm` ConfigMap.

```yaml
# argocd-notifications-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
  template.app-sync-succeeded: |
    message: |
      Application {{.app.metadata.name}} sync succeeded.
      Revision: {{.app.status.sync.revision}}
  trigger.on-sync-succeeded: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-sync-succeeded]

# Annotation on Application
metadata:
  annotations:
    notifications.argoproj.io/subscribe.on-sync-succeeded.slack: my-channel
    notifications.argoproj.io/subscribe.on-sync-failed.slack: my-channel
```

- Triggers define when to send; templates define what to send.
- Subscribe via annotations on individual Applications.
- Notifications: Slack/email/webhook on sync events; configure via ConfigMap + annotations.

Related notes: [005-argocd-admin-operations](./005-argocd-admin-operations.md)

### Multi-Cluster Management

- ArgoCD can manage applications across multiple Kubernetes clusters.
- Register clusters: `argocd cluster add <kubeconfig-context>`.
- ApplicationSet cluster generator: deploy same app to multiple clusters.

```yaml
# ApplicationSet with cluster generator
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-all-clusters
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            env: production
  template:
    metadata:
      name: 'myapp-{{name}}'     # {{name}} = cluster name
    spec:
      project: default
      source:
        repoURL: https://github.com/org/manifests.git
        path: apps/myapp/overlays/{{metadata.labels.env}}
        targetRevision: main
      destination:
        server: '{{server}}'      # cluster API server URL
        namespace: myapp
```

- Cluster labels: tag clusters with metadata (env, region, tier) for generator filtering.
- Hub-spoke model: ArgoCD in a management cluster deploys to workload clusters.
- Multi-cluster: register clusters, use ApplicationSet cluster generator.

Related notes: [002-argocd-applications](./002-argocd-applications.md)

### ApplicationSet Advanced Generators

- **Matrix generator**: combine two generators (e.g., clusters x apps).

```yaml
generators:
  - matrix:
      generators:
        - clusters:
            selector:
              matchLabels:
                env: production
        - git:
            repoURL: https://github.com/org/manifests.git
            revision: main
            directories:
              - path: apps/*
```

- **Merge generator**: merge parameters from multiple generators (override defaults per cluster).
- **Pull Request generator**: create preview environments per PR (see 002-argocd-applications).
- **SCM Provider generator**: discover repos from GitHub/GitLab org and create apps.
- Matrix generator: combine clusters x apps for dynamic multi-cluster deployments.

Related notes: [002-argocd-applications](./002-argocd-applications.md)

---

# Troubleshooting Guide

### Canary stuck at setWeight step

1. Check Rollout status: `kubectl argo rollouts get rollout myapp`.
2. Check if the canary pods are healthy: `kubectl get pods -l rollouts-pod-template-hash`.
3. Check `AnalysisRun`: `kubectl get analysisrun` — is it still running, failed, or succeeded?
4. Check traffic routing: is the Ingress/Istio VirtualService splitting traffic correctly?
5. Manual promote: `kubectl argo rollouts promote myapp` to proceed.
6. Abort if unhealthy: `kubectl argo rollouts abort myapp`.

### Image Updater not detecting new images

1. Check Image Updater logs: `kubectl logs -n argocd deploy/argocd-image-updater`.
2. Verify registry credentials: Image Updater needs pull access to the registry.
3. Check annotation syntax: `argocd-image-updater.argoproj.io/image-list` format.
4. Check `allow-tags` filter: does the regex match the new tag?
5. Check update interval: default 2 minutes; may need to wait.
6. Verify write-back method: `git` needs write access to the manifest repo.

---

Related notes (Concept):
- [../Concept/011-gitops](../Concept/011-gitops.md) — Progressive delivery with GitOps
- [../Concept/005-deployment-strategies](../Concept/005-deployment-strategies.md) — Canary, Blue-Green strategy fundamentals
- [../Concept/010-metrics-and-dora](../Concept/010-metrics-and-dora.md) — DORA metrics for deployment analysis

### Notifications not sending

1. Check notification controller logs: `kubectl logs -n argocd deploy/argocd-notifications-controller`.
2. Verify service config in `argocd-notifications-cm` (token, URL).
3. Check trigger condition: `when` expression must match the app state.
4. Verify subscribe annotation on the Application.
5. Test with `argocd admin notifications trigger get <trigger-name>`.
