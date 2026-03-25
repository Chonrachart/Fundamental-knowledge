# Workflow Security and OIDC

- OIDC (OpenID Connect) lets workflows authenticate to cloud providers with short-lived tokens instead of long-lived secrets.
- Supply chain security requires pinning actions by commit SHA, restricting fork PR execution, and limiting GITHUB_TOKEN permissions.
- `pull_request_target` runs with write permissions and access to secrets — misuse is a common attack vector.

# Architecture

```text
GitHub Actions Workflow
        │
        ▼
Request OIDC token from GitHub's OIDC provider
  (aud: sts.amazonaws.com / accounts.google.com)
        │
        ▼
Cloud Provider verifies token:
  - Issuer: token.actions.githubusercontent.com
  - Subject: repo:org/repo:ref:refs/heads/main
  - Claims match trust policy
        │
        ▼
Cloud returns short-lived credentials
  (AWS: STS AssumeRoleWithWebIdentity)
  (GCP: Workload Identity Federation)
  (Azure: Federated Identity Credential)
        │
        ▼
Workflow uses temporary credentials (15 min–1 hr)
  No secrets stored in GitHub
```

# Mental Model

```text
Old way: store AWS_ACCESS_KEY_ID in GitHub Secrets
  → long-lived → risk of leak → manual rotation

New way: OIDC
  → workflow says "I am repo:org/repo on branch main"
  → cloud says "I trust that identity, here's a temp token"
  → token expires automatically
  → no secrets to rotate
```

Example (AWS):
```yaml
jobs:
  deploy:
    permissions:
      id-token: write      # required for OIDC
      contents: read
    steps:
    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::123456789012:role/github-deploy
        aws-region: us-east-1
    - run: aws s3 ls
```

# Core Building Blocks

### OIDC with AWS

- Create IAM Role with trust policy for `token.actions.githubusercontent.com`.
- Condition: restrict to specific repo, branch, or environment.
- Use `aws-actions/configure-aws-credentials@v4` with `role-to-assume`.

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:my-org/my-repo:ref:refs/heads/main"
      }
    }
  }]
}
```

### OIDC with GCP

- Use Workload Identity Federation; create a workload identity pool and provider.
- Use `google-github-actions/auth@v2` with `workload_identity_provider` and `service_account`.

```yaml
- uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: projects/PROJECT/locations/global/workloadIdentityPools/POOL/providers/PROVIDER
    service_account: deploy@PROJECT.iam.gserviceaccount.com
```

### OIDC with Azure

- Use Federated Identity Credential on an Azure AD App Registration.
- Use `azure/login@v2` with `client-id`, `tenant-id`, `subscription-id`.

### Permissions Hardening

- Set `permissions:` at workflow or job level; default should be restrictive.
- Only grant what's needed: `contents: read`, `packages: write`, `id-token: write`, etc.
- Org setting: set default GITHUB_TOKEN to read-only (Settings → Actions → General).

```yaml
# Restrictive workflow-level default
permissions:
  contents: read

jobs:
  deploy:
    permissions:
      contents: read
      id-token: write    # only this job needs OIDC
```

### Supply Chain Security

- **Pin actions by SHA**: `uses: actions/checkout@<full-sha>` — prevents tag hijacking.
- **Dependabot for actions**: Add `.github/dependabot.yml` to auto-update action versions.
- **Review third-party actions**: Check source, stars, maintenance before using.
- **Avoid `pull_request_target`** unless you understand the risks — it runs with write access on forked PRs.

```yaml
# .github/dependabot.yml
version: 2
updates:
- package-ecosystem: github-actions
  directory: /
  schedule:
    interval: weekly
```

### Fork and PR Safety

- `pull_request` from forks: no secrets, read-only GITHUB_TOKEN — safe by default.
- `pull_request_target`: runs in context of base repo with secrets and write access — dangerous.
- Never checkout and execute fork PR code in `pull_request_target` without review.
- Use `environment` with required reviewers for deploy jobs triggered by PRs.

Related notes: [004-secrets-cache](./004-secrets-cache.md), [003-expressions-contexts](./003-expressions-contexts.md), [008-self-hosted-runners](./008-self-hosted-runners.md), [../Concept/009-ci-cd-security](../Concept/009-ci-cd-security.md)


- OIDC eliminates long-lived cloud credentials; tokens are scoped to repo + branch + environment.
- `permissions: id-token: write` is required for any OIDC authentication.
- AWS OIDC uses `sts:AssumeRoleWithWebIdentity`; GCP uses Workload Identity Federation.
- Pin actions by commit SHA for supply chain security; use Dependabot to track updates.
- `pull_request_target` has write permissions and secrets access — never checkout fork code with it.
- Default GITHUB_TOKEN should be read-only at org level; grant write only where needed.
- OIDC subject claims can be scoped to repo, branch, tag, or environment for fine-grained access.
- Fork PRs on `pull_request` event are safe by default: no secrets, read-only token.
---

# Troubleshooting Guide

### OIDC token request fails — "Error: Not authorized"
1. Check `permissions: id-token: write` is set on the job.
2. Check cloud trust policy: subject claim must match repo, branch, or environment exactly.
3. Check OIDC provider is configured in cloud account (AWS: Identity Provider, GCP: Workload Identity Pool).
4. Debug: add step `- run: echo $ACTIONS_ID_TOKEN_REQUEST_URL` to verify token endpoint exists.

### Cloud credentials expire mid-job
1. Default OIDC session is 1 hour; long jobs may exceed this.
2. AWS: set `role-duration-seconds` in `configure-aws-credentials` (max depends on IAM role config).
3. Split long jobs into smaller ones with separate auth steps.

### pull_request_target security incident
1. Immediately revoke any leaked secrets.
2. Audit workflow: ensure no `actions/checkout` of PR head ref in `pull_request_target`.
3. Switch to `pull_request` event if write access isn't needed.
4. Add `environment` with required reviewers for sensitive operations.

### Dependabot PR updates actions — should I merge?
1. Review the changelog for breaking changes.
2. Check if the action still has the same inputs/outputs.
3. Prefer major version pins (`@v4`) for flexibility; SHA pins for maximum security.
