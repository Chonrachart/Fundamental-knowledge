tcp udp port socket tcp hand shake

---

# TCP (Transmission Control Protocol)

- Connection-oriented; establishes a session before sending data.
- Reliable: retransmits lost packets, ordered delivery.
- Flow control and congestion control.
- Used by HTTP, HTTPS, SSH, FTP.

# UDP (User Datagram Protocol)

- Connectionless; no handshake before sending.
- No guarantee of delivery or order.
- Lower overhead; good for real-time, streaming.
- Used by DNS, DHCP, video streaming, gaming.

# TCP vs UDP

| TCP                    | UDP                    |
| :--------------------- | :--------------------- |
| Connection-oriented   | Connectionless         |
| Reliable, ordered     | Best-effort            |
| Higher latency        | Lower latency          |
| Flow control          | No flow control        |

# Port

- Port is a 16-bit number (0–65535) that identifies a service or application.
- Combined with IP: `IP:Port` identifies a specific endpoint.
- Well-known ports: 80 (HTTP), 443 (HTTPS), 22 (SSH), 53 (DNS).

# Socket

- Socket = IP + Port + Protocol
- Endpoint for sending or receiving data.
- Client creates socket, connects to server socket; server listens on a port.

# TCP Handshake (3-Way)

- Establishes connection before data transfer.

```
Client → SYN     → Server
Client ← SYN-ACK ← Server
Client → ACK     → Server
```

1. Client sends SYN (synchronize).
2. Server replies with SYN-ACK (acknowledge).
3. Client sends ACK.
4. Connection established; data can flow.

# TCP Teardown (4-Way)

```
Client → FIN     → Server
Client ← ACK     ← Server
Client ← FIN     ← Server
Client → ACK     → Server
```