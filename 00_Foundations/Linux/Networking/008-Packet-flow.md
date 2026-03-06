# Packet Flow Through Linux Network Stack

- This document describes how a packet travels through the kernel from application to wire, and from wire to application.

---

# Outgoing Packet Flow (Application → Wire)

### Step-by-Step

1. **Application**
   - Calls `send()` or `write()` on a socket.
   - Data is copied into kernel socket buffer.

2. **Socket Layer**
   - Kernel looks up socket (protocol, local/remote IP:port).
   - Prepares data for transport layer.

3. **Transport Layer (TCP/UDP)**
   - TCP: segments data, adds TCP header (ports, sequence, checksum).
   - UDP: adds UDP header.
   - Passes segment to IP layer.

4. **IP Layer**
   - Adds IP header (source/dest IP, TTL, etc.).
   - Performs **routing lookup**: which interface and next hop?
   - May fragment if packet too large for MTU.

5. **Netfilter (OUTPUT chain)**
   - iptables/nftables OUTPUT rules.
   - Can filter, NAT, or mangle.

6. **Routing (again)**
   - After OUTPUT; determines final output interface.

7. **Netfilter (POSTROUTING)**
   - SNAT, MASQUERADE for NAT.
   - Last chance to modify before send.

8. **Network Interface**
   - Driver adds Ethernet header (MAC addresses).
   - Queues frame for transmission.

9. **Physical**
   - NIC sends bits on the wire.

### Diagram

```
Application (send)
    ↓
Socket buffer
    ↓
TCP/UDP (add transport header)
    ↓
IP (add IP header, routing lookup)
    ↓
Netfilter OUTPUT
    ↓
Netfilter POSTROUTING (NAT)
    ↓
Network interface (add Ethernet header)
    ↓
NIC → Wire
```

# Incoming Packet Flow (Wire → Application)

### Step-by-Step

1. **NIC**
   - Receives frame; driver passes to kernel.

2. **Network Interface**
   - Strips Ethernet header; passes to IP layer.

3. **Netfilter (PREROUTING)**
   - DNAT, raw table.
   - Can change destination before routing.

4. **Routing Decision**
   - Is packet for local host or to be forwarded?
   - **Local**: go to INPUT.
   - **Forward**: go to FORWARD.

5. **Netfilter (INPUT or FORWARD)**
   - filter table: accept, drop, reject.
   - For forwarded: then POSTROUTING.

6. **Transport Layer (for local)**
   - TCP/UDP demultiplexes by port.
   - Finds matching socket.
   - Data copied to socket buffer.

7. **Application**
   - `recv()` or `read()` returns data.

### Diagram

```
Wire → NIC
    ↓
Network interface (strip Ethernet)
    ↓
Netfilter PREROUTING (DNAT)
    ↓
Routing: local or forward?
    ↓
INPUT (local)              FORWARD (forwarded)
    ↓                           ↓
Netfilter filter           Netfilter FORWARD
    ↓                           ↓
TCP/UDP demux              POSTROUTING
    ↓
Socket → Application
```

# Forwarded Packets

- When Linux acts as a router, packets are forwarded (not for local host).
- Flow: PREROUTING → routing → FORWARD → POSTROUTING.
- Must enable `net.ipv4.ip_forward=1` for IPv4 forwarding.

# Key Takeaways

- **Routing** happens at specific points; it determines output interface (outgoing) or whether packet is local/forward (incoming).
- **Netfilter** hooks allow filtering and NAT at multiple stages.
- **Sockets** are the endpoint; transport layer delivers to the right socket based on IP:port.