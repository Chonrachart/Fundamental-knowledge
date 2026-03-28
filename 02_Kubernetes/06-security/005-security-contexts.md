# Security Contexts

### Overview
- **Why it exists** — Container runtimes run as root by default and have broad Linux capabilities. A compromised container that runs as root with no restrictions can escape to the host, read sensitive files, or overwrite system binaries. Security contexts let you strip away privileges the container never needed — defense in depth at the workload level.
- **What it is** — A set of fields on a Pod (`spec.securityContext`) or on an individual container (`spec.containers[].securityContext`) that control the Linux security attributes of that pod or container: UID/GID, Linux capabilities, filesystem write access, and privilege escalation.
- **One-liner** — Security contexts let you run containers with the minimum Linux privileges they need, reducing blast radius if a container is compromised.

### Architecture (ASCII)

```text
  Pod spec
  ├── spec.securityContext          (pod-level — applies to ALL containers)
  │     runAsUser: 1000
  │     runAsGroup: 3000
  │     fsGroup: 2000              (volume ownership)
  │     runAsNonRoot: true
  │
  └── spec.containers[]
        └── securityContext        (container-level — overrides pod-level)
              allowPrivilegeEscalation: false
              readOnlyRootFilesystem: true
              capabilities:
                drop: ["ALL"]
                add: ["NET_BIND_SERVICE"]
              privileged: false

  Container-level fields OVERRIDE pod-level fields for that container.
  Pod-level fields apply to all containers that don't override them.
```

### Mental Model

Think of a freshly-started container as an employee with a master key to every room. Security contexts are the policy that says: "Actually, you only need access to room 42. Here is a key only for room 42, and we've removed your ability to copy keys." The employee can still do their job, but a break-in through that employee's credentials causes far less damage.

Two levels:
- **Pod-level** (`spec.securityContext`) — shared settings for the whole pod, mainly around user/group identity and volume permissions.
- **Container-level** (`spec.containers[].securityContext`) — per-container settings, mainly around capabilities and filesystem access. Overrides pod-level when both are set.

### Core Building Blocks

### Key Fields Reference

| Field | Level | What it does | Recommended value |
|-------|-------|--------------|-------------------|
| `runAsUser` | Pod / Container | Run process as this UID | Any non-zero UID (e.g. `1000`) |
| `runAsGroup` | Pod / Container | Run process as this GID | Any non-zero GID (e.g. `3000`) |
| `fsGroup` | Pod only | Volumes are owned by this GID; files created in volumes get this group | Match app GID |
| `runAsNonRoot` | Pod / Container | Kubelet rejects the pod if the image's USER is root (UID 0) | `true` |
| `readOnlyRootFilesystem` | Container | Mount the container's root filesystem as read-only | `true` |
| `allowPrivilegeEscalation` | Container | Prevents `setuid`/`setgid` binaries from gaining more privileges than their parent process (`no_new_privs` flag) | `false` |
| `capabilities.drop` | Container | Remove Linux capabilities from the default set | `["ALL"]` |
| `capabilities.add` | Container | Add specific capabilities back after dropping | Only what is needed |
| `privileged` | Container | Run with full host privileges (equivalent to root on the node) | `false` (never in prod) |
| `seccompProfile` | Pod / Container | Apply a seccomp filter to restrict syscalls | `RuntimeDefault` |

---

### runAsUser / runAsGroup
- **Why it exists** — Images often default to running as root (UID 0). Running as a known non-root UID limits damage if the container is compromised.
- **What it is** — Overrides the `USER` directive in the Dockerfile at runtime.
- **One-liner** — "Run this process as UID X, not root."

```yaml
securityContext:
  runAsUser: 1000
  runAsGroup: 3000
```

---

### runAsNonRoot
- **Why it exists** — Catches images that were not built with a non-root USER; fails fast at admission rather than silently running as root.
- **What it is** — If the container's effective UID would be 0, kubelet refuses to start the container.
- **One-liner** — "Reject the container if it would run as root."

```yaml
securityContext:
  runAsNonRoot: true
```

---

### readOnlyRootFilesystem
- **Why it exists** — Attackers who compromise a container often write payloads, modify binaries, or install tools. A read-only filesystem prevents writes.
- **What it is** — Mounts the container's root filesystem as read-only. Writable paths (logs, temp files) must be explicitly mounted as `emptyDir` volumes.
- **One-liner** — "The container cannot write to its own filesystem."

```yaml
securityContext:
  readOnlyRootFilesystem: true
```

---

