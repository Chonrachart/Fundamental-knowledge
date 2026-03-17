# ArgoCD Admin Operations

- ArgoCD administration covers access control (RBAC, SSO), backup and disaster recovery, upgrades, performance tuning, and security hardening.
- Production ArgoCD deployments require HA mode, proper RBAC, SSO integration, and regular backups of application state.
- Monitoring ArgoCD itself is critical — a broken GitOps operator means no deployments.

# Architecture

```text
ArgoCD Admin Components:

+------------------------------------------------------------------+
|                     ArgoCD Admin Concerns                         |
+------------------------------------------------------------------+
|                                                                    |
|  +------------------+  +------------------+  +------------------+ |
|  | ACCESS CONTROL   |  | OPERATIONS       |  | OBSERVABILITY    | |
|  |                  |  |                  |  |                  | |
|  | - RBAC policies  |  | - Backups        |  | - Metrics        | |
|  | - SSO/OIDC (Dex) |  | - DR plan        |  |   (Prometheus)   | |
|  | - Projects       |  | - Upgrades       |  | - Dashboards     | |
|  | - Local accounts |  | - Scaling        |  |   (Grafana)      | |
|  | - API tokens     |  | - Maintenance    |  | - Alerts         | |
|  +------------------+  +------------------+  +------------------+ |
|                                                                    |
|  +------------------+  +------------------+                       |
|  | SECURITY         |  | HIGH AVAIL.      |                       |
|  |                  |  |                  |                       |
|  | - TLS            |  | - HA manifests   |                       |
|  | - Network policy |  | - Redis HA       |                       |
|  | - Secret mgmt   |  | - Multiple       |                       |
|  | - Audit logs     |  |   replicas       |                       |
|  +------------------+  +------------------+                       |
+------------------------------------------------------------------+
```

# Mental Model

```text
ArgoCD admin lifecycle:

  [1] INSTALL
      |   - Choose: kubectl apply, Helm, or ArgoCD managing itself
      |   - Choose: standalone (dev/test) or HA (production)
      |
      v
  [2] CONFIGURE ACCESS
      |   - Set up SSO (OIDC via Dex or direct)
      |   - Define RBAC policies (who can sync, who can view)
      |   - Create Projects (scope what apps can do)
      |   - Disable/change default admin password
      |
      v
  [3] SECURE
      |   - TLS for argocd-server (Ingress or cert-manager)
      |   - Network policies (restrict ArgoCD namespace access)
      |   - Audit logging enabled
      |   - Git repo credentials secured
      |
      v
  [4] MONITOR
      |   - Expose Prometheus metrics (/metrics endpoint)
      |   - Grafana dashboards for sync status, repo-server latency
      |   - Alert on: sync failures, unhealthy apps, high repo-server latency
      |
      v
  [5] MAINTAIN
      |   - Regular upgrades (follow ArgoCD release notes)
      |   - Backup Application and AppProject CRDs
      |   - Test disaster recovery procedures
      |   - Review and clean up orphaned applications
      |
      v
  [6] SCALE (when needed)
      - Increase repo-server replicas for many repos
      - Tune application-controller sharding for many apps
      - Adjust Redis memory limits
```

# Core Building Blocks

### RBAC Configuration

- RBAC policies define who can perform what actions on which resources.
- Configured in `argocd-rbac-cm` ConfigMap.
- Policy format: `p, <subject>, <resource>, <action>, <object>, <allow/deny>`.
- Resources: `applications`, `clusters`, `repositories`, `projects`, `logs`, `exec`.
- Actions: `get`, `create`, `update`, `delete`, `sync`, `override`, `action`.
- Groups map to SSO groups or local accounts.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly     # default role for authenticated users
  policy.csv: |
    # Roles
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    p, role:admin, projects, *, *, allow

    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, dev/*, allow
    p, role:developer, applications, sync, staging/*, allow
    p, role:developer, applications, sync, production/*, deny

    p, role:viewer, applications, get, */*, allow

    # Group mappings (SSO groups)
    g, platform-team, role:admin
    g, dev-team, role:developer
    g, stakeholders, role:viewer
