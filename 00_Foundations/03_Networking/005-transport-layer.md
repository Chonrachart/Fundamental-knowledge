# Transport Layer

- The transport layer provides end-to-end communication between processes on different hosts.
- TCP delivers data reliably and in order (connection-oriented); UDP delivers data fast with no guarantees (connectionless).
- Ports (0-65535) identify services; sockets (IP + Port + Protocol) are the endpoints for all network communication.

# Architecture

```text
+------------------+                        +------------------+
|   Application    |                        |   Application    |
+------------------+                        +------------------+
        |                                           ^
        v                                           |
+------------------+    network path        +------------------+
|    Transport     |----------------------->|    Transport     |
|  (TCP or UDP)    |   segments/datagrams   |  (TCP or UDP)    |
|  src port:51514  |                        |  dst port:443    |
+------------------+                        +------------------+
        |                                           ^
        v                                           |
+------------------+                        +------------------+
|     Network      |  -- packets -->        |     Network      |
+------------------+                        +------------------+

   Client side                                 Server side
```

# Mental Model

```text
TCP connection lifecycle:

  [1] 3-way handshake  -->  connection established
  [2] data transfer    -->  reliable, ordered, acknowledged
  [3] 4-way teardown   -->  connection closed

UDP send:

  [1] send datagram    -->  no handshake, no connection
  [2] hope it arrives  -->  no acknowledgement, no retransmit
```

```bash
# check which ports are listening on this machine
ss -tulnp
# output shows: protocol, local address:port, process name
```

# Core Building Blocks

### TCP (Transmission Control Protocol)

- Connection-oriented: establishes a session before sending data (3-way handshake).
- Reliable: retransmits lost packets, guarantees ordered delivery.
- Flow control (receiver advertises window size) and congestion control (sender adjusts rate).
- Uses sequence numbers and acknowledgement numbers to track every byte of data.
- Used by: HTTP, HTTPS, SSH, FTP, SMTP.
- TCP = connection-oriented, reliable, ordered; UDP = connectionless, best-effort, fast.
- TCP uses a 3-way handshake (SYN, SYN-ACK, ACK) to establish and a 4-way teardown (FIN, ACK, FIN, ACK) to close.
- TCP header is 20+ bytes; UDP header is 8 bytes.

Related notes: [008-http-https](./008-http-https.md), [009-tls-and-ssl-cert-chain](./009-tls-and-ssl-cert-chain.md)

### UDP (User Datagram Protocol)

- Connectionless: no handshake before sending, no session state.
- No guarantee of delivery, ordering, or duplicate protection.
- Lower overhead than TCP: smaller header (8 bytes vs TCP 20+ bytes).
- No retransmission or built-in recovery -- application must handle if needed.
- Best when speed matters more than perfect delivery.
- Used by: DNS, DHCP, video streaming, VoIP, gaming.
- Lower overhead than TCP: smaller header (8 bytes vs TCP 20+ bytes).

Related notes: [006-dns](./006-dns.md)

### TCP vs UDP

| TCP                     | UDP                    |
| :---------------------- | :--------------------- |
| Connection-oriented     | Connectionless         |
| Reliable, ordered       | Best-effort            |
| Higher latency          | Lower latency          |
| Flow control            | No flow control        |
| Retransmission          | No retransmission      |
| Web, SSH, file transfer | DNS, streaming, gaming |

Related notes: [001-network-models](./001-network-models.md)

### Ports

- A port is a 16-bit number (0-65535) that identifies a service or application on a host.
- Combined with IP as `IP:Port` to identify a specific endpoint.
- Source port: chosen by client (ephemeral); destination port: the server's service port.
- Port ranges:
  - `0-1023` -- well-known ports (HTTP 80, HTTPS 443, SSH 22, DNS 53)
  - `1024-49151` -- registered ports (assigned to specific applications)
  - `49152-65535` -- dynamic / ephemeral ports (used by clients)
- Port range: 0-65535. Well-known: 0-1023. Registered: 1024-49151. Ephemeral: 49152-65535.
- Common ports: HTTP 80, HTTPS 443, SSH 22, DNS 53, SMTP 25.

Related notes: [003-addressing-and-routing](./003-addressing-and-routing.md)

### Sockets

- Socket = IP + Port + Protocol -- the endpoint for sending or receiving data.
- Client creates a socket and connects to a server socket; server listens on a port.
- A TCP connection is uniquely identified by the 4-tuple: source IP, source port, destination IP, destination port.
- Socket = IP + Port + Protocol. A TCP connection = 4-tuple (srcIP, srcPort, dstIP, dstPort).

```text
Example:
  Client socket:  192.168.1.10:51514 + TCP
  Server socket:  172.217.0.14:443   + TCP
  Connection ID:  (192.168.1.10, 51514, 172.217.0.14, 443)
```

Related notes: [003-addressing-and-routing](./003-addressing-and-routing.md)

### TCP 3-Way Handshake

- Establishes a connection before any data transfer.

```text
Client               Server
  |                    |
  |--- SYN ----------> |   [1] Client sends SYN (synchronize)
  |                    |
  |<-- SYN-ACK ------- |   [2] Server replies with SYN-ACK
  |                    |
  |--- ACK ----------> |   [3] Client sends ACK
  |                    |
  |== connection established ==|
  |    data can flow both ways |
```

Related notes: [008-http-https](./008-http-https.md)

### TCP 4-Way Teardown

- Gracefully closes a connection; either side can initiate.

```text
Client               Server
  |                    |
  |--- FIN ----------> |   [1] Client says "I'm done sending"
  |                    |
  |<-- ACK ----------- |   [2] Server acknowledges
  |                    |
  |<-- FIN ----------- |   [3] Server says "I'm done sending too"
  |                    |
  |--- ACK ----------> |   [4] Client acknowledges
  |                    |
  |== connection closed ==|
```

Related notes: [009-tls-and-ssl-cert-chain](./009-tls-and-ssl-cert-chain.md)

### Common TCP Flags
Related notes: [001-network-models](./001-network-models.md)
- **SYN** -- start (synchronize) a new connection
- **ACK** -- acknowledge received data
- **FIN** -- finish (close) the connection gracefully
- **RST** -- reset the connection immediately (abort)
- **PSH** -- push data to the application without buffering
- RST flag immediately aborts a connection; FIN gracefully closes it.

---

# Troubleshooting Guide

```text
Problem: cannot connect to a remote service
    |
    v
[1] Is the port listening on the server?
    ss -tulnp | grep <port>
    |
    +-- not listening --> start the service or check config
    |
    v
[2] Can you reach the port from the client?
    nc -zv <host> <port>
    |
    +-- timeout --> firewall blocking? check iptables/nftables/security groups
    +-- refused --> port closed or service down
    |
    v
[3] Is the TCP handshake completing?
    tcpdump -n port <port>
    |
    +-- SYN sent, no SYN-ACK --> server not responding or packet dropped
    +-- RST received --> service rejecting connection
    |
    v
[4] Application-level issue
    curl -v / openssl s_client / application logs
```
