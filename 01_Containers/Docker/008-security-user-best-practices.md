security
non-root
USER
secrets
scan
best practices

---

# Run as Non-Root

- Running as root inside container increases risk; if process is compromised, attacker has root in container.
- **USER** in Dockerfile: Switch to non-root user for subsequent instructions and at runtime.
- Create user/group in Dockerfile (e.g. adduser), set ownership of needed dirs, then USER name or uid.
- Some images (e.g. official nginx) already use non-root; check with `docker run --user 1000 image id`.

```dockerfile
RUN addgroup -g 1000 app && adduser -u 1000 -G app -D app
WORKDIR /app
COPY --chown=app:app . .
USER app
CMD ["node", "index.js"]
```

# Do Not Store Secrets in Image

- **Never** COPY .env or secret files into image; they stay in layers and can be extracted.
- Use **runtime** injection: environment variables (docker run -e, orchestration secrets), or mounted secret files (Kubernetes secret mount, Docker secret).
- For **build-time** secrets (private npm, apt repo): use Docker BuildKit **--secret** so they are not written into any layer; or use multi-stage and only copy non-secret artifacts.

# Read-Only and Immutable

- **--read-only**: Container root filesystem read-only; combine with **--tmpfs** for /tmp and writable volume for data.
- Makes it harder for an attacker to persist or modify files in the image.

# Limit Capabilities

- By default containers run with a subset of Linux capabilities; some (e.g. CAP_NET_RAW) can be dropped.
- **--cap-drop=ALL --cap-add=NET_BIND_SERVICE**: Drop all, add only what is needed.
- Reduces impact of container escape or privilege misuse.

# Resource Limits

- Always set **memory limit** (-m) and optionally **CPU** (--cpus) so one container cannot starve the host.
- In production, use orchestrator (Kubernetes) to set requests/limits.

# Image Scanning and Base Image

- Use **trusted base images** (official, verified publisher); pin by digest for reproducibility.
- Scan images for known vulnerabilities (Trivy, Snyk, Docker Scout, registry scanners); fix or upgrade base and dependencies.
- Prefer minimal bases (alpine, distroless) to reduce attack surface.

# Summary Checklist

- Run as non-root (USER).
- No secrets in image; inject at runtime or use build secrets.
- Use minimal base; pin versions/digests.
- Set memory/CPU limits.
- Prefer read-only root where possible.
- Drop unneeded capabilities.
- Scan images regularly.
