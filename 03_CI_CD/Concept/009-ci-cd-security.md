# CI/CD Security

- CI/CD security protects the software supply chain from source code to production — securing the pipeline itself, the artifacts it produces, and the credentials it uses.
- Threats target every stage: compromised dependencies, leaked secrets, tampered artifacts, malicious pipeline modifications, and over-privileged service accounts.
- Core principle: defense in depth — multiple security layers so no single failure compromises the system.

# Architecture

```text
Security Layers in a CI/CD Pipeline:

+------------------------------------------------------------------+
|                    SOURCE CODE SECURITY                           |
| Branch protection | Code review | Signed commits | CODEOWNERS    |
+------------------------------------------------------------------+
        |
        v
+------------------------------------------------------------------+
|                    DEPENDENCY SECURITY                            |
| Lock files | Pinned versions | SCA scanning | License compliance |
+------------------------------------------------------------------+
        |
        v
+------------------------------------------------------------------+
|                    BUILD SECURITY                                 |
| Minimal base images | Multi-stage builds | Reproducible builds   |
| Pin actions by SHA  | No secrets in images | SBOM generation     |
+------------------------------------------------------------------+
        |
        v
+------------------------------------------------------------------+
|                    PIPELINE SECURITY                              |
| Least privilege tokens | OIDC federation | Scoped secrets        |
| Workflow review required | Audit logging | Runner isolation      |
+------------------------------------------------------------------+
        |
        v
+------------------------------------------------------------------+
|                    ARTIFACT SECURITY                              |
| Image signing (cosign) | Vulnerability scanning | Admission ctrl |
| Registry access control | Retention policies                     |
+------------------------------------------------------------------+
        |
        v
+------------------------------------------------------------------+
|                    RUNTIME SECURITY                               |
| Network policies | RBAC | Pod security | Secret rotation         |
| Monitoring + alerting | Incident response                        |
+------------------------------------------------------------------+
```

# Mental Model

```text
Securing the software supply chain:

  [1] SECURE THE SOURCE
      |   - Branch protection: require PR review, status checks
      |   - CODEOWNERS: enforce review by domain experts
      |   - Signed commits: verify author identity
      |
      v
  [2] SECURE DEPENDENCIES
      |   - Lock files: pin exact dependency versions
      |   - SCA: scan for known vulnerabilities (Dependabot, Snyk)
      |   - License audit: ensure compliance
      |
      v
  [3] SECURE THE BUILD
      |   - Pin actions/images by SHA digest
      |   - Multi-stage builds: don't ship build tools
      |   - Generate SBOM for every artifact
      |
      v
  [4] SECURE THE PIPELINE
      |   - Least privilege: scoped tokens, minimal permissions
      |   - OIDC: short-lived credentials, no stored secrets for cloud
      |   - Review workflow changes like code changes
      |
      v
  [5] SECURE ARTIFACTS
      |   - Sign with cosign/Sigstore
      |   - Scan for vulnerabilities before deploy
      |   - Admission controller: only signed images can deploy
      |
      v
  [6] SECURE SECRETS
      |   - Platform secret store or external vault
      |   - Scope to environment, rotate regularly
      |   - Never log, echo, or expose in error messages
      |
      v
  [7] MONITOR AND RESPOND
      - Audit logs: who deployed what, when
      - Alert on: unauthorized access, failed deployments, anomalies
      - Incident response plan tested and documented
```

# Core Building Blocks

### Supply Chain Security

- The software supply chain includes: your code, dependencies, build tools, CI runners, and registries.
- Attack vectors: compromised npm/PyPI package, malicious GitHub Action, tampered base image.
- Defenses:
  - Use lock files to pin dependency versions.
  - Review dependency updates before merging.
  - Pin GitHub Actions by commit SHA, not tag (tags can be moved).
  - Use minimal, trusted base images (distroless, Chainguard).
- SLSA framework (Supply-chain Levels for Software Artifacts): levels 1-4 for build integrity.

```yaml
# Pin action by SHA, not tag
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
```

Related notes: [007-artifact-management](./007-artifact-management.md)

### SAST (Static Application Security Testing)

- Analyze source code for vulnerabilities without executing it.
- Finds: SQL injection patterns, XSS, hardcoded secrets, insecure crypto usage.
- Tools: Semgrep, CodeQL, SonarQube, Bandit (Python), ESLint security plugin.
- Run on every PR; gate on critical/high severity findings.
- False positives: tune rules, suppress with comments (document why), review regularly.

Related notes: [006-testing-strategies](./006-testing-strategies.md)

### SCA (Software Composition Analysis)

- Scan third-party dependencies for known vulnerabilities and license issues.
- Tools: Dependabot, Snyk, Trivy, Grype, OWASP Dependency-Check.
- Vulnerability databases: NVD, GitHub Advisory Database, OSV.
- Automated PR creation for dependency updates (Dependabot, Renovate).
- License compliance: detect copyleft licenses that may conflict with your project's license.

Related notes: [007-artifact-management](./007-artifact-management.md)

### DAST (Dynamic Application Security Testing)

- Test a running application by sending crafted requests and analyzing responses.
- Finds: XSS, SQL injection, auth bypass, CORS misconfiguration, open redirects.
- Tools: OWASP ZAP, Nuclei, Burp Suite (automated scan mode).
- Requires a deployed instance (staging or ephemeral environment).
- Run weekly or before release; too slow for every PR.
- Complement SAST (code-level) with DAST (runtime-level).

