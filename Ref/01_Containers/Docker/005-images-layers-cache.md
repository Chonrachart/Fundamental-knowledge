# Images, Layers, and Cache

# Overview

- **Why it exists** — Building images from scratch on every change would be slow and wasteful; a layered, cacheable system lets Docker reuse unchanged work and share common layers across images to save time and disk space.
- **What it is** — A Docker image is an ordered stack of read-only layers, one per Dockerfile instruction that changes the filesystem. At runtime a thin writable layer is added on top. Docker's build cache maps each layer to a content hash so unchanged instructions are skipped. Multi-stage builds and BuildKit extend this with advanced cache control and secrets handling.
- **One-liner** — Images are immutable layer stacks where Docker reuses cached layers for fast, incremental builds.

# Architecture

```text
┌──────────────────────────────────────────────────────────┐
│                   Image Layer Stack                      │
│                                                          │
│   ┌─────────────────────────────────┐  ← writable layer │
│   │  Container Layer (read-write)   │    (runtime only)  │
│   └─────────────────────────────────┘                    │
│   ┌─────────────────────────────────┐                    │
│   │  Layer 4: COPY . /app  (app src)│  ← changes often  │
│   └─────────────────────────────────┘                    │
│   ┌─────────────────────────────────┐                    │
│   │  Layer 3: RUN npm install       │  ← changes rarely  │
│   └─────────────────────────────────┘                    │
│   ┌─────────────────────────────────┐                    │
│   │  Layer 2: COPY package*.json .  │  ← cache anchor   │
│   └─────────────────────────────────┘                    │
│   ┌─────────────────────────────────┐                    │
│   │  Layer 1: FROM node:18          │  ← base image      │
│   └─────────────────────────────────┘                    │
│                                                          │
│   Layer sharing across images:                           │
│                                                          │
│   image-a      image-b      image-c                      │
│   ┌──────┐     ┌──────┐     ┌──────┐                    │
│   │ L4-a │     │ L4-b │     │ L4-c │  unique per image  │
│   ├──────┤     ├──────┤     └──┬───┘                    │
│   │ L3-a │     │ L3-ab│        │     shared layer on    │
│   └──┬───┘     └──┬───┘        │     disk — one copy    │
│      └────────────┴────────────┘                        │
│                 shared base                              │
└──────────────────────────────────────────────────────────┘
```

# Mental Model

```text
docker build .
      │
      ▼
For each Dockerfile instruction:
      │
      ├──▶ Compute cache key (instruction text + parent layer hash)
      │
      ├──▶ Cache HIT? ──▶ reuse existing layer, skip execution
      │
      └──▶ Cache MISS? ──▶ execute instruction, create new layer
                            ALL subsequent layers also miss cache
                            (cache is invalidated from this point down)


docker run <image>
      │
      ▼
Stack read-only image layers  +  add thin read-write container layer
      │
      ▼
Copy-on-Write (CoW): container reads from image layers directly;
only modified files are copied up to the writable layer
```

- Instruction order is critical — put rarely-changing instructions (FROM, RUN apt-get) near the top and frequently-changing ones (COPY source code) near the bottom.
- A single changed instruction busts the cache for every instruction below it.
- `.dockerignore` prevents large or sensitive host files from being sent to the daemon as build context, which speeds up every build.
- Multi-stage builds use multiple `FROM` statements; only the final stage is shipped, so build tools never reach production.
- BuildKit is the modern builder (default since Docker 23) — it parallelises independent stages and unlocks `--mount` cache and secret flags.

# Core Building Blocks

### Image Layers (Read-Only Stack)

- **Why it exists** — Storing the full filesystem for every image separately would waste enormous disk space; sharing common layers between images keeps storage and transfer costs low.
- **What it is** — Each Dockerfile instruction that modifies the filesystem (`RUN`, `COPY`, `ADD`) produces a new read-only layer identified by a SHA256 content hash. Layers are stacked using a union filesystem (overlayfs). Multiple images that share a base layer reference the same on-disk data — no duplication.
- **One-liner** — Image layers are immutable, content-addressed filesystem diffs that are shared across images.

```bash
# Inspect layers of an image
docker image inspect nginx --format '{{.RootFS.Layers}}'

# See layer-by-layer history and sizes
docker image history nginx

# See how much space is shared vs unique
docker system df -v
```

### Build Cache

