# Docker Registries, Tagging, Push & Pull

### Overview

- **Why it exists** — Container images need a central place to be stored, versioned, and distributed so any machine or team member can pull the exact same image.
- **What it is** — A registry is a server that stores and serves Docker image layers and manifests. Images are referenced by a full name: `registry/repository:tag@digest`. You interact with registries using `docker tag`, `docker push`, and `docker pull`.
- **One-liner** — Registries are the package repositories of the container world: build once, push once, pull anywhere.

### Architecture

```text
┌──────────────────────────────────────────────────────────────────┐
│                       Developer Machine                          │
│                                                                  │
│   docker build  ──▶  Local Image Cache                          │
│                            │                                     │
│               docker tag   │   docker push                      │
│                            ▼                                     │
│                  registry/repo:tag                               │
└────────────────────────────┬─────────────────────────────────────┘
                             │  HTTPS (port 443)
              ┌──────────────┴──────────────────┐
              │            Registry              │
              │                                  │
              │  ┌────────────┐  ┌────────────┐  │
              │  │  Manifest  │  │   Layers   │  │
              │  │   (JSON)   │  │  (tar.gz)  │  │
              │  └────────────┘  └────────────┘  │
              │                                  │
              │  repos:  myapp, nginx, postgres   │
              └──────────────┬───────────────────┘
                             │  docker pull
              ┌──────────────┴──────────────────┐
              │  CI/CD Runner  │  Prod Server    │
              └─────────────────────────────────┘
```

### Mental Model

```text
Full image reference:   registry / repository : tag @ digest
                           │           │          │       │
                     docker.io     myuser/app   latest  sha256:abc...
                      (default)

docker build  ──▶  image exists locally (unnamed image ID)
docker tag    ──▶  attaches a full registry/repo:tag name to that image
docker push   ──▶  uploads layers + manifest to registry
docker pull   ──▶  downloads layers + manifest from registry
```

- Tags are mutable pointers — `latest` can be reassigned to a new image at any time.
- Digests are immutable SHA256 hashes of the manifest — pinning a digest guarantees reproducibility.
- If no registry is specified, Docker defaults to `docker.io` (Docker Hub).
- If no tag is specified, Docker defaults to `:latest`.

### Core Building Blocks

### Registry

- **Why it exists** — Developers and CI pipelines need a shared, persistent store for built images so they do not have to be rebuilt on every machine.
- **What it is** — A server implementing the OCI Distribution Specification. It stores image manifests (JSON metadata) and layers (compressed filesystem tarballs) content-addressed by digest. Clients authenticate with a token and transfer data over HTTPS. A registry contains many repositories; each repository groups image versions under one name.
- **One-liner** — A registry is a versioned image warehouse accessible over HTTPS.

Common registries:

| Registry | Host | Notes |
|---|---|---|
| Docker Hub | `docker.io` | Default; free public, paid private |
| GitHub Container Registry | `ghcr.io` | Tied to GitHub packages |
| Amazon ECR | `<account>.dkr.ecr.<region>.amazonaws.com` | AWS-native, IAM auth |
| Google Artifact Registry | `<region>-docker.pkg.dev` | GCP-native, Workload Identity |
| Self-hosted | any hostname | Run your own with `registry:2` |

```bash
# Run a local registry
docker run -d -p 5000:5000 --name registry registry:2
```

### Image Naming

- **Why it exists** — A single registry holds thousands of repositories; a structured naming scheme uniquely identifies any image at any version across any registry.
- **What it is** — The full image reference is `registry/repository:tag@digest`. Registry defaults to `docker.io`, tag defaults to `latest`. The digest (`@sha256:...`) pins to an exact manifest and overrides the tag resolution.
- **One-liner** — The image name is the address that tells Docker exactly where to find a specific version of an image.

```text
Full form:
  docker.io/library/nginx:1.27.0@sha256:4c0fdaa8b6341bfdeca5f18f7837462567c9a1ae4...

Short forms accepted by Docker:
  nginx                          →  docker.io/library/nginx:latest
  nginx:1.27                     →  docker.io/library/nginx:1.27
  myuser/myapp:v2                →  docker.io/myuser/myapp:v2
  ghcr.io/org/service:main       →  (explicit registry, explicit tag)
```

### Tagging

- **Why it exists** — Builds produce an unnamed image ID; tagging attaches a human-readable, pushable name that maps to a registry location.
- **What it is** — `docker tag SOURCE TARGET` creates an alias. The source can be an image ID or an existing tag. The target is the full `registry/repo:tag` reference. Tagging does not copy data — both names point to the same image layers with the same image ID.
- **One-liner** — `docker tag` is like a symlink: a new name pointing at the same image content.

