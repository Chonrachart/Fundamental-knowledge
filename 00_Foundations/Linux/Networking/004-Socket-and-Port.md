# Sockets and Ports

- A socket is a kernel-managed endpoint for network communication, identified by the tuple: IP + Port + Protocol
- Ports are 16-bit numbers (0-65535) that multiplex connections on a single IP address
- Applications create sockets via system calls; the kernel handles buffering, protocol processing, and delivery

# Architecture

```text
┌──────────────────────────────────────────────────────────────┐
│  Application (nginx, sshd, curl)                             │
│  calls: socket(), bind(), listen(), accept(), connect()      │
└─────────────────────────┬────────────────────────────────────┘
                          │ file descriptor
┌─────────────────────────▼────────────────────────────────────┐
│  Socket Layer (kernel)                                       │
│  ┌──────────────────┐  ┌──────────────────┐                  │
│  │ SOCK_STREAM (TCP)│  │ SOCK_DGRAM (UDP) │                  │
│  │ reliable, ordered│  │ connectionless    │                  │
│  └────────┬─────────┘  └────────┬─────────┘                  │
│           └──────────┬──────────┘                             │
│                      ▼                                       │
│         Port demultiplexing (0-65535)                         │
│         Well-known: 22, 53, 80, 443                          │
└─────────────────────────┬────────────────────────────────────┘
                          │
                     IP + Routing
```

# Mental Model

```text
Server-client socket lifecycle:

  SERVER                              CLIENT
  ──────                              ──────
  socket()  ← create endpoint         socket()
     │                                    │
  bind()    ← attach to IP:port           │
     │                                    │
  listen()  ← mark as accepting           │
     │                                    │
  accept()  ← wait for connection    connect() → to server IP:port
     │            │                       │
     └────────────┘                       │
         connected socket                 │
     send()/recv() ◄─────────────► send()/recv()
```

Example: server listening on port 80, client connects

```bash
# Server side (what nginx does internally):
#   socket(AF_INET, SOCK_STREAM, 0)
#   bind(sock, {0.0.0.0, 80})
#   listen(sock, 128)
#   accept(sock) → new_fd for each client

# Client side (what curl does internally):
#   socket(AF_INET, SOCK_STREAM, 0)
#   connect(sock, {93.184.216.34, 80})
#   send(sock, "GET / HTTP/1.1\r\n...")
#   recv(sock, buffer)
```

# Core Building Blocks

### Socket Types

| Type        | Protocol | Behavior                     |
| :---------- | :------- | :--------------------------- |
| SOCK_STREAM | TCP      | Reliable, connection-oriented, ordered |
| SOCK_DGRAM  | UDP      | Connectionless, best-effort, unordered |

Related notes: [000-core](./000-core.md)

### Ports

- 16-bit number (0-65535) identifying a service on a host
- Combined with IP forms an endpoint: `192.168.1.10:443`
- Only one process can bind to a given IP:port:protocol combination

| Range        | Name         | Examples                    |
| :----------- | :----------- | :-------------------------- |
| 0-1023       | Well-known   | 22 (SSH), 53 (DNS), 80 (HTTP), 443 (HTTPS) |
| 1024-49151   | Registered   | 3306 (MySQL), 5432 (PostgreSQL) |
| 49152-65535  | Ephemeral    | Auto-assigned to clients    |

Related notes: [006-firewall-iptables-nftable](./006-firewall-iptables-nftable.md)

### ss (Socket Statistics)

- Modern replacement for `netstat`; faster and more detailed
- Key flags: `-t` (TCP), `-u` (UDP), `-l` (listening), `-n` (numeric), `-p` (process)

```bash
# All listening TCP sockets with process info
ss -tlnp

# All TCP connections (including established)
ss -tanp

# All listening UDP sockets
ss -ulnp

# Filter by port
ss -tlnp | grep :80
```

Example output:

```text
State   Recv-Q  Send-Q  Local Address:Port  Peer Address:Port  Process
LISTEN  0       128     0.0.0.0:22          0.0.0.0:*          users:(("sshd",pid=1234))
LISTEN  0       128     0.0.0.0:80          0.0.0.0:*          users:(("nginx",pid=5678))
```

- `0.0.0.0:22` -- listening on all interfaces, port 22
- `127.0.0.1:3306` -- listening only on loopback (local access only)

Related notes: [002-ip-command](./002-ip-command.md)

### netstat (Legacy)

```bash
netstat -tlnp    # listening TCP
netstat -anp     # all connections
```

Deprecated in favor of `ss`.

Related notes: [002-ip-command](./002-ip-command.md)

### /proc/net and /proc/PID/fd

- Kernel exposes socket information in `/proc`
- Useful for low-level inspection when ss/netstat are unavailable

```bash
# Sockets for process 1234
ls -l /proc/1234/fd

# TCP connections (raw kernel data)
cat /proc/net/tcp
```

Related notes: [000-core](./000-core.md)

### Port Binding and Conflicts

- Only one process can bind to a given IP:port for a given protocol
- "Address already in use" error means another process holds the port
- Find the conflicting process:

```bash
ss -tlnp | grep :80
lsof -i :80
```

Related notes: [006-firewall-iptables-nftable](./006-firewall-iptables-nftable.md)

---

# Practical Command Set (Core)

```bash
# List all listening TCP sockets
ss -tlnp

# List all listening UDP sockets
ss -ulnp

# Show all connections (established + listening)
ss -tanp

# Find what process uses port 80
ss -tlnp | grep :80
lsof -i :80

# Check socket info via /proc
ls -l /proc/<pid>/fd
cat /proc/net/tcp
```

`ss` is the go-to tool for socket inspection on modern Linux.

# Troubleshooting Guide

```text
Service not reachable?
  │
  ├─ Process running? ──── systemctl status <svc> / ps aux | grep <svc>
  │
  ├─ Listening on correct port? ──── ss -tlnp | grep :<port>
  │       │
  │       ├─ Not listed? → service not started or config error
  │       └─ 127.0.0.1 only? → bound to loopback, not accessible externally
  │
  ├─ Port conflict? ──── "Address already in use" → lsof -i :<port> to find holder
  │
  ├─ Firewall blocking? ──── iptables -L -n / nft list ruleset
  │
  └─ Client connecting to correct IP:port? ──── verify with curl / telnet / nc
```

# Quick Facts (Revision)

- Socket = IP + Port + Protocol; it is the application-to-kernel network interface
- SOCK_STREAM = TCP (reliable); SOCK_DGRAM = UDP (best-effort)
- Ports 0-1023 are well-known (require root to bind); 49152-65535 are ephemeral
- `ss -tlnp` is the single most useful command for checking listening services
- `0.0.0.0` means listening on all interfaces; `127.0.0.1` means loopback only
- Only one process per IP:port:protocol; conflicts give "Address already in use"
- `lsof -i :<port>` and `ss -tlnp | grep :<port>` both identify port holders
- Socket info is exposed in `/proc/net/tcp` and `/proc/<pid>/fd`
