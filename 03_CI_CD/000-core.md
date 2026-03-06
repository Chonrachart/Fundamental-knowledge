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

- [Concept/001-ci-cd-concept](./Concept/001-ci-cd-concept.md) — CI, CD, pipeline, build, test, deploy
- [Concept/002-pipeline-stages](./Concept/002-pipeline-stages.md) — Stages, gates, artifacts
- [Concept/003-best-practices](./Concept/003-best-practices.md) — Fast feedback, security, maintainability
- [Concept/004-pipeline-design-patterns](./Concept/004-pipeline-design-patterns.md) — Design, parallel, fan-out, branch strategy
- [Github_Action/001-github-actions-overview](./Github_Action/001-github-actions-overview.md) — Workflow, job, step, trigger (start here)
- [Github_Action/002-workflow-syntax](./Github_Action/002-workflow-syntax.md) — on, jobs, env, matrix, needs
- [Github_Action/003-secrets-cache](./Github_Action/003-secrets-cache.md) — Secrets, cache, artifacts, environments
- [Github_Action/004-real-world-examples](./Github_Action/004-real-world-examples.md) — Node, Docker, deploy examples
- [Github_Action/005-expressions-contexts](./Github_Action/005-expressions-contexts.md) — Expressions, contexts, outputs, hashFiles
- [Github_Action/006-reusable-workflows-debugging](./Github_Action/006-reusable-workflows-debugging.md) — Reusable workflows, composite actions, debugging
