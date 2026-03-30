# Containers

# Overview

- **Why it exists** — Applications need a consistent, isolated environment to run regardless of host OS differences, without the overhead of full virtual machines.
- **What it is** — A lightweight, isolated runtime environment that packages an application with its dependencies, using Linux namespaces for isolation and cgroups for resource limits, sharing the host kernel.
- **One-liner** — Containers are isolated processes on a shared kernel — portable, fast to start, and far lighter than VMs.

# Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                     Host OS (Linux Kernel)                  │
│                                                             │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐   │
│  │  Container A  │  │  Container B  │  │  Container C  │   │
│  │ ┌───────────┐ │  │ ┌───────────┐ │  │ ┌───────────┐ │   │
│  │ │    App    │ │  │ │    App    │ │  │ │    App    │ │   │
│  │ ├───────────┤ │  │ ├───────────┤ │  │ ├───────────┤ │   │
│  │ │   Libs    │ │  │ │   Libs    │ │  │ │   Libs    │ │   │
│  │ └───────────┘ │  │ └───────────┘ │  │ └───────────┘ │   │
│  │  namespaces   │  │  namespaces   │  │  namespaces   │   │
│  │  cgroups      │  │  cgroups      │  │  cgroups      │   │
│  └───────────────┘  └───────────────┘  └───────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │          Container Runtime (containerd / runc)      │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘

vs VM:
┌──────────────┐  ┌──────────────┐
│     VM A     │  │     VM B     │
│ ┌──────────┐ │  │ ┌──────────┐ │
│ │   App    │ │  │ │   App    │ │
│ ├──────────┤ │  │ ├──────────┤ │
│ │ Guest OS │ │  │ │ Guest OS │ │
│ └──────────┘ │  │ └──────────┘ │
└──────┬───────┘  └──────┬───────┘
       └────────┬─────────┘
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

- Write a `Dockerfile` (recipe), `docker build` produces an immutable image.
- `docker run` creates a container (running process) from the image.
- Containers are ephemeral; state not in a volume is lost on removal.
- `docker push` / `docker pull` move images between host and registry.

# Core Building Blocks

### Namespaces

- **Why it exists** — Processes on the same kernel must not see or interfere with each other's resources.
- **What it is** — Linux kernel feature that partitions global resources into independent views per container: `PID` (process tree), `net` (network stack), `mount` (filesystem), `UTS` (hostname), `IPC` (inter-process comms), `user` (UID mapping).
- **One-liner** — Namespaces control what a container can see.

### cgroups

- **Why it exists** — Without limits, one container can starve the host or other containers of CPU and memory.
- **What it is** — Linux control groups; enforce per-container limits and accounting for CPU, memory, I/O, and network bandwidth. The kernel refuses to let a container exceed its cgroup quota.
- **One-liner** — cgroups control what a container can use.

### Container Runtime Stack

- **Why it exists** — A layered runtime stack separates high-level container management from the low-level Linux primitives that create processes.
- **What it is** — The chain from user-facing tooling down to the kernel: a high-level runtime (`containerd`) manages lifecycle; a low-level OCI runtime (`runc`) calls clone/unshare to actually create namespaced processes.
- **One-liner** — `containerd` manages the lifecycle; `runc` creates the actual container process.

```text
Docker CLI / docker compose
       │
  Docker Engine (dockerd)
       │
  containerd  (container lifecycle manager)
       │
  runc  (OCI runtime — calls Linux clone/unshare)
       │
  Linux Kernel (namespaces + cgroups)
```

- OCI = Open Container Initiative; defines the standard image format and runtime spec.
- `runc` is the reference OCI runtime; `crun` and `gVisor runsc` are alternatives.

### Container vs VM

- **Why it exists** — Teams need to choose the right isolation model for their workload.
- **What it is** — A comparison of how containers and VMs achieve isolation at different levels of the stack.
- **One-liner** — Containers share the kernel and start in milliseconds; VMs carry a full guest OS and start in seconds.

| Aspect | Container | VM |
|---|---|---|
| Isolation | Process-level (namespaces) | Hardware-level (hypervisor) |
| Kernel | Shares host kernel | Own guest kernel |
| Start time | Milliseconds | Seconds–minutes |
| Size | MBs (app + libs) | GBs (full OS) |
| Overhead | Minimal | High (CPU/RAM for guest OS) |
| Use case | App packaging, density, microservices | Strong isolation, different OS/kernel |

### Image Layers

- **Why it exists** — Building images from scratch every time would be slow; layers enable caching and sharing.
- **What it is** — An image is a stack of read-only layers; each Dockerfile instruction adds one. Layers are identified by content hash and shared across images. A running container gets a thin writable layer on top.
- **One-liner** — Images are immutable layered snapshots; containers add a writable layer on top.

- Layers are cached: unchanged instructions reuse the cached layer on rebuild.
- Copy-on-write: writing inside a container modifies only the writable layer, not the image.
- Alpine base images are ~5 MB; distroless images are even smaller.

Related notes:
- [Docker/005-images-layers-cache](./Docker/005-images-layers-cache.md)

### Docker Subfolder

- Docker is the most common toolchain built on top of the container runtime stack.
- The Docker subfolder covers the full Docker platform: CLI, daemon, images, Dockerfile, networking, volumes, registries, and Compose.

Related notes:
- [Docker/000-core](./Docker/000-core.md) — Docker overview, key commands, topic map