```bash
# Tag a local build for Docker Hub
docker tag myapp:build myuser/myapp:v1.2.0

# Tag the same build as latest
docker tag myapp:build myuser/myapp:latest

# Tag for ECR
docker tag myapp:build 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:v1.2.0

# Tag by image ID
docker tag a1b2c3d4e5f6 myuser/myapp:v1.2.0
```

### Push and Pull

- **Why it exists** — Images built locally must be distributed to servers and CI systems; `push` uploads them and `pull` downloads them.
- **What it is** — `docker push` uploads only the layers the registry does not yet have (deduplication by digest), then uploads the manifest. `docker pull` downloads missing layers and the manifest into the local image cache. Both commands require the image name to include the registry host (or default to Docker Hub). You must be logged in to push to a private repository.
- **One-liner** — `push` uploads an image to a registry; `pull` downloads it.

```bash
# Push to Docker Hub
docker push myuser/myapp:v1.2.0

# Pull by tag
docker pull myuser/myapp:v1.2.0

# Pull by digest (immutable, reproducible)
docker pull myuser/myapp@sha256:4c0fdaa8b6341bfdeca5f18f7837462567c9a1ae4...

# Pull from ECR (after login)
docker pull 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:v1.2.0
```

### Digest

- **Why it exists** — Tags are mutable and can change; production deployments need a way to lock to an exact, immutable version.
- **What it is** — A digest is the SHA256 hash of the image manifest. It never changes — the same content always produces the same digest. A tag is a mutable pointer stored in the registry that can be updated to point to a new digest at any time. Pulling by digest (`@sha256:...`) always retrieves the same image regardless of tag changes.
- **One-liner** — Tags are mutable labels; digests are immutable fingerprints.

| | Tag | Digest |
|---|---|---|
| Mutable | Yes — can be reassigned | No — content-addressed |
| Human-readable | Yes | No (SHA256 hex) |
| Reproducible deploys | No | Yes |
| Usage | Day-to-day reference | Pinning for production/CI |

```bash
# Find the digest of a local image
docker inspect --format='{{index .RepoDigests 0}}' nginx:latest

# Pull by digest to pin exactly
docker pull nginx@sha256:4c0fdaa8b6341bfdeca5f18f7837462567c9a1ae4...

# Inspect manifest and digest on registry
docker buildx imagetools inspect nginx:latest
```

### Private Registry Login

- **Why it exists** — Private registries require authentication to prevent unauthorized access to proprietary images.
- **What it is** — `docker login` stores credentials (username/password or token) in `~/.docker/config.json` or the system credential store. For cloud registries, a short-lived token is obtained from the cloud provider's CLI and piped to `docker login`. Stored credentials are automatically sent on every push/pull to the matching registry host.
- **One-liner** — `docker login` stores your credentials so push and pull can authenticate automatically.

```bash
# Docker Hub
echo "$DOCKER_TOKEN" | docker login -u myuser --password-stdin

# GitHub Container Registry
echo "$GITHUB_TOKEN" | docker login ghcr.io -u USERNAME --password-stdin

# Amazon ECR (token valid for 12 hours)
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
    123456789.dkr.ecr.us-east-1.amazonaws.com

# Google Artifact Registry
gcloud auth configure-docker us-central1-docker.pkg.dev

# Logout
docker logout docker.io
```

### Troubleshooting

### `denied: requested access to the resource is denied` on push

1. Confirm you are logged in: `docker login <registry>`.
2. Verify the image tag includes your username or org: `myuser/myapp:tag`, not just `myapp:tag`.
3. For ECR, the token expires after 12 hours — re-run `aws ecr get-login-password | docker login ...`.
4. Verify you have write permission on the repository in the registry UI or IAM policy.

### `manifest unknown` or `pull access denied`

1. Check the full image name for typos: `docker pull registry/repo:tag`.
2. Verify the tag exists on the registry: `docker buildx imagetools inspect <image>`.
3. If the repository is private, confirm you are logged in with the correct account.
4. For ECR, confirm the repository exists: `aws ecr describe-repositories`.

### Image push is slow or fails mid-transfer

1. Check available disk space: `docker system df`.
2. Retry — layer uploads are resumable; already-uploaded layers are skipped.
3. Check proxy settings: `docker info | grep -i proxy`; set `HTTP_PROXY`/`HTTPS_PROXY` in `/etc/docker/daemon.json` if needed.
4. Reduce image size with multi-stage builds to minimize layer count.

### Tag points to a different image than expected after pull

1. Tags are mutable — another push may have moved the tag to a newer image.
2. Use digest pinning for reproducibility: `docker pull myimage@sha256:...`.
3. Record the digest at build time: `docker inspect --format='{{index .RepoDigests 0}}' myimage:tag`.