Related notes: [006-testing-strategies](./006-testing-strategies.md)

### Secret Management

- Secrets: API keys, database passwords, tokens, certificates, private keys.
- Storage: platform secret store (GitHub Secrets, GitLab CI variables) or external vault (HashiCorp Vault, AWS Secrets Manager).
- Rules:
  - Never commit secrets to Git (use pre-commit hooks: gitleaks, detect-secrets).
  - Never echo/print secrets in CI logs.
  - Scope secrets to specific environments (staging secrets != production secrets).
  - Rotate regularly; prefer short-lived tokens (OIDC).
  - Audit access: who can read/modify secrets.
- If a secret is leaked: rotate immediately, audit impact, review how it happened.

Related notes: [003-best-practices](./003-best-practices.md), [008-environment-management](./008-environment-management.md)

### SBOM (Software Bill of Materials)

- Machine-readable inventory of all components, libraries, and dependencies in an artifact.
- Formats: SPDX, CycloneDX.
- Generation tools: syft, trivy, docker sbom, cyclonedx-cli.
- Use cases:
  - Vulnerability response: when a new CVE is published, quickly check if you're affected.
  - License compliance: audit all licenses in your supply chain.
  - Regulatory compliance: some industries require SBOM for deployed software.
- Generate SBOM in CI; attach to release artifacts; store for audit.

Related notes: [007-artifact-management](./007-artifact-management.md)

### Image Signing and Verification

- Sign container images to prove integrity and provenance.
- **cosign** (Sigstore): keyless signing using OIDC identity from CI provider.
  - No key management needed; uses short-lived certificates.
  - Transparency log (Rekor) records all signing events.
- **Verification**: admission controllers enforce that only signed images can be deployed.
  - Kyverno, OPA Gatekeeper, Connaisseur.
- Sign in CI, verify at deploy time; reject unsigned images.

```bash
# Sign in CI (keyless with GitHub OIDC)
cosign sign --yes ghcr.io/org/myapp@$DIGEST

# Verify before deploy
cosign verify --certificate-identity=https://github.com/org/repo \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  ghcr.io/org/myapp@$DIGEST
```

Related notes: [007-artifact-management](./007-artifact-management.md)

### Least Privilege in Pipelines

- Grant CI/CD service accounts the minimum permissions needed.
- GitHub Actions: set `permissions:` block in workflow to restrict token scope.
- OIDC federation: exchange CI identity for short-lived cloud credentials (no stored secrets).
  - AWS: `aws-actions/configure-aws-credentials` with OIDC.
  - GCP: `google-github-actions/auth` with workload identity.
- Runner isolation: use ephemeral runners that are destroyed after each job.
- Self-hosted runners: harden, isolate, regularly update.

```yaml
# Restrict GitHub Actions token permissions
permissions:
  contents: read       # only read repo contents
  packages: write      # push to GHCR
  id-token: write      # OIDC token for cloud auth
```

Related notes: [003-best-practices](./003-best-practices.md)

### Branch Protection and Code Review

- Protect main/production branches from unauthorized changes.
- Settings:
  - Require pull request reviews (1-2 reviewers minimum).
  - Require CI status checks to pass before merge.
  - Require linear history (no merge commits) or signed commits.
  - Restrict who can push directly to protected branches.
  - CODEOWNERS: require specific team review for specific paths.
- Workflow files (`.github/workflows/`) should also require review (prevent malicious pipeline changes).

Related notes: [004-pipeline-design-patterns](./004-pipeline-design-patterns.md)

---

# Troubleshooting Guide

### Secret exposed in CI logs

1. Immediately rotate the exposed secret.
2. Check if the secret was registered in the platform secret store (auto-masking).
3. Find the source: `echo $SECRET`, debug logging, error messages including credentials.
4. Add pre-commit hooks to prevent future secret commits (gitleaks).
5. Audit git history: `git log -p | grep -i password` — secrets in history persist in all clones.
6. If committed to git: use git filter-branch or BFG Repo-Cleaner to remove from history.

### Dependency vulnerability alert blocking merge

1. Check severity: critical/high should be fixed before merge.
2. Check if an update is available: `npm audit fix`, `pip install --upgrade`.
3. If no fix exists: assess risk, document accepted risk, suppress with reason.
4. Check if the vulnerability is reachable in your code (not all CVEs are exploitable).
5. For transitive dependencies: update the direct dependency that pulls in the vulnerable one.

### OIDC authentication fails in CI

1. Verify trust policy: correct repository, branch, and environment in cloud provider config.
2. Check `id-token: write` permission is set in the workflow.
3. Verify OIDC provider URL matches (GitHub: `https://token.actions.githubusercontent.com`).
4. Check audience claim: some providers require explicit audience configuration.
5. Check if the workflow is running from a fork (OIDC tokens not available for fork PRs).

---

# Quick Facts (Revision)

- Pin actions and base images by SHA digest, not mutable tags.
- OIDC federation eliminates stored cloud credentials in CI.
- SAST scans code; DAST scans running applications; SCA scans dependencies.
- SBOM: generate on build, store with artifact, use for vulnerability response.
- Sign images with cosign; verify with admission controllers before deployment.
- Secrets: scoped per environment, rotated regularly, never logged.
- Branch protection: require reviews, status checks, and restricted push access.
- Supply chain security is defense in depth — no single layer is sufficient.
