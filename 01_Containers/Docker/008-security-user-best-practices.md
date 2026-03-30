# Container Security Best Practices

# Overview

- **Why it exists** — Containers share the host kernel, so a misconfigured or compromised container can escalate privileges to the host or laterally to neighbouring containers; layered controls reduce the blast radius of any single failure.
- **What it is** — A set of defence-in-depth practices — non-root users, secret hygiene, read-only filesystems, capability dropping, resource limits, minimal base images, and continuous image scanning — applied at build time, runtime, and registry level.
- **One-liner** — Secure containers by shrinking attack surface at every layer: image, runtime flags, kernel capabilities, and supply chain.

# Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                    Defence-in-Depth Layers                      │
│                                                                 │
│  Layer 1 – Supply Chain                                         │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Minimal base image (alpine / distroless)                 │  │
│  │  No secrets baked into layers                             │  │
│  │  Image scanning (Trivy / Snyk / Docker Scout)             │  │
│  └───────────────────────────────────────────────────────────┘  │
│                            │                                    │
│  Layer 2 – Build / Image                                        │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  USER directive  →  run as non-root UID                   │  │
│  │  --secret flag   →  secrets never written to layers       │  │
│  └───────────────────────────────────────────────────────────┘  │
│                            │                                    │
│  Layer 3 – Runtime Flags                                        │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  --read-only + --tmpfs   →  immutable root filesystem     │  │
│  │  --cap-drop=ALL + --cap-add <only needed>                 │  │
│  │  --memory / --cpus       →  resource limits               │  │
│  └───────────────────────────────────────────────────────────┘  │
│                            │                                    │
│  Layer 4 – Kernel / Host                                        │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  seccomp / AppArmor profiles                              │  │
│  │  No privileged mode  (--privileged=false)                 │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

# Mental Model

```text
Dockerfile build                   docker run
─────────────────                  ──────────────────────────────
FROM minimal-base                  --read-only
  │                                --tmpfs /tmp
USER nonroot          ─────▶       --cap-drop=ALL
  │                                --cap-add NET_BIND_SERVICE
No secrets in layers               --memory=256m --cpus=0.5
  │                                --security-opt no-new-privileges
Image scanning (CI)                │
                                   Running container with minimal
                                   privileges and surface area
```

- Start with the smallest possible base image — fewer packages means fewer CVEs.
- Never put a secret (API key, password, cert) inside a `RUN`, `ENV`, or `COPY` instruction; it will be frozen in the layer history forever.
- Drop all Linux capabilities at runtime and add back only what the process genuinely requires.
- A read-only filesystem prevents attackers from writing payloads or modifying binaries inside the running container.
- Scanning images in CI catches known vulnerabilities before they reach production.

# Core Building Blocks

### Non-Root User (USER Directive)

- **Why it exists** — Processes running as UID 0 inside a container can exploit kernel misconfigurations to gain root on the host; non-root processes limit that lateral movement.
- **What it is** — The `USER` instruction in a Dockerfile sets the UID/GID for all subsequent `RUN`, `CMD`, and `ENTRYPOINT` instructions and for the container process at runtime.
- **One-liner** — Always end your Dockerfile with `USER nonroot` so the container process is never root.

```dockerfile
FROM node:20-alpine

# Create a dedicated user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app
COPY --chown=appuser:appgroup package*.json ./
RUN npm ci --omit=dev

COPY --chown=appuser:appgroup . .

# Switch to non-root before the entrypoint
USER appuser

CMD ["node", "server.js"]
```

- Use `--chown` on `COPY` so the app files are owned by the non-root user.
- Distroless images ship `nonroot` (UID 65532) by default — use `USER nonroot` with them.
- If you need to bind to port < 1024, use `--cap-add NET_BIND_SERVICE` instead of running as root.

### Secret Hygiene (Never Bake Secrets into Layers)

- **Why it exists** — Every `RUN`, `ENV`, and `COPY` instruction creates an immutable layer; secrets stored there can be extracted with `docker history` or by pulling the image.
- **What it is** — Using `docker build --secret` (BuildKit) mounts a secret at build time without writing it to any layer; at runtime, secrets are injected via environment variables, mounted files, or a secrets manager — never baked in.
- **One-liner** — Secrets must never touch an image layer; mount them at build time or inject them at runtime.

```dockerfile
# Build-time secret (BuildKit) — never lands in a layer
# syntax=docker/dockerfile:1
FROM python:3.12-slim
RUN --mount=type=secret,id=pip_token \
    pip install --index-url https://$(cat /run/secrets/pip_token)@pypi.example.com/simple mypackage
```

```bash
# Pass the secret at build time
docker build --secret id=pip_token,src=./pip_token.txt -t myapp .

# Runtime injection via environment variable
docker run --env-file .secrets.env myapp

# What NOT to do:
# ENV API_KEY=supersecret        ← baked into layer forever
# RUN curl -H "Token: $MY_KEY"   ← visible in docker history
```

- Use Docker Secrets (Swarm) or Kubernetes Secrets for runtime injection in production.
- Rotate any secret that was accidentally baked into an image and push a new tag immediately.

### Read-Only Filesystem (--read-only + --tmpfs)

- **Why it exists** — A writable root filesystem lets attackers drop scripts, modify binaries, or establish persistence; a read-only filesystem makes this impossible.
- **What it is** — `--read-only` mounts the container root filesystem as read-only; `--tmpfs` carves out in-memory writable directories for paths the app genuinely needs to write (e.g. `/tmp`, `/var/run`).
- **One-liner** — Run containers `--read-only` and add `--tmpfs` only for the directories that must be writable.

