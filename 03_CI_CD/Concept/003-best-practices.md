fast feedback
security
maintainability
cache
secrets

---

# Fast Feedback

- Run quick tests first (unit, lint); run slow jobs (e2e) in parallel or after.
- Use caching for dependencies; keep pipelines under ~10 min when possible.
- Fail fast: cancel redundant runs when new commit pushed (e.g. concurrency in GHA).

# Security

- Never log or expose secrets; use secret store (GitHub Secrets, Vault); mask in logs.
- Pin actions and base images by digest or exact version; scan dependencies (Dependabot, Snyk).
- Least privilege: use scoped tokens; avoid broad repo permissions in workflows.
- SAST/DAST in pipeline; gate on critical findings.

# Maintainability

- Reuse workflows (callable workflows, composite actions); keep YAML DRY.
- Name jobs and steps clearly; add comments for non-obvious steps.
- Document required secrets and env vars; use small, focused workflows.
- Version workflow files; avoid breaking main branch (test in PR).

# Cache

- Cache package manager dirs (npm, pip, go mod); key on lockfile hash.
- Invalidate when lockfile or install script changes.
- Docker: use layer cache; cache-from when building images.

# Secrets

- Store in platform (GitHub Secrets, GitLab CI variables) or external store.
- Rotate regularly; use short-lived tokens for deploy; restrict by environment where possible.
