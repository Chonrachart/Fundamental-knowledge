# Dockerfile

- Text file named `Dockerfile`; instructions build an image layer by layer.
- Each instruction (except a few) creates one read-only layer; order affects cache and image size. Related notes: [005-images-layers-cache](./005-images-layers-cache.md) for image layer details
- Common instructions: `FROM`, `RUN`, `COPY`, `ADD`, `WORKDIR`, `EXPOSE`, `CMD`, `ENTRYPOINT`.

# Architecture

```text
  Dockerfile instruction ──▶ Layer (read-only)
  ─────────────────────────────────────────────
  FROM alpine:3.19          → base layer
  RUN apk add nginx         → layer +1
  COPY nginx.conf /etc/     → layer +2
  COPY html/ /var/www/      → layer +3
  CMD ["nginx", "-g", ...]  → metadata (no layer)
  ─────────────────────────────────────────────
  Result: Image = stack of layers
```

- Each `FROM`, `RUN`, `COPY`, `ADD` creates a new layer; metadata instructions (`CMD`, `ENV`, `EXPOSE`) update config without adding a layer.
- Layers are content-hashed and cached; reused across builds if unchanged.

# Mental Model

```text
Build context (.) ──▶ Sent to daemon
                          │
              ┌───────────┴───────────┐
              ▼                       ▼
         Instruction 1           .dockerignore
         (cache hit?) ──Yes──▶ reuse layer
              │No
              ▼
         Execute + create layer
              │
         Instruction 2 ...
              │
              ▼
         Final image (tagged)
```

- Docker sends the build context to the daemon, then executes instructions top-to-bottom.
- Each instruction checks cache first; on miss, executes and invalidates cache for all following instructions.

# Core Building Blocks

### FROM

- Base image; must be first non-comment instruction.
- Use specific tags: `alpine:3.19` not `alpine:latest`.
- Multi-stage: use multiple `FROM`; copy artifacts from earlier stage to reduce final size.
- `FROM` must be the first instruction; it sets the base image.

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
```

Related notes:
- [005-images-layers-cache](./005-images-layers-cache.md)

### RUN

- Run command in a new layer; shell form `RUN apt update` or exec form `RUN ["apt", "update"]`.
- Combine commands to reduce layers: `RUN apt update && apt install -y nginx && rm -rf /var/lib/apt/lists/*`.
- Avoid caching secrets in RUN; use build secrets (e.g. `--mount=type=secret`).
- Each `RUN`/`COPY`/`ADD` creates a new layer; combine `RUN` commands to reduce layers.

### COPY and ADD

- **COPY**: Copy files from build context into image; preferred (explicit).
- **ADD**: Can fetch URLs and extract tar; less predictable; use COPY when possible.
- `COPY src dest`; dest can be absolute or relative to WORKDIR.
- `COPY` is preferred over `ADD` for local files; `ADD` can extract tars and fetch URLs.

```dockerfile
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
```

### CMD and ENTRYPOINT

- **CMD**: Default command when container runs; can be overridden by `docker run ... args`.
- **ENTRYPOINT**: Main executable; args from `docker run` append to it.
- Exec form preferred: `CMD ["nginx", "-g", "daemon off;"]` (no shell, proper signals).
- `CMD` sets default command (overridable); `ENTRYPOINT` sets main executable (args append).
- Exec form `["cmd", "arg"]` is preferred over shell form for proper signal handling.

```dockerfile
ENTRYPOINT ["/entrypoint.sh"]
CMD ["serve"]
# docker run myimg → /entrypoint.sh serve
# docker run myimg api → /entrypoint.sh api
```

### WORKDIR and ENV

- **WORKDIR**: Set working directory for following `RUN`, `COPY`, `CMD`, `ENTRYPOINT`.
- **ENV**: Set environment variable; visible at build and runtime.
- **EXPOSE**: Document which port the app listens on; does not publish (use `-p` at run).
- `WORKDIR` sets working directory; `ENV` sets environment variables for build and runtime.

### Best Practices

- Use minimal base images (alpine, distroless) to reduce size and attack surface.
- Run as non-root when possible (`USER`).
- Put rarely changing instructions first so cache is reused.
- Use `.dockerignore` to exclude files from build context.
- Pin versions for base image and packages.
- Order instructions from least-changing to most-changing for optimal cache usage.

Related notes:
- [005-images-layers-cache](./005-images-layers-cache.md)
- [008-security-user-best-practices](./008-security-user-best-practices.md)

---

# Troubleshooting Guide

### Build fails with "COPY failed: file not found"
1. Check file exists in build context (same dir as Dockerfile): `ls <file>`.
2. Check `.dockerignore` -- it may exclude the file.
3. Verify path is relative to build context, not `Dockerfile` location.

### Build cache not working (rebuilds every time)
1. Check if files copied before `RUN` changed: any file change invalidates cache for that `COPY` and all after.
2. Move `COPY package*.json` before `RUN npm ci`, then `COPY . .` after.
3. Check if `--no-cache` is being passed.

### CMD not running / container exits
1. Shell form `CMD command` runs under `/bin/sh -c` -- if `sh` missing (distroless), use exec form.
2. Exec form: `CMD ["node", "index.js"]` -- must be JSON array with double quotes.
3. If `ENTRYPOINT` is set, `CMD` becomes arguments to `ENTRYPOINT`.

### Image too large
1. Check base image: switch to `alpine` or `distroless`.
2. Use multi-stage build: build in first stage, copy only artifacts to final.
3. Combine `RUN` and clean in same layer: `RUN apt install && rm -rf /var/lib/apt/lists/*`.