```bash
docker run \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  --tmpfs /var/run:rw,noexec,nosuid \
  myapp
```

- `noexec` on `--tmpfs` prevents execution of binaries dropped into `/tmp`.
- Test your application first — some frameworks write socket files or cache to unexpected paths.

### Capability Dropping (--cap-drop / --cap-add)

- **Why it exists** — Docker containers inherit a default set of Linux capabilities (e.g. `CHOWN`, `NET_RAW`, `SYS_CHROOT`) that most applications do not need; each retained capability is an exploitable attack surface.
- **What it is** — `--cap-drop=ALL` strips every Linux capability from the container; `--cap-add <CAP>` restores only the specific ones the process requires.
- **One-liner** — Drop all capabilities first, then add back the minimum your app needs.

```bash
docker run \
  --cap-drop=ALL \
  --cap-add NET_BIND_SERVICE \
  --security-opt no-new-privileges \
  -p 80:80 nginx:alpine
```

| Capability | Needed for |
|---|---|
| `NET_BIND_SERVICE` | Binding to ports < 1024 |
| `CHOWN` | Changing file ownership at runtime |
| `SETUID` / `SETGID` | Changing process UID/GID at runtime |
| `SYS_PTRACE` | Debuggers (never in production) |

- `--security-opt no-new-privileges` prevents `setuid` binaries from escalating privileges.

### Resource Limits (--memory / --cpus)

- **Why it exists** — An unconstrained container can consume all host CPU and memory, causing denial of service for every other workload on the node.
- **What it is** — Docker flags `--memory`, `--memory-swap`, `--cpus`, and `--pids-limit` map directly to Linux cgroup controls that the kernel enforces regardless of what the container process does.
- **One-liner** — Always set memory and CPU limits so one container cannot starve the host.

```bash
docker run \
  --memory=256m \
  --memory-swap=256m \
  --cpus=0.5 \
  --pids-limit=100 \
  myapp
```

- `--memory-swap` equal to `--memory` disables swap, preventing a container from silently using host swap.
- `--pids-limit` prevents fork-bomb style attacks.
- In Docker Compose use `mem_limit` / `cpus` under `deploy.resources` (Compose v3) or directly under the service (Compose v2).

### Minimal Base Images (alpine / distroless)

- **Why it exists** — Every package installed in a base image is a potential CVE; fewer packages means fewer vulnerabilities to patch and a smaller image to pull.
- **What it is** — Alpine Linux (~5 MB, musl libc, busybox) and Google Distroless images (no shell, no package manager, just the runtime) are minimal bases that drastically reduce attack surface and image size.
- **One-liner** — Use `alpine` or `distroless` as your base to minimise attack surface and image size.

```dockerfile
# Alpine — small general-purpose base
FROM python:3.12-alpine

# Multi-stage: build on full image, copy artefact into distroless
FROM golang:1.22 AS builder
WORKDIR /app
COPY . .
RUN go build -o server .

FROM gcr.io/distroless/static-debian12
COPY --from=builder /app/server /server
ENTRYPOINT ["/server"]
```

- Distroless has no shell, so `docker exec ... /bin/sh` is impossible — great for production.
- Use multi-stage builds to keep build tools (compilers, test runners) out of the final image.

### Image Scanning (Trivy / Snyk / Docker Scout)

- **Why it exists** — Images accumulate CVEs in OS packages and language dependencies; automated scanning in CI catches them before deployment.
- **What it is** — Static analysis tools that compare image layer contents against known CVE databases (NVD, GitHub Advisories, OS vendor feeds) and report vulnerabilities by severity.
- **One-liner** — Scan every image in CI and block on CRITICAL/HIGH findings before pushing to a registry.

```bash
# Trivy (free, fast, runs locally and in CI)
trivy image --severity CRITICAL,HIGH --exit-code 1 myapp:latest

# Docker Scout (built into Docker Desktop / Docker Hub)
docker scout cves myapp:latest

# Snyk (commercial, integrates with GitHub Actions)
snyk container test myapp:latest --severity-threshold=high
```

- Run scanning as a CI gate — fail the pipeline on CRITICAL findings.
- Rebuild and push images regularly even without code changes to pick up patched base images.
- Use `trivy fs .` to scan source dependencies before building the image.

### Security Checklist

- Build
  - `FROM` uses a minimal base (alpine, distroless, or a slim official variant)
  - Multi-stage build — no compiler or build tools in final image
  - `USER nonroot` (or equivalent non-root UID) as the last user-setting instruction
  - No secrets in `ENV`, `ARG`, `RUN`, or `COPY` instructions
  - `--secret` used for any build-time credentials
  - Image scanned with Trivy/Snyk/Docker Scout; no CRITICAL/HIGH CVEs
- Runtime
  - `--read-only` enabled; `--tmpfs` added for necessary write paths
  - `--cap-drop=ALL` with only required capabilities re-added
  - `--security-opt no-new-privileges` set
  - `--memory` and `--cpus` limits set
  - `--pids-limit` set
  - No `--privileged` flag
  - Secrets injected via environment, mounted file, or secrets manager — not baked in
- Registry / Supply Chain
  - Images tagged with immutable digest in production (not `:latest`)
  - Registry access controlled; only CI/CD pipeline can push
  - Base images rebuilt and re-scanned on a regular schedule
