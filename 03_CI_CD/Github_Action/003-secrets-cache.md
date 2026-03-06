secrets
GITHUB_TOKEN
cache
artifact
environment

---

# Secrets

- Stored in repo or org Settings → Secrets; not in logs (masked).
- Use in workflow: `${{ secrets.MY_SECRET }}`; must exist or step fails.
- **GITHUB_TOKEN**: Auto-injected; scoped to repo; permissions set in job or workflow.
- Limit GITHUB_TOKEN permissions to least needed (contents: read, packages: write, etc.).

```yaml
jobs:
  deploy:
    permissions:
      contents: read
      packages: write
    steps:
    - run: echo ${{ secrets.API_KEY }}
```

# Cache

- **actions/cache**: Save and restore directory by key; restore key for fallback.
- Key often includes hash of lockfile: `npm-${{ hashFiles('**/package-lock.json') }}`.
- Scope: branch; cache can be shared across branches (cache from default branch).

```yaml
- uses: actions/cache@v4
  with:
    path: node_modules
    key: npm-${{ hashFiles('**/package-lock.json') }}
    restore-keys: npm-
```

# Artifacts

- **actions/upload-artifact**: Upload files from job; stored with workflow run.
- **actions/download-artifact**: Download in same or later job (by name).
- Use for build outputs, test results, logs; retention configurable.

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: dist
    path: dist/
```

# Environment

- Define environments in repo (e.g. staging, production); optional protection rules (required reviewers, wait timer).
- **environment**: In job; use for approval gates and env-specific secrets.
- Reference: `environment: production`; secrets can be per-environment.
