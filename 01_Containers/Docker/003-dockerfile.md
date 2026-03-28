# Dockerfile

# Overview

- **Why it exists** — You need a reproducible, version-controlled recipe that turns source code plus dependencies into a portable image anyone can build and run identically. A shell script is not portable; a Dockerfile is.
- **What it is** — A text file named `Dockerfile` containing ordered instructions. `docker build` reads them top-to-bottom, executes each one, and stacks the results as a series of read-only layers to produce the final image. Each instruction that changes the filesystem creates a new layer; metadata instructions (`CMD`, `ENV`, `EXPOSE`) update the image config without adding a layer.
- **One-liner** — A Dockerfile is a declarative, layer-by-layer recipe that `docker build` turns into a reproducible image.

# Architecture

```text
Dockerfile instructions          Image layers (content-hashed, cached)
──────────────────────────────   ────────────────────────────────────
FROM alpine:3.19              →  base layer     (pulled from registry)
RUN apk add --no-cache nginx  →  layer +1       (cached if unchanged)
COPY nginx.conf /etc/nginx/   →  layer +2       (cached if file unchanged)
COPY html/ /var/www/html/     →  layer +3       (invalidated if html/ changes)
EXPOSE 80                     →  image config   (no layer)
CMD ["nginx", "-g",           →  image config   (no layer)
     "daemon off;"]
──────────────────────────────   ────────────────────────────────────
docker build -t myapp:1.0 .   →  Final image = stacked layers + config
```

# Mental Model

```text
docker build -t myapp:1.0 .
        │
        ▼
  Build context (.) sent to daemon
  (.dockerignore filters what is sent)
        │
        ▼
  Instruction 1: FROM alpine:3.19
        │
        ▼
  Instruction 2: RUN apk add nginx
    ├─ Cache hit? ──Yes──▶ reuse existing layer (fast)
    └─ Cache miss? ──────▶ execute + create new layer
                            all subsequent layers are also rebuilt
        │
        ▼
  Instruction 3, 4, … (repeat)
        │
        ▼
  Tag final image → myapp:1.0
```

- Instructions execute top-to-bottom; a cache miss at instruction N rebuilds N and everything after.
- Put the slowest, most stable instructions first (system packages) and the most frequently changing last (application code).

# Core Building Blocks

### FROM — Base Image

- **Why it exists** — Every image must start from somewhere. `FROM` specifies the base filesystem that all subsequent instructions build on top of.
- **What it is** — The first non-comment instruction in every Dockerfile. It sets the starting layer. Use specific version tags (`alpine:3.19`, not `alpine:latest`) for reproducibility. A `FROM scratch` starts from an empty filesystem. Multiple `FROM` instructions in the same file create a multi-stage build (see Multi-Stage Builds section below).
- **One-liner** — `FROM` is mandatory and first; it sets the base image everything else builds on.

```dockerfile
# pinned tag — reproducible
FROM node:20-alpine

# named stage — used in multi-stage builds
FROM node:20-alpine AS builder
```

### RUN — Execute Commands

- **Why it exists** — You need to install packages, compile code, set permissions, or perform any build-time action that modifies the filesystem.
- **What it is** — Executes a command in a new layer on top of the current image. Two forms: shell form (`RUN apt update`) runs under `/bin/sh -c`; exec form (`RUN ["apt", "update"]`) bypasses the shell. Combine related commands with `&&` and clean up in the same `RUN` to avoid committing package caches into a layer.
- **One-liner** — Each `RUN` creates a new layer; chain commands with `&&` and clean up in the same step to keep image size small.

```dockerfile
# bad — package cache committed into the layer
RUN apt-get update
RUN apt-get install -y nginx

# good — update, install, and clean in one layer
RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx \
    && rm -rf /var/lib/apt/lists/*
```

### COPY vs ADD — Bringing Files In

- **Why it exists** — Your application source code, configs, and static assets live on the host; you need them inside the image at build time.
- **What it is** — `COPY src dest` copies files or directories from the build context into the image. `ADD src dest` does the same but also extracts local `.tar` archives and can fetch remote URLs. Use `COPY` by default — it is explicit and predictable. Use `ADD` only when you specifically need its tar-extraction feature. Path `dest` is relative to `WORKDIR` if set.
- **One-liner** — Prefer `COPY` for local files; `ADD` only when you need automatic tar extraction.

```dockerfile
WORKDIR /app

# copy dependency manifests first (cache-friendly)
COPY package*.json ./
RUN npm ci

# copy application source last (changes most often)
COPY . .
```

### CMD vs ENTRYPOINT — Defining What Runs

- **Why it exists** — The image must know what process to start when `docker run` is called. You need a way to specify that default command and control whether it can be overridden by the caller.
- **What it is** — `CMD` sets the default command (or default arguments) for the container; it is fully overridden if the user passes a command to `docker run`. `ENTRYPOINT` sets the fixed executable; arguments from `docker run` are appended to it instead of replacing it. Use exec form (`["executable", "arg"]`) for both — it avoids a shell wrapper and ensures PID 1 receives signals correctly. When both are set, `ENTRYPOINT` is the executable and `CMD` supplies default arguments.
- **One-liner** — `CMD` is the overridable default command; `ENTRYPOINT` is the fixed executable that `docker run` args are appended to.

