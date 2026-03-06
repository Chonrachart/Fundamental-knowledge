process communication

---

# Socket Overview

- A **socket** is an endpoint for network communication.
- Application creates socket, binds to address/port, and sends/receives data.
- Socket = IP + Port + Protocol (TCP or UDP).

# Socket Types

| Type   | Protocol | Use case                    |
| :----- | :------- | :-------------------------- |
| SOCK_STREAM | TCP  | Reliable, connection-oriented |
| SOCK_DGRAM  | UDP  | Connectionless, best-effort   |

# Port

- Port is a 16-bit number (0–65535) identifying a service.
- Well-known ports: 22 (SSH), 80 (HTTP), 443 (HTTPS), 53 (DNS).
- Combined with IP: `192.168.1.10:443` identifies a specific endpoint.

# How Processes Use Sockets

### Server Flow

1. Create socket: `socket(AF_INET, SOCK_STREAM, 0)`
2. Bind to address and port: `bind(sock, addr, len)`
3. Listen for connections: `listen(sock, backlog)`
4. Accept connection: `accept(sock, ...)`
5. Send/receive: `send()`, `recv()`

### Client Flow

1. Create socket
2. Connect to server: `connect(sock, addr, len)`
3. Send/receive

# Viewing Sockets and Ports on Linux

### ss (Socket Statistics)

- Modern replacement for `netstat`.

```bash
# All listening sockets
ss -tlnp

# All connections
ss -tanp

# UDP
ss -ulnp
```

### netstat (Legacy)

```bash
netstat -tlnp
netstat -anp
```

### Example Output (ss -tlnp)

```
State   Recv-Q  Send-Q  Local Address:Port  Peer Address:Port
LISTEN  0       128     0.0.0.0:22         0.0.0.0:*       users:(("sshd",pid=1234))
LISTEN  0       128     0.0.0.0:80         0.0.0.0:*       users:(("nginx",pid=5678))
```

- `0.0.0.0:22` — listening on all interfaces, port 22
- `127.0.0.1:3306` — listening only on loopback (MySQL local only)

# /proc/net and /proc/PID/fd

- Kernel exposes socket info in `/proc`.

```bash
# Sockets for process 1234
ls -l /proc/1234/fd

# TCP connections
cat /proc/net/tcp
```

# Port Binding and Conflicts

- Only one process can bind to a given IP:port for a given protocol.
- "Address already in use" means another process holds the port.
- Find process using a port:

```bash
ss -tlnp | grep :80
lsof -i :80
```