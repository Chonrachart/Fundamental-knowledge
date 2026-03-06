checkout
build
test
deploy
artifact
gate

---

# Checkout

- Get repository source; usually first step.
- Shallow clone or sparse checkout to speed up; specify ref (branch, tag, SHA) when needed.

# Build

- Compile code, build binaries, create Docker images.
- Use caching (dependencies, layers) to reduce build time.
- Output artifacts: attach to workflow (upload-artifact) or push to registry.

# Test

- **Unit**: Fast; test single units in isolation; run on every commit.
- **Integration**: Services together; DB, APIs; may need test env.
- **E2E**: Full flow in environment close to prod; often on schedule or before release.
- **Lint / static analysis**: Style, security (SAST), dependency checks.
- Fail the pipeline if tests fail; report coverage and results.

# Deploy

- Push image to registry; update deployment (k8s, ECS, etc.) or run deploy script.
- Often separate jobs or workflows: deploy-staging on merge to main, deploy-prod on tag or manual.
- Use secrets for credentials; never log secrets.

# Artifacts

- Build outputs passed between jobs or stored for download (e.g. GitHub Actions upload-artifact / download-artifact).
- Docker images are "artifacts" stored in registry; deploy step pulls by tag.

# Gates

- **Merge gate**: CI must pass before PR can merge (branch protection).
- **Deploy gate**: Only deploy if tests pass; optional manual approval for prod.
- **Quality gate**: Block if coverage below threshold or critical findings (config in tool).