```

Related notes: [001-argocd-overview](./001-argocd-overview.md)

### SSO / OIDC Configuration

- ArgoCD supports SSO via Dex (built-in) or direct OIDC provider.
- Dex: bundled identity broker; connects to GitHub, GitLab, LDAP, SAML, OIDC.
- Direct OIDC: configure ArgoCD to talk directly to Okta, Azure AD, Google, etc.

```yaml
# argocd-cm ConfigMap - Dex with GitHub
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd.example.com
  dex.config: |
    connectors:
      - type: github
        id: github
        name: GitHub
        config:
          clientID: $dex-github-client-id
          clientSecret: $dex-github-client-secret
          orgs:
            - name: my-org
              teams:
                - platform-team
                - dev-team

# Direct OIDC (e.g., Okta)
# argocd-cm ConfigMap
data:
  oidc.config: |
    name: Okta
    issuer: https://myorg.okta.com/oauth2/default
    clientID: <client-id>
    clientSecret: $oidc-okta-client-secret
    requestedScopes: ["openid", "profile", "email", "groups"]
```

Related notes: [001-argocd-overview](./001-argocd-overview.md)

### Backup and Disaster Recovery

- ArgoCD state is stored in Kubernetes CRDs (Application, AppProject) and ConfigMaps.
- Backup what matters:
  - Application and AppProject CRDs.
  - ConfigMaps: `argocd-cm`, `argocd-rbac-cm`, `argocd-notifications-cm`.
  - Secrets: repo credentials, cluster credentials, SSO config.
  - Not needed: the actual app manifests (they're in Git — that's the point of GitOps).

```bash
# Backup all ArgoCD applications
kubectl get applications -n argocd -o yaml > argocd-applications-backup.yaml

# Backup all AppProjects
kubectl get appprojects -n argocd -o yaml > argocd-projects-backup.yaml

# Backup ConfigMaps
kubectl get cm argocd-cm argocd-rbac-cm -n argocd -o yaml > argocd-config-backup.yaml

# Export with argocd CLI
argocd admin export > argocd-backup.yaml

# Restore
kubectl apply -f argocd-backup.yaml
# or
argocd admin import < argocd-backup.yaml
```

- DR plan:
  1. Reinstall ArgoCD (Helm or kubectl apply).
  2. Restore CRDs and ConfigMaps from backup.
  3. ArgoCD will re-sync all applications from Git (Git is the source of truth).
  4. Verify all applications are synced and healthy.

Related notes: [002-argocd-applications](./002-argocd-applications.md)

### Upgrade Strategy

- Follow ArgoCD release notes for breaking changes before upgrading.
- Upgrade path: minor versions (2.8 --> 2.9 --> 2.10), not skipping majors.
- Methods:
  - **Helm**: `helm upgrade argocd argo/argo-cd --version <new-version>`.
  - **kubectl**: apply the new version's install manifest.
  - **ArgoCD managing itself**: update the target revision in the self-managing Application.
- Pre-upgrade checklist:
  1. Backup all CRDs and ConfigMaps.
  2. Read release notes and migration guide.
  3. Test upgrade in a non-production ArgoCD instance.
  4. Plan for brief downtime of ArgoCD UI/API during rollout (apps continue running).

Related notes: [001-argocd-overview](./001-argocd-overview.md)

### Performance Tuning

- **Repo server**: clone and render manifests; most common bottleneck.
  - Increase replicas for many repos or complex Helm charts.
  - Tune `reposerver.parallelism.limit` for concurrent renders.
  - Cache: repo-server caches rendered manifests in Redis.
- **Application controller**: watch and sync applications.
  - Sharding: distribute applications across controller replicas.
  - `controller.status.processors` and `controller.operation.processors`: parallel processing.
- **Redis**: caching layer for repo-server and controller.
  - Increase memory limits for large deployments.
  - Use Redis HA (Sentinel) for production.
- **Reconciliation interval**: default 3 minutes; increase for large deployments to reduce load.

```yaml
# argocd-cmd-params-cm ConfigMap - tuning
data:
  reposerver.parallelism.limit: "10"           # concurrent manifest renders
  controller.status.processors: "50"           # parallel status processors
  controller.operation.processors: "25"        # parallel operation processors
  timeout.reconciliation: "300"                # 5 min reconciliation (default 180s)