```dockerfile
# CMD only — easily overridden
CMD ["nginx", "-g", "daemon off;"]

# ENTRYPOINT + CMD — fixed executable, overridable default args
ENTRYPOINT ["/entrypoint.sh"]
CMD ["serve", "--port", "8080"]
# docker run myimg              → /entrypoint.sh serve --port 8080
# docker run myimg api --port 9090 → /entrypoint.sh api --port 9090
```

| Form | PID 1 | Signal handling | Override by docker run |
|------|-------|-----------------|------------------------|
| `CMD ["node","app.js"]` exec | node | correct | full override |
| `CMD node app.js` shell | /bin/sh | broken (sh gets signal) | full override |
| `ENTRYPOINT ["node","app.js"]` | node | correct | args append |

### WORKDIR, ENV, and EXPOSE — Environment Setup

- **Why it exists** — You need a predictable working directory so that relative paths in `COPY`, `RUN`, and `CMD` resolve consistently. Environment variables configure the app at build and runtime. `EXPOSE` documents which port the service listens on.
- **What it is** — `WORKDIR /app` sets (and creates if needed) the working directory for all subsequent instructions and for the running container. `ENV KEY=value` sets environment variables visible during the build and inside the running container. `EXPOSE 8080` is documentation only — it does not publish the port; you still need `-p` at `docker run`. Use `ARG` for build-time-only variables that should not leak into the final image.
- **One-liner** — `WORKDIR` anchors relative paths, `ENV` injects runtime config, and `EXPOSE` documents (but does not publish) the listening port.

```dockerfile
WORKDIR /app
ENV NODE_ENV=production \
    PORT=8080
EXPOSE 8080
```

### Multi-Stage Builds

- **Why it exists** — Build tools (compilers, test runners, `node_modules` with devDependencies) are needed at build time but bloat the final runtime image and expand the attack surface.
- **What it is** — A Dockerfile with multiple `FROM` instructions. Each `FROM` starts a new stage with a fresh filesystem. You use `COPY --from=<stage>` to selectively copy compiled artifacts from an earlier stage into the final, minimal stage. Only the last stage ends up in the final image; all intermediate stages are discarded.
- **One-liner** — Multi-stage builds let you build in a fat image and ship only the compiled output in a minimal runtime image.

```dockerfile
# Stage 1: build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: runtime — only dist/ is copied in; no node_modules, no dev tools
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Best Practices — Layer Order, Non-Root, Minimal Base

- **Why it exists** — Poor Dockerfile habits cause slow builds (cache busts on every change), oversized images (hundreds of MB for a static binary), and security vulnerabilities (running as root, unnecessary packages).
- **What it is** — A set of discipline rules applied when writing any Dockerfile:
  - Order instructions from least-changing to most-changing — base image and package installs first, application source last.
  - Copy dependency manifests (`package.json`, `requirements.txt`, `go.mod`) and install before copying source so the install layer is cached on code-only changes.
  - Use minimal base images: `alpine`, `distroless`, or `scratch` reduce size and attack surface.
  - Drop root: add a non-root user with `RUN adduser` and switch with `USER`.
  - Use `.dockerignore` to exclude `.git`, `node_modules`, test data, and secrets from the build context.
  - Pin base image and package versions for reproducible builds.
- **One-liner** — Stable things first for cache efficiency; minimal base and non-root for security; `.dockerignore` to keep the context clean.

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app

# 1. install deps (cached unless package.json changes)
COPY package*.json ./
RUN npm ci --only=production

# 2. copy source (invalidates cache on any code change)
COPY . .
RUN npm run build

FROM node:20-alpine
WORKDIR /app

# non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules

EXPOSE 3000
CMD ["node", "dist/index.js"]
```

# Troubleshooting

### Build fails with "COPY failed: file not found"

1. Verify the file exists in the build context: `ls <file>` from the directory you run `docker build` in.
2. Check `.dockerignore` — it may be excluding the file unintentionally.
3. Confirm the path is relative to the build context root, not to the `Dockerfile`'s location.

### Build cache not working — rebuilds every time

1. Identify the first instruction that misses cache: any change to a file copied before a `RUN` invalidates that `RUN` and everything after.
2. Fix instruction order: `COPY package*.json ./` and `RUN npm ci` before `COPY . .`.
3. Check that `--no-cache` is not being passed in the build command.

### CMD not running / container exits immediately

1. Shell form (`CMD command`) spawns `/bin/sh -c` — if the base image has no shell (e.g. distroless), use exec form.
2. Exec form must be a valid JSON array with double quotes: `CMD ["node", "index.js"]`.
3. If `ENTRYPOINT` is also set, `CMD` becomes its arguments — make sure they are compatible.

### Image too large

1. Check the base image: switch from `ubuntu` to `alpine` or `distroless`.
2. Apply a multi-stage build: compile in stage 1, copy only the binary/dist to stage 2.
3. Ensure `RUN` cleans up in the same layer: `RUN apt install pkg && rm -rf /var/lib/apt/lists/*`.
4. Use `docker history <image>` to identify which layer is large and target it.
