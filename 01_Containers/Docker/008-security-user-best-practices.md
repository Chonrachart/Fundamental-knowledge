# Security, User, and Best Practices

- Running containers as non-root reduces blast radius if a process is compromised.
- Never store secrets in images; inject at runtime via env vars, mounted files, or orchestrator secrets.
- Minimal base images, capability dropping, and image scanning form a defense-in-depth approach.

# Architecture

```text
  Defense-in-Depth Layers
  ┌─────────────────────────────────┐
  │ 1. Minimal base image           │ ← reduce attack surface
  │ 2. Non-root USER                │ ← limit process privileges
  │ 3. Read-only rootfs             │ ← prevent filesystem tampering
  │ 4. Drop capabilities            │ ← restrict kernel permissions
  │ 5. Resource limits (mem/cpu)    │ ← prevent resource exhaustion
  │ 6. No secrets in image          │ ← prevent credential leaks
  │ 7. Image scanning               │ ← detect known CVEs
  └─────────────────────────────────┘
```

- Each layer mitigates a different attack vector; combine all for robust container security.
- Outer layers (base image, scanning) reduce what is shipped; inner layers (user, caps, read-only) restrict what runs.

# Core Building Blocks

### Run as Non-Root

- Running as root inside container increases risk; if process is compromised, attacker has root in container.
- **USER** in Dockerfile: Switch to non-root user for subsequent instructions and at runtime.
- Create user/group in Dockerfile (e.g. `adduser`), set ownership of needed dirs, then `USER` name or uid.
- Some images (e.g. official nginx) already use non-root; check with `docker run --user 1000 image id`.
- Always use `USER` in Dockerfile to run as non-root; create the user with `adduser`/`addgroup`.

```dockerfile
RUN addgroup -g 1000 app && adduser -u 1000 -G app -D app
WORKDIR /app
COPY --chown=app:app . .
USER app
CMD ["node", "index.js"]
```

### Do Not Store Secrets in Image

- Never `COPY` `.env` or secret files into image; they stay in layers and can be extracted.
- Use runtime injection: environment variables (`docker run -e`, orchestration secrets), or mounted secret files (Kubernetes secret mount, Docker secret).
- For build-time secrets (private npm, apt repo): use Docker BuildKit `--secret` so they are not written into any layer; or use multi-stage and only copy non-secret artifacts.
- Never `COPY` secrets into image layers; use `--secret` at build time or env vars at runtime.

### Read-Only and Immutable

- `--read-only`: Container root filesystem read-only; combine with `--tmpfs` for `/tmp` and writable volume for data.
- Makes it harder for an attacker to persist or modify files in the image.
- `--read-only` + `--tmpfs /tmp` + volumes = immutable container with controlled writable paths.

### Limit Capabilities

- By default containers run with a subset of Linux capabilities; some (e.g. `CAP_NET_RAW`) can be dropped.
- `--cap-drop=ALL --cap-add=NET_BIND_SERVICE`: Drop all, add only what is needed.
- Reduces impact of container escape or privilege misuse.
- `--cap-drop=ALL --cap-add=<needed>` follows least-privilege for Linux capabilities.

### Resource Limits

- Always set memory limit (`-m`) and optionally CPU (`--cpus`) so one container cannot starve the host.
- In production, use orchestrator (Kubernetes) to set requests/limits.

Related notes:
- [007-docker-run-advanced](./007-docker-run-advanced.md)

### Image Scanning and Base Image

- Use trusted base images (official, verified publisher); pin by digest for reproducibility.
- Scan images for known vulnerabilities (Trivy, Snyk, Docker Scout, registry scanners); fix or upgrade base and dependencies.
- Prefer minimal bases (alpine, distroless) to reduce attack surface.
- Pin base image versions and digests for reproducible, auditable builds.
- Scan images with Trivy, Snyk, or Docker Scout before deploying to production.
- Alpine and distroless bases minimize attack surface and image size.

### Security Checklist

- Run as non-root (`USER`).
- No secrets in image; inject at runtime or use build secrets.
- Use minimal base; pin versions/digests.
- Set memory/CPU limits.
- Prefer read-only root where possible.
- Drop unneeded capabilities.
- Scan images regularly.

Related notes:
- [003-dockerfile](./003-dockerfile.md)
- [007-docker-run-advanced](./007-docker-run-advanced.md)

---

# Troubleshooting Guide

### App fails after switching to non-root USER
1. Check file ownership: `docker exec <ctr> ls -la /app`.
2. Add `chown` before USER in Dockerfile: `COPY --chown=app:app . .`.
3. Ensure writable dirs exist: `RUN mkdir -p /app/data && chown app:app /app/data`.

### "read-only file system" errors with --read-only
1. App needs writable paths: add `--tmpfs /tmp` for temp files.
2. Mount volume for data dirs: `-v data:/app/data`.
3. Check app logs to identify which path it tries to write.

### Vulnerability scanner finds CVEs in base image
1. Update base image tag: `FROM nginx:1.27-alpine` (latest patch).
2. Rebuild: `docker build --no-cache -t myapp .`.
3. Consider `distroless` base for fewer packages and attack surface.