### allowPrivilegeEscalation
- **Why it exists** — Setuid/setgid binaries (like `sudo`, `ping`) can silently grant a process more privileges than its parent. Setting `no_new_privs` closes this path.
- **What it is** — Maps to the Linux `no_new_privs` process attribute. When false, child processes cannot acquire new privileges through setuid/setgid binaries.
- **One-liner** — "This process cannot gain more privileges than it started with."

```yaml
securityContext:
  allowPrivilegeEscalation: false
```

---

### capabilities
- **Why it exists** — Linux capabilities break root privileges into discrete units. A container that only needs to bind to port 80 doesn't need `CAP_SYS_ADMIN`. Dropping capabilities limits what an attacker can do with a compromised container.
- **What it is** — The container runtime applies a default set of capabilities. You can `drop` from that set (or drop ALL), then `add` back only what is needed.
- **One-liner** — "Drop everything, then add back only the capabilities this container genuinely needs."

```yaml
securityContext:
  capabilities:
    drop:
    - ALL                # drop every default capability
    add:
    - NET_BIND_SERVICE   # only add: bind to ports < 1024
```

Common capabilities and their meaning:

| Capability | What it allows | Typical need |
|------------|----------------|--------------|
| `NET_BIND_SERVICE` | Bind to ports below 1024 | Web servers on port 80/443 |
| `NET_ADMIN` | Network interface config, firewall rules | CNI plugins, VPNs |
| `SYS_ADMIN` | Mount filesystems, set hostname, many others | Avoid — very broad |
| `CHOWN` | Change file ownership | Base images; usually can drop |
| `DAC_OVERRIDE` | Bypass file permission checks | Usually can drop |
| `SETUID` / `SETGID` | Change process UID/GID | Usually can drop |

---

### privileged
- **Why it exists** — Exists for containers that genuinely need full host access (e.g. node-level agents, device plugins). Should never be used for normal workloads.
- **What it is** — Grants the container the same capabilities as a process running directly on the host node. Can see all host processes, devices, and network interfaces.
- **One-liner** — "Full host access — avoid unless you have a very specific reason."

```yaml
securityContext:
  privileged: false    # default; always set explicitly to false
```

---

### Hardened Security Context — Complete Example

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hardened-app
  namespace: production
spec:
  # Pod-level: identity shared by all containers
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault     # apply the container runtime's default seccomp filter

  containers:
  - name: app
    image: my-app:1.0
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      privileged: false
      capabilities:
        drop:
        - ALL
        # add: [] — add nothing; the app runs as an unprivileged user on port 8080

    volumeMounts:
    # Provide writable directories the app needs (logs, temp)
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /app/cache

  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
```

---

### Pod-level vs Container-level Summary

| Setting | Pod-level | Container-level | Notes |
|---------|-----------|-----------------|-------|
| `runAsUser` | Yes | Yes | Container overrides pod |
| `runAsGroup` | Yes | Yes | Container overrides pod |
| `fsGroup` | Yes | No | Pod-only; affects volume ownership |
| `runAsNonRoot` | Yes | Yes | Container overrides pod |
| `readOnlyRootFilesystem` | No | Yes | Container-only |
| `allowPrivilegeEscalation` | No | Yes | Container-only |
| `capabilities` | No | Yes | Container-only |
| `privileged` | No | Yes | Container-only |
| `seccompProfile` | Yes | Yes | Container overrides pod |

### Troubleshooting

### Container fails to start: "container has runAsNonRoot and image will run as root"
1. The image's Dockerfile has `USER root` or no `USER` directive.
2. Either fix the image to use a non-root user, or set `runAsUser: <non-zero>` in the security context to override the image default.
3. Verify: `docker inspect <image> | grep -A5 '"User"'`.

### Permission denied writing to files inside the container
1. `readOnlyRootFilesystem: true` is set. The container needs a writable path.
2. Mount an `emptyDir` volume at the path the app writes to (`/tmp`, log dirs, cache dirs).
3. Check also that `runAsUser` matches the file ownership inside the image.

### Operation not permitted — capability missing
1. `capabilities.drop: [ALL]` was set, but the app needs a specific capability.
2. Identify which capability is needed (check app docs or use `strace`/`ausearch`).
3. Add it back: `capabilities.add: ["NET_BIND_SERVICE"]`.
4. Avoid adding `SYS_ADMIN` — it is nearly as powerful as `privileged: true`.

### fsGroup not taking effect on volume
1. `fsGroup` only applies to volumes of type `emptyDir`, `secret`, `configMap`, and persistent volumes. It does not apply to `hostPath`.
2. Verify the volume type; for `hostPath` you must ensure ownership at the host level.
