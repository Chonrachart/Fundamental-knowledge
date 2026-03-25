# Registry, Tagging, Push, and Pull

- A registry is a server that stores and serves Docker/OCI images; Docker Hub is the default.
- Tags label image versions within a repository; digests pin exact content by hash.
- `docker push` uploads images; `docker pull` downloads them; authentication via `docker login`.

# Architecture

```text
  Registry (e.g. Docker Hub)
  └── Repository (e.g. nginx)
       ├── Tag: latest  ──▶ Manifest ──▶ Layer blobs
       ├── Tag: 1.24    ──▶ Manifest ──▶ Layer blobs
       └── Digest: sha256:abc... (immutable)
```

- **Registry** hosts multiple repositories; **repository** groups image versions under one name.
- **Tag** is a mutable pointer to a manifest; **digest** is an immutable content hash.
- Manifest references layer blobs; layers are shared across tags when content matches.

# Mental Model

```text
Push flow:
  docker push myregistry/app:v1
    │
    ├─ Check auth (docker login credentials)
    ├─ Upload layers (skip already-present blobs)
    └─ Upload manifest + tag

Pull flow:
  docker pull myregistry/app:v1
    │
    ├─ Resolve tag → manifest (or use digest)
    ├─ Download missing layer blobs
    └─ Assemble image locally
```

- Push uploads only new/changed layers; pull downloads only missing layers -- both are incremental.

# Core Building Blocks

### What Is a Registry

- **Registry** = server that stores and serves Docker images (and optionally OCI images).
- **Repository** = collection of images under a name (e.g. `nginx` has tags like `latest`, `alpine`).
- **Tag** = label for a specific image in a repo (e.g. `nginx:1.24-alpine`).
- Default registry for `docker pull`/`docker push` is Docker Hub (docker.io) unless you use a full image name with another host.
- Registry stores images; repository groups image versions; tag labels a specific version.

### Image Naming (Full Form)

- `registry_host[:port]/repository[:tag][@digest]`
- Examples:
  - `nginx` -- `docker.io/library/nginx:latest` (Docker Hub, library repo, latest tag).
  - `myorg/myapp:v1.0` -- `docker.io/myorg/myapp`, tag `v1.0`.
  - `ghcr.io/user/repo:main` -- GitHub Container Registry.
  - `123456789.dkr.ecr.region.amazonaws.com/myapp:prod` -- AWS ECR.
- **Tag** defaults to `latest` if omitted; **digest** pins exact content (e.g. `nginx@sha256:abc...`).
- Default registry is Docker Hub (docker.io); tag defaults to `latest` if omitted.

### Tagging Locally

- `docker tag` creates another tag pointing to the same image (same ID).
- Use for versioning before push: `docker tag myapp:1.0 myregistry.com/myapp:1.0`.
- `docker tag source target`: source can be existing tag or image ID.
- `docker tag` creates an alias; the underlying image ID stays the same.

```bash
docker build -t myapp:1.0 .
docker tag myapp:1.0 myregistry.com/myapp:1.0
```

### Push and Pull

- `docker push` uploads image to registry; you must be logged in and have write access to the repository.
- `docker pull` downloads image (and its layers); uses tag or digest.
- **Pull policy** at run time: always (default), missing (pull if not present), never; set with `--pull` at build/run.

```bash
docker login myregistry.com
docker push myregistry.com/myapp:1.0
docker pull myregistry.com/myapp:1.0
```

### Digest -- Immutable Reference

- **Digest** = content-addressable hash (e.g. sha256:abc123...); same digest always = same image content.
- **Tag** can be moved to a new image (e.g. latest); digest does not change when content is fixed.
- Use digest in production for reproducibility: `docker pull myapp@sha256:...`.
- `docker images --digests` shows digest for local images.
- Digest (sha256:...) is immutable; tags can be moved to point to different images.

### Private Registry and Login

- `docker login [registry]`: Store credentials; used for push/pull (default Docker Hub if no host).
- Credentials stored in config file (`~/.docker/config.json`); use credential helpers for secure storage.
- **Insecure registry**: For self-signed or HTTP registry, add daemon config (`insecure-registries`) and optionally use HTTP in image name.
- `docker login` stores credentials in `~/.docker/config.json`; use credential helpers for security.

### Common Registries

| Registry | Example image |
|----------|----------------|
| Docker Hub | docker.io/library/nginx, user/repo |
| GitHub (GHCR) | ghcr.io/owner/repo:tag |
| AWS ECR | account.dkr.ecr.region.amazonaws.com/repo:tag |
| Google GCR | gcr.io/project/repo:tag |
| Self-hosted | myregistry.company.com:5000/repo:tag |

### Best Practices

- Prefer tagging by version (v1.0, git sha) over always using `latest`.
- In CI/CD, push by digest or tag from commit SHA so every build is traceable.
- Use digest in production when you need exact image; re-pull by tag for "latest" of a stream.
- Avoid storing registry credentials in plain text; use credential helpers or orchestrator image pull secrets.
- Always tag by version or commit SHA in CI/CD; avoid relying on `latest` in production.

Related notes:
- [005-images-layers-cache](./005-images-layers-cache.md)

---

# Troubleshooting Guide

### "denied: requested access to the resource is denied"
1. Check login: `docker login <registry>`.
2. Check image name matches your repo: `docker tag myapp <registry>/<repo>:tag`.
3. Check write access to the repository.

### "manifest unknown" on pull
1. Tag does not exist: verify tag on registry (web UI or `docker manifest inspect`).
2. Check for typos in image name or tag.
3. If using digest, confirm it exists: `docker manifest inspect <image>@sha256:...`.

### Pull is slow or times out
1. Check proxy settings: `docker info | grep -i proxy`.
2. Check DNS: `nslookup registry-1.docker.io`.
3. For corporate environments: configure registry mirror in `/etc/docker/daemon.json`.