- **Why it exists** — Re-executing every instruction on every build (compiling dependencies, running apt-get) would make iterative development unbearably slow.
- **What it is** — Before executing an instruction, Docker computes a cache key from the instruction text and the parent layer's hash. For `COPY`/`ADD`, file content is also included. If a matching key exists in the cache, the stored layer is reused. Once any instruction misses, all subsequent instructions also miss — cache is sequential.
- **One-liner** — The build cache skips unchanged instructions by matching a content-derived key, invalidating everything below the first change.

```bash
# Force full rebuild, ignoring cache
docker build --no-cache -t myapp .

# Good order: stable dependencies before volatile source code
# BAD — copies all source first, cache busts on any file change:
# COPY . /app
# RUN npm install

# GOOD — copies only package files, installs, then copies source:
# COPY package.json package-lock.json /app/
# RUN npm install
# COPY . /app
```

### .dockerignore

- **Why it exists** — The entire build context directory is sent to the Docker daemon before building; without filtering, `.git`, `node_modules`, test data, and secrets slow every build and may leak into the image.
- **What it is** — A `.dockerignore` file in the build context root lists patterns (same syntax as `.gitignore`) of paths to exclude from the context tarball sent to the daemon. Excluded files are not available to `COPY` or `ADD` instructions and never appear in any layer.
- **One-liner** — `.dockerignore` is the allowlist filter that keeps the build context lean and secrets out of images.

```text
# .dockerignore example
.git
node_modules
*.log
.env
tests/
docs/
*.md
```

```bash
# See how large the build context is (printed at start of docker build)
docker build . 2>&1 | head -3
# Sending build context to Docker daemon  4.096kB
```

### Multi-Stage Builds

- **Why it exists** — Build tools (compilers, test runners, dev dependencies) are needed to produce an artifact but must not ship to production — they bloat the image and expand the attack surface.
- **What it is** — A Dockerfile can contain multiple `FROM` statements, each starting a new stage with its own layer set. Artifacts are copied from one stage to another with `COPY --from=<stage>`. Only the final stage becomes the shipped image; earlier stages are discarded after the build.
- **One-liner** — Multi-stage builds let you compile in a fat build image and ship only the binary in a minimal runtime image.

```dockerfile
# Stage 1: build
FROM node:18 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build          # produces /app/dist

# Stage 2: runtime — only dist/ is copied, no node_modules, no src
FROM node:18-alpine AS runtime
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

```bash
# Build only up to a specific stage (useful for debugging)
docker build --target builder -t myapp:builder .

# Final image contains only the runtime stage
docker build -t myapp:prod .
docker image history myapp:prod   # no compiler layers visible
```

### BuildKit

- **Why it exists** — The classic builder is sequential and has no way to pass secrets safely or cache package manager downloads across builds; BuildKit solves all three.
- **What it is** — Docker's next-generation build engine (default since Docker 23.0). Key features: parallel execution of independent stages, `--mount=type=cache` to persist package manager caches between builds, `--mount=type=secret` to inject secrets at build time without baking them into a layer, and `--mount=type=ssh` for SSH agent forwarding.
- **One-liner** — BuildKit is the modern build backend that adds parallelism, persistent caches, and safe secret handling to Docker builds.

```dockerfile
# syntax=docker/dockerfile:1

FROM python:3.12-slim

# Cache pip downloads across builds — never stored in a layer
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# Inject a secret at build time — never appears in any layer
RUN --mount=type=secret,id=gh_token \
    curl -H "Authorization: token $(cat /run/secrets/gh_token)" \
         https://api.github.com/repos/org/private-repo/tarball -o pkg.tar.gz
```

```bash
# Enable BuildKit (already default in Docker 23+)
DOCKER_BUILDKIT=1 docker build -t myapp .

# Pass a secret file
docker build --secret id=gh_token,src=~/.gh_token -t myapp .

# Build multiple stages in parallel (BuildKit does this automatically)
docker build -t myapp .
```

| Feature                    | Classic Builder | BuildKit     |
|----------------------------|-----------------|--------------|
| Parallel stage execution   | No              | Yes          |
| `--mount=type=cache`       | No              | Yes          |
| `--mount=type=secret`      | No              | Yes          |
| Default since Docker 23    | No              | Yes          |
| Dockerfile syntax version  | Implicit        | `# syntax=`  |
