Dockerfile
FROM
RUN
COPY
CMD
ENTRYPOINT
layer
cache

---

# Dockerfile

- Text file named `Dockerfile`; instructions build an image layer by layer.
- Each instruction (except a few) creates one layer; order affects cache and image size.

# FROM

- Base image; must be first non-comment instruction.
- Use specific tags: `alpine:3.19` not `alpine:latest`.
- Multi-stage: use multiple `FROM`; copy artifacts from earlier stage to reduce final size.

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

# RUN

- Run command in a new layer; shell form `RUN apt update` or exec form `RUN ["apt", "update"]`.
- Combine commands to reduce layers: `RUN apt update && apt install -y nginx && rm -rf /var/lib/apt/lists/*`.
- Avoid caching secrets in RUN; use build secrets (e.g. `--mount=type=secret`).

# COPY and ADD

- **COPY**: Copy files from build context into image; preferred (explicit).
- **ADD**: Can fetch URLs and extract tar; less predictable; use COPY when possible.
- `COPY src dest`; dest can be absolute or relative to WORKDIR.

```dockerfile
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
```

# CMD and ENTRYPOINT

- **CMD**: Default command when container runs; can be overridden by `docker run ... args`.
- **ENTRYPOINT**: Main executable; args from `docker run` append to it.
- Exec form preferred: `CMD ["nginx", "-g", "daemon off;"]` (no shell, proper signals).

```dockerfile
ENTRYPOINT ["/entrypoint.sh"]
CMD ["serve"]
# docker run myimg → /entrypoint.sh serve
# docker run myimg api → /entrypoint.sh api
```

# WORKDIR and ENV

- **WORKDIR**: Set working directory for following RUN, COPY, CMD, ENTRYPOINT.
- **ENV**: Set environment variable; visible at build and runtime.
- **EXPOSE**: Document which port the app listens on; does not publish (use `-p` at run).

# Best Practices

- Use minimal base images (alpine, distroless) to reduce size and attack surface.
- Run as non-root when possible (USER).
- Put rarely changing instructions first so cache is reused.
- Use .dockerignore to exclude files from build context.
- Pin versions for base image and packages.
