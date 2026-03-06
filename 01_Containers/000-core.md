overview of

    container
    image
    Docker
    runtime
    orchestration

---

# Container

- Isolated environment that runs an application and its dependencies.
- Shares host kernel; lighter than a VM.
- Portable: same image runs on dev, test, prod.

# Image

- Read-only template for a container; layers built from Dockerfile or pulled from registry.
- Immutable; tag for version (e.g. `nginx:1.24`).

# Docker

- Platform to build, ship, and run containers.
- Dockerfile defines image; `docker build` creates image; `docker run` starts container.

# Container vs VM

- **Container**: Shares host kernel; process isolation (namespaces, cgroups); fast start, low overhead.
- **VM**: Full guest OS; hypervisor; stronger isolation, heavier.
- Containers are good for app packaging and density; VMs for strong isolation or different kernels.

# Image Layers

- Image = stack of read-only layers; each Dockerfile instruction adds a layer.
- Layers are cached; change one instruction and only that layer and below rebuild.
- Copy-on-write: container gets writable layer on top of image layers.

# Runtime

- OCI runtime (e.g. runc) runs the container; Docker/containerd use it.
- Namespaces: PID, network, mount, UTS, IPC, user — isolate container from host.
- cgroups: limit CPU, memory, I/O.

# Orchestration

- Run and manage many containers: scheduling, scaling, healing, networking.
- Kubernetes is the common choice; Docker Swarm, Nomad are alternatives.

# Topic Map (basic → advanced)

- [Docker/001-docker-overview](./Docker/001-docker-overview.md) — Images, containers, registry (start here)
- [Docker/002-running-containers-basics](./Docker/002-running-containers-basics.md) — run, ps, logs, exec, stop, rm
- [Docker/003-dockerfile](./Docker/003-dockerfile.md) — Dockerfile instructions, FROM, RUN, COPY, CMD
- [Docker/004-docker-network-volume](./Docker/004-docker-network-volume.md) — Networking, volumes
- [Docker/005-images-layers-cache](./Docker/005-images-layers-cache.md) — Layers, cache, .dockerignore, multi-stage
- [Docker/006-registry-tagging-push-pull](./Docker/006-registry-tagging-push-pull.md) — Registry, tag, digest, push/pull
- [Docker/007-docker-run-advanced](./Docker/007-docker-run-advanced.md) — docker run flags, limits, env, restart
- [Docker/008-security-user-best-practices](./Docker/008-security-user-best-practices.md) — Non-root, secrets, scanning
- [Docker/009-compose-basics](./Docker/009-compose-basics.md) — Compose, services, networks, volumes
- [Docker/010-compose-production-patterns](./Docker/010-compose-production-patterns.md) — Healthcheck, profiles, scale, override