```

Related notes: [001-argocd-overview](./001-argocd-overview.md)

### Monitoring ArgoCD

- ArgoCD exposes Prometheus metrics on `/metrics` endpoints.
- Key metrics to monitor:
  - `argocd_app_info`: application sync and health status.
  - `argocd_app_sync_total`: sync operations count.
  - `argocd_app_reconcile`: reconciliation duration.
  - `argocd_repo_pending_request_total`: repo-server queue depth.
  - `argocd_cluster_api_resource_objects`: cluster resource count.
- Grafana dashboards: ArgoCD community provides pre-built dashboards.
- Alerts to configure:
  - Application sync failed (any app in SyncFailed state).
  - Application unhealthy (any app in Degraded state for >5 min).
  - Repo-server high latency (manifest rendering too slow).
  - Redis memory usage >80%.

```yaml
# ServiceMonitor for Prometheus Operator
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/part-of: argocd
  endpoints:
    - port: metrics
```

Related notes: [001-argocd-overview](./001-argocd-overview.md)

### Security Hardening

- Disable admin account after setting up SSO (or change default password).
- TLS: terminate TLS at Ingress or configure argocd-server with TLS certificates.
- Network policies: restrict access to ArgoCD namespace; only allow necessary traffic.
- Git credentials: use deploy keys (read-only SSH) or scoped tokens.
- Cluster credentials: use service accounts with minimal RBAC.
- Audit logging: ArgoCD logs all sync operations; forward to centralized logging.
- Restrict repository access per Project (only allowed repos).
- Regularly rotate credentials and review access policies.

```bash
# Disable admin account
kubectl patch cm argocd-cm -n argocd -p '{"data":{"admin.enabled":"false"}}'

# Change admin password
argocd account update-password --account admin --current-password <old> --new-password <new>
```

Related notes: [001-argocd-overview](./001-argocd-overview.md)

---

# Troubleshooting Guide

### User cannot sync application (RBAC denied)

1. Check RBAC policy: `argocd admin settings rbac can <user> sync applications <project>/<app>`.
2. Verify user's group membership matches RBAC group mapping.
3. Check `policy.default` — is it too restrictive?
4. Verify SSO group claims are being passed correctly.
5. Check the Application's project — project-level restrictions apply on top of RBAC.

### ArgoCD UI returns 502/503

1. Check argocd-server pods: `kubectl get pods -n argocd`.
2. Check Ingress: is the backend healthy?
3. Check TLS: certificate mismatch between Ingress and argocd-server.
4. Check resource limits: argocd-server may be OOMKilled.
5. Check logs: `kubectl logs -n argocd deploy/argocd-server`.

### Repo-server high latency (slow sync)

1. Check repo-server resource usage: `kubectl top pods -n argocd`.
2. Large repos: consider splitting into smaller repos.
3. Complex Helm charts: Helm templating is CPU-intensive; increase replicas.
4. Check Redis: cache misses increase rendering frequency.
5. Increase `reposerver.parallelism.limit` if renders are queuing.

### Disaster recovery — ArgoCD namespace accidentally deleted

1. Reinstall ArgoCD: `kubectl apply -n argocd -f install.yaml`.
2. Restore from backup: `kubectl apply -f argocd-backup.yaml`.
3. Re-register clusters: `argocd cluster add <context>`.
4. Applications will auto-sync from Git (cluster workloads are unaffected).
5. Verify all apps: `argocd app list` — check sync and health status.
6. Lesson: protect ArgoCD namespace with RBAC and resource policies.

---

# Quick Facts (Revision)

- RBAC: policy.csv in argocd-rbac-cm; format: `p, role, resource, action, scope, allow/deny`.
- SSO: Dex (bundled) or direct OIDC; map SSO groups to RBAC roles.
- Backup: export Application CRDs, ConfigMaps, Secrets; Git has the manifests.
- Upgrade: follow release notes, backup first, test in non-prod, don't skip versions.
- Performance: scale repo-server replicas, tune controller processors, increase Redis memory.
- Monitor: Prometheus metrics, Grafana dashboards, alert on sync failures and degraded apps.
- Security: disable admin after SSO, TLS, network policies, read-only deploy keys.
- DR: reinstall ArgoCD + restore CRDs; applications re-sync from Git automatically.
