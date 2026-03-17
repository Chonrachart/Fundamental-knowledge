overview of

    CI
    CD
    pipeline
    build
    test
    deploy

---

# CI (Continuous Integration)

- Automatically build and test code when changes are pushed.
- Catch integration issues early; keep main branch healthy.

# CD (Continuous Delivery / Deployment)

- **Continuous Delivery**: Always in a deployable state; deploy to production manually.
- **Continuous Deployment**: Automatically deploy to production after tests pass.

# Pipeline

- Sequence of stages: checkout → build → test → (security scan) → deploy.
- Defined in config (e.g. GitHub Actions workflow, Jenkinsfile).

# Pipeline Stages

- **Checkout**: Get source code.
- **Build**: Compile, package, build images.
- **Test**: Unit, integration, e2e; lint, security scan.
- **Deploy**: Push to registry, deploy to env (staging/prod); often gated by branch or manual.

# Quality Gates

- Block merge if tests fail or coverage drops; require approval for production deploy.
- Use status checks (e.g. "CI") as branch protection requirements.

# Topic Map (basic → advanced)

### Concepts
- [Concept/001-ci-cd-concept](./Concept/001-ci-cd-concept.md) — CI, CD, pipeline fundamentals, build, test, deploy lifecycle
- [Concept/002-pipeline-stages](./Concept/002-pipeline-stages.md) — Stages, gates, artifacts, notifications
- [Concept/003-best-practices](./Concept/003-best-practices.md) — Fast feedback, security, caching, secrets, maintainability
- [Concept/004-pipeline-design-patterns](./Concept/004-pipeline-design-patterns.md) — Sequential, parallel, fan-out/fan-in, matrix, monorepo
- [Concept/005-deployment-strategies](./Concept/005-deployment-strategies.md) — Rolling, blue-green, canary, feature flags, rollback
- [Concept/006-testing-strategies](./Concept/006-testing-strategies.md) — Test pyramid, shift-left, unit/integration/e2e, SAST/DAST
- [Concept/007-artifact-management](./Concept/007-artifact-management.md) — Registries, versioning, signing, SBOM, retention
- [Concept/008-environment-management](./Concept/008-environment-management.md) — Staging/prod, promotion, ephemeral envs, migrations
- [Concept/009-ci-cd-security](./Concept/009-ci-cd-security.md) — Supply chain, SAST/SCA/DAST, secrets, OIDC, branch protection
- [Concept/010-metrics-and-dora](./Concept/010-metrics-and-dora.md) — DORA four key metrics, pipeline health, continuous improvement
- [Concept/011-gitops](./Concept/011-gitops.md) — ArgoCD, FluxCD, drift detection, reconciliation, progressive delivery

### GitHub Actions
- [Github_Action/001-github-actions-overview](./Github_Action/001-github-actions-overview.md) — Workflow, job, step, trigger (start here)
- [Github_Action/002-workflow-syntax](./Github_Action/002-workflow-syntax.md) — on, jobs, env, matrix, needs
- [Github_Action/003-secrets-cache](./Github_Action/003-secrets-cache.md) — Secrets, cache, artifacts, environments
- [Github_Action/004-real-world-examples](./Github_Action/004-real-world-examples.md) — Node, Docker, deploy examples
- [Github_Action/005-expressions-contexts](./Github_Action/005-expressions-contexts.md) — Expressions, contexts, outputs, hashFiles
- [Github_Action/006-reusable-workflows-debugging](./Github_Action/006-reusable-workflows-debugging.md) — Reusable workflows, composite actions, debugging

### Argo CD
- [Argo_CD/001-argocd-overview](./Argo_CD/001-argocd-overview.md) — Architecture, components, Application CRD, Web UI, CLI
- [Argo_CD/002-argocd-applications](./Argo_CD/002-argocd-applications.md) — Application, Helm/Kustomize source, Projects, app-of-apps, ApplicationSet
- [Argo_CD/003-argocd-sync-strategies](./Argo_CD/003-argocd-sync-strategies.md) — Auto-sync, self-heal, prune, sync waves, hooks, sync windows
- [Argo_CD/004-argocd-advanced-patterns](./Argo_CD/004-argocd-advanced-patterns.md) — Argo Rollouts, canary/blue-green, Image Updater, notifications, multi-cluster
- [Argo_CD/005-argocd-admin-operations](./Argo_CD/005-argocd-admin-operations.md) — RBAC, SSO, backup/DR, upgrades, monitoring, security hardening
