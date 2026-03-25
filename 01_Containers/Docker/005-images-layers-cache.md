# Images, Layers, and Cache

- Each Dockerfile instruction creates a read-only layer; layers stack to form the final image filesystem.
- Docker caches layers by content hash; unchanged instructions reuse cached layers for faster builds.
- Multi-stage builds separate build tools from runtime, reducing final image size and attack surface.

# Architecture

```text
  Image (read-only)          Container (runtime)
  ┌──────────────────┐      ┌──────────────────┐
  │ Layer 3: COPY .  │      │ Writable layer   │ ← copy-on-write
  │ Layer 2: RUN npm │      ├──────────────────┤
  │ Layer 1: COPY pkg│      │ Layer 3 (shared) │
  │ Layer 0: FROM    │      │ Layer 2 (shared) │
  └──────────────────┘      │ Layer 1 (shared) │
         │                  │ Layer 0 (shared) │
    content-hash            └──────────────────┘
    (cache key)
```

- Image = stack of read-only layers, each identified by content hash.
- Container adds one thin writable layer on top; multiple containers share the same image layers.

# Mental Model

```text
docker build instruction N
  │
  ├─ Cache key = (parent layer hash + instruction + input files hash)
  │
  ├─ Match in cache? ──Yes──▶ Reuse cached layer (fast)
  │       │
  │      No
  ▼
  Execute instruction → new layer
  │
  ▼
  All subsequent layers: cache INVALIDATED
```

- Cache evaluation is per-instruction, top-to-bottom; one miss cascades to all following layers.
- For `COPY`/`ADD`: cache key includes file content hashes, not just instruction text.

# Core Building Blocks

### How Layers Work

- Each Dockerfile instruction (except a few like `ENV` that can be merged) creates a read-only layer.
- Layers are stacked; top layer is the final filesystem view.
- When you run a container, Docker adds a writable layer on top of the image layers; all writes go there (copy-on-write).
- Layer = diff from previous layer; stored by content hash; same layer can be shared across images.
- Each Dockerfile instruction creates a layer; layers are cached by content hash.
- Copy-on-write: container gets a thin writable layer on top of read-only image layers.

![Container layers with writable layer](../pic/container-layers.png)

Multiple containers from the same image share all read-only layers; each gets its own thin writable layer.

![Sharing layers across containers](../pic/sharing-layers.png)

### Why Order Matters

- Docker rebuilds from the first changed instruction; all layers after that are recreated.
- Put rarely changing steps first (e.g. base image, install system deps), frequently changing steps last (e.g. COPY app code).
- Example: If you `COPY . .` before `RUN npm install`, any file change invalidates cache for `RUN` and everything after; better: `COPY package*.json` first, `RUN npm ci`, then `COPY . .` so only code changes invalidate last steps.
- Cache invalidation cascades: one changed layer rebuilds all subsequent layers.

### Build Cache

- **Cache hit**: Instruction and all previous layers unchanged -- reuse cached layer.
- **Cache miss**: Instruction or input changed -- rebuild that layer and all following.
- `--no-cache`: Ignore cache; rebuild all layers (`docker build --no-cache`).
- **Cache from**: Use another image as cache source (e.g. previous build); advanced use for CI.

### Build Context

- **Context** = set of files sent to Docker daemon for COPY/ADD (usually current directory: `.`).
- Everything under the context path is sent (unless `.dockerignore` excludes it); large context = slow build.
- `.dockerignore`: Like `.gitignore`; exclude files/dirs from context; reduces size and avoids copying secrets or build artifacts.
- Never `COPY` secrets; use build-time secrets (`--secret`) or runtime env/volumes.
- `.dockerignore` excludes files from build context, reducing build time and preventing secret leaks.

```text
# .dockerignore
.git
node_modules
*.log
.env
dist
```

### Multi-Stage Build

- **Problem**: Building compilers and deps increases image size and attack surface.
- **Solution**: First stage (builder) compiles/builds; second stage copies only artifacts (binary, static files) into minimal base.
- Only the last stage's layers become the final image; earlier stages are discarded.
- `COPY --from=stage_name`: Copy from earlier stage or from any image.
- Multi-stage builds separate build dependencies from runtime, dramatically reducing image size.

```dockerfile
# Stage 1: build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: run
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Reducing Image Size

- Use **alpine** or **distroless** base when possible.
- **Multi-stage**: Don't ship build tools in final image.
- **Combine RUN** and clean in same layer: `RUN apt update && apt install -y pkg && rm -rf /var/lib/apt/lists/*` so cache doesn't keep deleted files.
- Avoid **ADD** for local archives (use `COPY` + `RUN` to extract) so you control what goes in.
- **Squash** (experimental or buildkit): Merge layers into one; reduces layers but can reduce cache reuse.
- `docker history <image>` shows layer sizes for debugging large images.

### BuildKit

- Modern build engine (enable with `DOCKER_BUILDKIT=1` or in daemon config).
- Parallel stage builds, better cache, `RUN --mount=type=cache` for persistent cache across builds.
- `--mount=type=secret`: Mount secret at build time without leaving it in image.
- BuildKit enables parallel builds, better caching, and secure secret mounting.

Related notes:
- [003-dockerfile](./003-dockerfile.md)
- [006-registry-tagging-push-pull](./006-registry-tagging-push-pull.md)

---

# Troubleshooting Guide

### Build is slow / not using cache
1. Check instruction order: put `COPY package*.json` + `RUN npm ci` before `COPY . .`.
2. Check if `.dockerignore` excludes unnecessary files (`node_modules`, `.git`, logs).
3. Enable BuildKit: `DOCKER_BUILDKIT=1 docker build .` -- parallel builds and better cache.

### Image unexpectedly large
1. Check layer sizes: `docker history <image>`.
2. Look for large RUN layers that install + don't clean: combine `apt install && rm -rf /var/lib/apt/lists/*`.
3. Use multi-stage build to exclude build tools from final image.
4. Check if `.dockerignore` is missing -- entire build context (including `.git`) may be copied.

### "layer does not exist" or "manifest unknown"
1. Image may have been deleted from registry or local cache.
2. Try `docker pull <image>` again.
3. If using digest, verify it still exists in registry.
