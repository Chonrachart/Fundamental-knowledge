# Real-World Workflow Examples

- Common CI/CD patterns: Node.js test matrix, Docker build-and-push, Kubernetes deploy, and artifact packaging.
- Security best practices: least-privilege permissions, pinned action versions, and secret hygiene.
- Conditional steps and concurrency groups control when steps run and prevent duplicate deployments.

# Core Building Blocks

### Node.js Build and Test

- Checkout; setup Node with version from matrix; cache npm; install; run tests; optional upload coverage.
- Use **actions/checkout**, **actions/setup-node** (with cache), **run: npm ci**, **run: npm test**.
- **actions/cache** key: `npm-${{ hashFiles('**/package-lock.json') }}`; path: `~/.npm` or `node_modules` (check tool docs).
- On PR: run same; optionally **codecov** or **upload-artifact** for test results.

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node: [18, 20]
    steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: ${{ matrix.node }}
        cache: 'npm'
    - run: npm ci
    - run: npm test
```

### Build and Push Docker Image

- Checkout; **docker/login-action** (ECR, GHCR, or Docker Hub with secrets); **docker/build-push-action** with tags (e.g. sha, latest).
- Use **docker/metadata-action** to generate tags from ref/sha.
- Push only on main or on tag; use **if: github.ref == 'refs/heads/main'** or **startsWith(github.ref, 'refs/tags/')**.
- **docker/setup-buildx-action** for BuildKit; **docker/build-push-action** with **push: true** and **tags**.

```yaml
- uses: docker/login-action@v3
  with:
    registry: ${{ env.REGISTRY }}
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
- uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: ${{ env.REGISTRY }}/${{ github.repository }}:${{ github.sha }}
```

### Deploy to Kubernetes or Cloud

- **Deploy job** has **needs: [build]** (or test); only runs on main or on workflow_dispatch.
- **kubectl** or **helm**: Use **azure/k8s-set-context** or **google-github-actions/auth** + **kubectl**; or run **aws eks update-kubeconfig** then **kubectl set image**.
- **Secrets**: Store kubeconfig or cloud credentials in repo/org secrets; never in workflow file.
- **Environment**: Set **environment: production** for approval gate; use **environment** secrets for prod-only vars.

### Matrix and Upload Artifact

- Build on multiple OS (ubuntu, windows, mac); **upload-artifact** with matrix identifier in name (e.g. `build-${{ matrix.os }}`).
- Downstream job **download-artifact** for each; or single job that needs all build jobs and downloads all artifacts for packaging.
- **path** in upload: only the dir you need; **name**: include matrix to avoid overwrite.

### Conditional Steps and Concurrency

- **if: success()** or **if: failure()** to run cleanup or notify only on failure.
- **concurrency: group: ${{ github.ref }}** so only latest run per branch is active; cancel in progress when new commit pushed.
- **concurrency: group: deploy-${{ github.ref }}, cancel-in-progress: false** for deploy so two deploys don't overlap.

### Security in Workflows

- Use **least privilege**: **permissions:** only what the job needs (e.g. contents: read, packages: write).
- **GITHUB_TOKEN** is per-run and scoped; prefer it over personal/org tokens when possible.
- **Secrets**: Never echo or log; use **env** to pass to script and avoid printing.
- Pin **actions** by full ref (e.g. `actions/checkout@v4` or commit SHA) so you control when to upgrade.

Related notes: [002-workflow-syntax](./002-workflow-syntax.md), [004-secrets-cache](./004-secrets-cache.md), [003-expressions-contexts](./003-expressions-contexts.md)

---

# Troubleshooting Guide

### Docker push fails with "denied"
1. Check `docker/login-action` — verify registry URL, username, and secret name.
2. For GHCR: use `ghcr.io`, username `${{ github.actor }}`, password `${{ secrets.GITHUB_TOKEN }}`.
3. Add `permissions: packages: write` to the job.

### Deploy step has wrong credentials
1. Verify secret names match repo/org settings (case-sensitive).
2. Use `environment: production` to access environment-scoped secrets.
3. Check cloud credentials are not expired (e.g. AWS session tokens, GCP service account keys).

### npm ci fails in CI but works locally
1. Ensure `package-lock.json` is committed — `npm ci` requires it.
2. Check Node version matches: `actions/setup-node` with `node-version:` from matrix.
3. Cache may be stale: delete cache from Actions tab and re-run.

# Quick Facts (Revision)

- `npm ci` requires a committed `package-lock.json`; it fails if the lockfile is missing or out of sync.
- `docker/metadata-action` auto-generates image tags from git ref and SHA.
- Deploy jobs should use `needs:` to depend on build/test and `environment:` for approval gates.
- Pin actions to a specific version or commit SHA to prevent supply-chain attacks.
- `if: failure()` runs a step only when a previous step failed — useful for notifications.
- `concurrency` with `cancel-in-progress: false` prevents deploy interruptions.
- Use `GITHUB_TOKEN` over personal access tokens whenever its permissions are sufficient.
