# Secrets, Cache, Artifacts, and Environments

- Secrets are stored in repo/org settings, masked in logs, and accessed via `${{ secrets.NAME }}`.
- Caching (`actions/cache`) speeds up builds by reusing dependencies across runs; keyed by lockfile hash.
- Artifacts persist build outputs between jobs; environments gate deployments with approval rules.

# Architecture

```text
Secrets Injection and Cache Storage:

Secrets:
  Repo/Org Settings ──(encrypted at rest)──> GitHub Secrets Store
       |
       v  (injected at job start)
  Runner Environment ──> ${{ secrets.NAME }} in YAML
       |                  (value masked in logs)
       v
  Step execution ──> env var or inline value (never logged)

Cache:
  actions/cache
       |
       ├── key: npm-${{ hashFiles('**/package-lock.json') }}
       |         ^-- deterministic hash of lockfile
       |
       ├── SAVE: job end ──> compress path ──> GitHub cache storage
       |                     (scoped to branch, 10 GB repo limit)
       |
       └── RESTORE: job start ──> exact key match? ──> cache hit
                                  no? ──> restore-keys fallback
                                  no? ──> cache miss (fresh install)
```

# Mental Model

```text
Secret masking + cache hit/miss flow:

  Secrets:
  [1] Secret stored encrypted in GitHub Settings
  [2] At job start, secrets injected as env vars
  [3] Log scanner masks any output matching secret values
  [4] Fork PRs: secrets NOT injected (security boundary)

  Cache:
  [1] Compute cache key from hashFiles() of lockfile
      |
      v
  [2] Exact key exists? → cache HIT → restore path → skip install
      |
      +-- No exact match → try restore-keys prefix match
      |     → partial HIT → restore (may need partial update)
      |
      +-- No match at all → cache MISS → full install
      |
      v
  [3] At job end: if key was new, save path to cache
```

# Core Building Blocks

### Secrets

- Stored in repo or org Settings; not in logs (masked).
- Use in workflow: `${{ secrets.MY_SECRET }}`; must exist or step fails.
- **GITHUB_TOKEN**: Auto-injected; scoped to repo; permissions set in job or workflow.
- Limit GITHUB_TOKEN permissions to least needed (contents: read, packages: write, etc.).
- Secrets are masked in logs automatically; never echo them intentionally.
- `GITHUB_TOKEN` is auto-generated per workflow run and scoped to the current repo.
- Forked PRs do not receive secrets — this is a security feature, not a bug.

```yaml
jobs:
  deploy:
    permissions:
      contents: read
      packages: write
    steps:
    - run: echo ${{ secrets.API_KEY }}
```

### Cache

- **actions/cache**: Save and restore directory by key; restore key for fallback.
- Key often includes hash of lockfile: `npm-${{ hashFiles('**/package-lock.json') }}`.
- Scope: branch; cache can be shared across branches (cache from default branch).
- Cache keys should include `hashFiles()` of the lockfile so changes invalidate stale caches.
- `restore-keys:` provides fallback cache matching when the exact key misses.

```yaml
- uses: actions/cache@v4
  with:
    path: node_modules
    key: npm-${{ hashFiles('**/package-lock.json') }}
    restore-keys: npm-
```

### Artifacts

- **actions/upload-artifact**: Upload files from job; stored with workflow run.
- **actions/download-artifact**: Download in same or later job (by name).
- Use for build outputs, test results, logs; retention configurable.
- Artifacts are stored per workflow run and can be downloaded by dependent jobs via `needs:`.

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: dist
    path: dist/
```

### Environment

- Define environments in repo (e.g. staging, production); optional protection rules (required reviewers, wait timer).
- **environment**: In job; use for approval gates and env-specific secrets.
- Reference: `environment: production`; secrets can be per-environment.
- Environment protection rules (reviewers, wait timers) only apply when the job specifies `environment:`.

Related notes: [001-github-actions-overview](./001-github-actions-overview.md), [003-expressions-contexts](./003-expressions-contexts.md)
