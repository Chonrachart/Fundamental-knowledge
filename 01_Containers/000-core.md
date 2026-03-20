# Containers

- Lightweight, isolated environment that packages an application with its dependencies and runs on a shared host kernel.
- Uses Linux namespaces (PID, net, mount, UTS, IPC, user) for isolation and cgroups for resource limits.
- Portable and reproducible: same image produces identical runtime on any host.

# Architecture

```text
┌─────────────────────────────────────────────────────┐
│                     Host OS (Linux Kernel)           │
│                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │ Container A  │  │ Container B  │  │Container C │ │
│  │ ┌──────────┐ │  │ ┌──────────┐ │  │┌──────────┐│ │
│  │ │   App    │ │  │ │   App    │ │  ││   App    ││ │
│  │ ├──────────┤ │  │ ├──────────┤ │  │├──────────┤│ │
│  │ │  Libs    │ │  │ │  Libs    │ │  ││  Libs    ││ │
│  │ └──────────┘ │  │ └──────────┘ │  │└──────────┘│ │
│  │  namespaces  │  │  namespaces  │  │ namespaces │ │
│  │  cgroups     │  │  cgroups     │  │ cgroups    │ │
│  └──────────────┘  └──────────────┘  └────────────┘ │
│                                                     │
│  ┌─────────────────────────────────────────────────┐ │
│  │          Container Runtime (containerd/runc)     │ │
│  └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘

vs VM:
┌──────────────┐  ┌──────────────┐
│     VM A     │  │     VM B     │
│ ┌──────────┐ │  │ ┌──────────┐ │
│ │   App    │ │  │ │   App    │ │
│ ├──────────┤ │  │ ├──────────┤ │
│ │ Guest OS │ │  │ │ Guest OS │ │
│ └──────────┘ │  │ └──────────┘ │
└──────┬───────┘  └──────┬───────┘
       └────────┬────────┘
         Hypervisor (KVM, VMware)
            Host OS
```

# Mental Model

```text
Dockerfile  ──build──▶  Image  ──run──▶  Container
                          │                  │
                        push/pull         logs/exec/stop
                          │
                       Registry
                    (Docker Hub, ECR)
```

Concrete example:
```bash
# Build image from Dockerfile
docker build -t myapp:1.0 .

# Push to registry
docker push registry.company.com/myapp:1.0

# Run container from image
docker run -d --name web -p 8080:80 myapp:1.0

# Check logs, exec into container
docker logs web
docker exec -it web sh
```

# Core Building Blocks

### Container vs VM

| Aspect | Container | VM |
|--------|-----------|-----|
| Isolation | Process-level (namespaces) | Hardware-level (hypervisor) |
| Kernel | Shares host kernel | Own guest kernel |
| Start time | Milliseconds | Seconds-minutes |
| Size | MBs (app + libs) | GBs (full OS) |
| Overhead | Minimal | High (CPU/RAM for guest OS) |
| Use case | App packaging, density, microservices | Strong isolation, different OS/kernel |

### Image Layers

- Image = stack of read-only layers; each Dockerfile instruction adds a layer.
- Layers are cached and shared across images by content hash.
- Copy-on-write: container gets a thin writable layer on top.

Related notes:
- [005-images-layers-cache](./Docker/005-images-layers-cache.md)

### Runtime Stack

```text
Docker CLI / docker compose
       │
  Docker Engine (dockerd)
       │
  containerd (container lifecycle)
       │
  runc (OCI runtime — actually creates the container)
       │
  Linux Kernel (namespaces + cgroups)
```

- **Namespaces**: PID, network, mount, UTS, IPC, user -- isolate what container can see.
- **cgroups**: Limit CPU, memory, I/O -- isolate what container can use.

### Orchestration

- Manage many containers across hosts: scheduling, scaling, self-healing, networking.
- **Kubernetes** is the standard; Docker Swarm, Nomad are alternatives.

Related notes:
- [../../02_Kubernetes/001-kubernetes-overview](../../02_Kubernetes/001-kubernetes-overview.md)

---

# Troubleshooting Guide

### Container exits immediately
1. Check exit code: `docker ps -a` (look at STATUS column).
2. Check logs: `docker logs <container>`.
3. Common causes: CMD/ENTRYPOINT fails, missing env vars, app crash.
4. Debug: `docker run -it --entrypoint sh <image>` to get a shell.

### "permission denied" inside container
1. Check what user runs: `docker exec <ctr> whoami` / `docker exec <ctr> id`.
2. Check file ownership: `docker exec <ctr> ls -la /path`.
3. Fix: `--user` flag at run, or `chown` in Dockerfile before `USER`.

### Cannot connect to container port
1. Verify port published: `docker port <container>`.
2. Verify app listens on correct port inside container: `docker exec <ctr> ss -tlnp`.
3. Check host firewall: `iptables -L -n` or `ufw status`.
4. Ensure `-p host:container` matches the app's listening port.

### Image pull fails
1. Check registry login: `docker login <registry>`.
2. Check image name/tag: typo or tag does not exist.
3. Check proxy: `docker info` shows HTTP_PROXY; set in `/etc/systemd/system/docker.service.d/http-proxy.conf`.
4. Check DNS: `nslookup registry-1.docker.io`.

---

# Quick Facts (Revision)

- Container shares host kernel; VM has its own guest OS.
- Image is immutable read-only layers; container adds a writable layer on top.
- Namespaces = what you can see; cgroups = what you can use.
- `docker build` creates image; `docker run` creates container; `docker push` uploads to registry.
- OCI = Open Container Initiative; standard for container format and runtime.
- containerd manages lifecycle; runc creates the actual container process.
- Alpine base images are ~5MB; distroless even smaller.

# Topic Map

- [Docker/000-core](./Docker/000-core.md) -- Docker overview, key commands, topic map
