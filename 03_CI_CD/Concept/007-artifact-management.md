# Artifact Management

- An artifact is the output of a build stage — a container image, binary, package, or bundle that gets deployed to environments.
- Artifacts are stored in registries, tagged for traceability, signed for integrity, and promoted (not rebuilt) through environments.
- Good artifact management ensures reproducibility: any deployment can be traced back to the exact code, dependencies, and build that produced it.

# Architecture

```text
Artifact Lifecycle:

Source Code        Build Stage           Registry              Environments
+-----------+     +-------------+      +----------------+     +------------+
| Git Repo  |---->| Build       |----->| Artifact       |---->| Staging    |
| (tagged   |     | (compile,   |      | Registry       |     | (auto)     |
|  commit)  |     |  package,   |      | (Docker Hub,   |     +------------+
+-----------+     |  image)     |      |  ECR, GHCR,    |           |
                  +-------------+      |  npm, PyPI)    |     +------------+
                       |               +----------------+     | Production |
                       |                    |                  | (promoted) |
                       v                    v                  +------------+
                  +----------+        +-----------+
                  | Metadata |        | Signing   |
                  | - git SHA|        | (cosign,  |
                  | - semver |        |  sigstore)|
                  | - SBOM   |        +-----------+
                  +----------+

Artifact types:
  +------------------+-------------------+------------------+
  | Container Images | Language Packages | Infrastructure   |
  |                  |                   |                  |
  | Docker/OCI      | npm packages      | Helm charts      |
  | Multi-arch       | Python wheels     | Terraform modules|
  | Distroless       | Go modules        | Config bundles   |
  | Scratch-based    | Maven JARs        | Lambda ZIPs      |
  +------------------+-------------------+------------------+
```

# Mental Model

```text
Artifact flow from build to production:

  [1] Code merged to main (or tag pushed)
      |
      v
  [2] Build stage: compile, package, create artifact
      |   - Deterministic build (pinned deps, reproducible)
      |
      v
  [3] Tag artifact: git SHA + semantic version (if tagged)
      |   - myapp:abc123f (SHA)
      |   - myapp:1.2.3 (release)
      |
      v
  [4] Sign artifact (cosign, Notary)
      |   - Proves who built it and that it hasn't been tampered with
      |
      v
  [5] Generate SBOM (list of all dependencies)
      |
      v
  [6] Push to registry (ECR, GHCR, Docker Hub)
      |
      v
  [7] Deploy to staging: pull myapp:abc123f
      |   - Same artifact, staging config
      |
      v
  [8] Test staging, approve promotion
      |
      v
  [9] Deploy to production: pull myapp:abc123f
      |   - SAME artifact, production config
      |   - Never rebuild for production
      |
      v
  [10] Retention policy: keep N versions, garbage collect old images
```

Example — build and push in GitHub Actions:

