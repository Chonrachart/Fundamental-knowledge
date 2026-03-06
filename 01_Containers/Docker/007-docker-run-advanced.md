docker run
options
flags
detach
publish
environment
limit
restart

---

# docker run — Full Picture

- Creates a new container from an image and starts it.
- Syntax: `docker run [OPTIONS] IMAGE [COMMAND] [ARG...]`
- If image not found locally, Docker pulls it from configured registry (if pull policy allows).

# Detach vs Foreground

- **-d, --detach**: Run in background; returns container ID; logs not shown.
- Without -d: runs in foreground; Ctrl+C stops container (unless --sig-proxy=false); logs to terminal.
- **--rm**: Automatically remove container when it exits; useful for one-off runs.

```bash
docker run -d --name web nginx:alpine
docker run --rm alpine echo "hello"
```

# Publish Ports (-p, -P)

- **-p host_port:container_port**: Map host port to container port; multiple -p allowed.
- **-p 8080:80**: Host 8080 → container 80; access via localhost:8080.
- **-p 127.0.0.1:8080:80**: Bind only to localhost (not all interfaces).
- **-p 80**: Random host port → container 80; see with `docker port`.
- **-P**: Publish all ports declared in EXPOSE to random host ports.

# Environment Variables (-e, --env-file)

- **-e KEY=value**: Set env var in container; multiple -e allowed.
- **--env-file path**: Read KEY=value lines from file; one var per line.
- Override image ENV; used for config (DB host, API key, etc.).

```bash
docker run -e DB_HOST=db -e DB_PASS=secret myapp
docker run --env-file .env myapp
```

# Memory and CPU Limits

- **--memory**, **-m**: Max memory (e.g. `512m`, `1g`); container can be OOM-killed if exceeded.
- **--memory-swap**: Total memory + swap; set to same as --memory to disable swap.
- **--cpus**: Cap CPU (e.g. `1.5` = 1.5 cores); **--cpu-shares**: Relative weight (default 1024).
- **--cpuset-cpus**: Pin to specific CPU cores (e.g. `0-3`).

```bash
docker run -m 512m --cpus=0.5 myapp
```

# Restart Policy (--restart)

- **no** (default): Do not restart.
- **always**: Always restart; on daemon restart, container starts too.
- **on-failure**: Restart only if exit code non-zero; optional max count: `on-failure:3`.
- **unless-stopped**: Like always, but do not start after stop if daemon restarted.

# User and Capabilities

- **--user**, **-u**: Run as user (e.g. `1000:1000` or `www-data`); container may need writable dirs.
- **--read-only**: Mount root filesystem read-only; use tmpfs or volumes for writable paths.
- **--cap-add**, **--cap-drop**: Add or drop Linux capabilities; drop all then add minimal: `--cap-drop=ALL --cap-add=NET_BIND_SERVICE`.

# Network and DNS

- **--network**: Attach to network (bridge, host, none, or user-defined name).
- **--dns**: DNS server inside container (e.g. `8.8.8.8`).
- **--add-host**: Add line to /etc/hosts (e.g. `--add-host=db:10.0.0.5`).
- **--hostname**: Set container hostname.

# Volume and Mount

- **-v**, **--volume**: Bind mount or named volume; `host_path:container_path[:options]`.
- **:ro**: Read-only in container.
- **--mount**: More explicit; type=bind|volume|tmpfs, source, target, and options.
- **--tmpfs**: Mount tmpfs at path (e.g. `--tmpfs /tmp`).

# Entrypoint and Command Override

- **--entrypoint**: Override image ENTRYPOINT; useful for debug (e.g. `--entrypoint sh`).
- Args after image name override CMD; combined with ENTRYPOINT: `docker run myimg arg1` → ENTRYPOINT receives arg1.

# Summary Table (Common Flags)

| Flag | Short | Purpose |
|------|--------|---------|
| --detach | -d | Run in background |
| --publish | -p | Port mapping |
| --env | -e | Environment variable |
| --volume | -v | Mount volume |
| --memory | -m | Memory limit |
| --restart | | Restart policy |
| --name | | Container name |
| --rm | | Remove when exit |
| --user | -u | Run as user |
| --network | | Attach network |
| --entrypoint | | Override entrypoint |