```yaml
- name: Build and push Docker image
  uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: |
      ghcr.io/org/myapp:${{ github.sha }}
      ghcr.io/org/myapp:latest
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

# Core Building Blocks

### Artifact Types

- **Container images**: Docker/OCI images; most common deployment artifact in modern pipelines.
- **Language packages**: npm, PyPI, Maven, NuGet — published to package registries.
- **Binaries**: compiled executables (Go binary, Rust binary, Java JAR).
- **Helm charts**: Kubernetes deployment packages; stored in Helm/OCI registries.
- **Config bundles**: deployment configs, Lambda ZIP packages, Terraform modules.
- Choose artifact type based on deployment target and runtime environment.
- Build once, deploy many: same artifact through all environments.

Related notes: [002-pipeline-stages](./002-pipeline-stages.md)

### Container Registries

- Store and distribute Docker/OCI container images.
- Common registries:
  - **Docker Hub**: public default; rate-limited for free tier.
  - **GHCR** (GitHub Container Registry): integrated with GitHub Actions.
  - **ECR** (AWS): integrated with ECS/EKS; lifecycle policies built in.
  - **GCR/Artifact Registry** (GCP): integrated with GKE.
  - **Harbor**: self-hosted, open source; scanning and replication.
- Operations: `docker push`, `docker pull`, tag management, vulnerability scanning.
- Authentication: platform tokens, OIDC, service accounts.

Related notes: [009-ci-cd-security](./009-ci-cd-security.md)

### Package Registries

- Store language-specific packages for consumption by other projects.
- Common registries:
  - **npm**: JavaScript/TypeScript packages.
  - **PyPI**: Python packages.
  - **Maven Central / Nexus**: Java packages.
  - **NuGet**: .NET packages.
  - **GitHub Packages**: multi-format, integrated with GitHub.
- Publishing: automated in CI pipeline after tests pass and version is bumped.
- Scoping: public packages vs private/org-scoped packages.

Related notes: [002-pipeline-stages](./002-pipeline-stages.md)

### Semantic Versioning

- Version format: `MAJOR.MINOR.PATCH` (e.g., `2.1.3`).
  - **MAJOR**: breaking changes (incompatible API changes).
  - **MINOR**: new features (backward-compatible).
  - **PATCH**: bug fixes (backward-compatible).
- Pre-release: `1.0.0-beta.1`, `2.0.0-rc.1`.
- Build metadata: `1.0.0+build.123`.
- Auto-versioning tools: `semantic-release`, conventional commits.
- Convention: commit messages drive version bumps (`feat:` = minor, `fix:` = patch, `BREAKING CHANGE:` = major).
- Semantic versioning: MAJOR (breaking), MINOR (feature), PATCH (fix).

Related notes: [004-pipeline-design-patterns](./004-pipeline-design-patterns.md)

### Tagging Strategy

- **Git SHA**: `myapp:abc123f` — exact commit traceability; always unique.
- **Semantic version**: `myapp:1.2.3` — human-readable release version.
- **Branch name**: `myapp:main` — mutable, points to latest on branch.
- **`latest`**: mutable, points to most recent push; avoid in production (ambiguous).
- Best practice: always tag with git SHA; additionally tag with semver for releases.
- Never use `latest` or branch tags in production deployments — use immutable tags.
- Tag with git SHA for traceability; add semver for releases.
- Never use `latest` tag in production — it is mutable and ambiguous.

Related notes: [004-pipeline-design-patterns](./004-pipeline-design-patterns.md)

### Artifact Signing and Verification

- Signing proves: who built the artifact and that it hasn't been tampered with.
- Tools:
  - **`cosign`** (Sigstore): keyless signing using OIDC identity; most common for containers.
  - **Notary / Docker Content Trust**: Docker-native signing.
  - **`GPG`**: traditional signing for packages and binaries.
- Verification: admission controllers (`Kyverno`, `OPA`) verify signatures before allowing deployment.
- Keyless signing: uses short-lived certificates tied to CI identity (no key management).
- Sign artifacts with cosign/Sigstore; verify with admission controllers.

```bash
# Sign with cosign (keyless, in CI)
cosign sign --yes ghcr.io/org/myapp:$SHA

# Verify
cosign verify ghcr.io/org/myapp:$SHA
```

Related notes: [009-ci-cd-security](./009-ci-cd-security.md)

### Retention and Cleanup

- Registries accumulate images over time; storage costs and attack surface grow.
- Lifecycle policies: automatically delete images older than N days or keep only N tags.
- Keep: all tagged releases (semver), last N images per branch, production-deployed images.
- Delete: untagged manifests, old branch images, expired pre-release versions.
- ECR lifecycle policy example: keep last 10 tagged images, delete untagged after 7 days.
- Garbage collection: reclaim storage after deleting image manifests (registry-specific).
- Retention policies prevent registry bloat; keep releases, delete old branches.

Related notes: [003-best-practices](./003-best-practices.md)

### Build Reproducibility

- Same source + same dependencies should produce the same artifact.
- Requirements:
  - Pin all dependency versions (lockfiles: `package-lock.json`, `go.sum`, `poetry.lock`).
  - Pin base images by digest (`FROM node:20@sha256:abc...` not `FROM node:20`).
  - Avoid non-deterministic steps (timestamps in builds, random ordering).
- **SBOM** (Software Bill of Materials): machine-readable list of all components in the artifact.
  - Tools: `syft`, `trivy`, `docker sbom`.
  - Formats: `SPDX`, `CycloneDX`.
  - Use: vulnerability auditing, license compliance, supply chain transparency.
- SBOM: machine-readable inventory of all components in the artifact.
- Pin base images by digest for reproducible builds.

Related notes: [009-ci-cd-security](./009-ci-cd-security.md)

---

# Troubleshooting Guide

### Image pull fails in deployment

1. Check image tag: typo, wrong SHA, tag not pushed to registry.
2. Check registry authentication: pull secret / service account has access.
3. Check registry URL: correct domain, correct repository path.
4. Check rate limits: Docker Hub has pull rate limits for anonymous/free users.
5. Check image architecture: ARM node pulling AMD64 image (or vice versa).

### Artifact size too large

1. Use multi-stage Docker builds: build in large image, copy only output to slim image.
2. Use distroless or alpine base images.
3. Add `.dockerignore` to exclude unnecessary files (`node_modules`, `.git`, tests).
4. Check for debug symbols, development dependencies included in production image.
5. Compress binaries; strip debug information.

### Version conflict between environments

1. Verify same artifact tag is deployed to both environments.
2. Check deployment config: staging and prod should reference the same image tag.
3. Check for environment-specific build steps (there should be none — build once).
4. Audit promotion process: was the artifact rebuilt instead of promoted?
5. Use immutable tags (SHA) not mutable tags (latest, branch).
