# TCP (Transmission Control Protocol)

- Connection-oriented; establishes a session before sending data.
- Reliable: retransmits lost packets, ordered delivery.
- Flow control and congestion control.
- Uses sequence number and acknowledgement number to track data.
- Used by HTTP, HTTPS, SSH, FTP.

# UDP (User Datagram Protocol)

- Connectionless; no handshake before sending.
- No guarantee of delivery or order.
- Lower overhead; good for real-time, streaming.
- No retransmission or built-in recovery.
- Good when speed matters more than perfect delivery.
- Used by DNS, DHCP, video streaming, gaming.

# TCP vs UDP

| TCP                     | UDP                    |
| :---------------------- | :--------------------- |
| Connection-oriented     | Connectionless         |
| Reliable, ordered       | Best-effort            |
| Higher latency          | Lower latency          |
| Flow control            | No flow control        |
| Retransmission          | No retransmission      |
| Web, SSH, file transfer | DNS, streaming, gaming |

# Port

- Port is a 16-bit number (0–65535) that identifies a service or application.
- Combined with IP: `IP:Port` identifies a specific endpoint.
- Well-known ports: 80 (HTTP), 443 (HTTPS), 22 (SSH), 53 (DNS).
- Source port is usually chosen by client temporarily.
- Destination port is usually the server service port.
- Port ranges:
  - `0-1023` well-known ports
  - `1024-49151` registered ports
  - `49152-65535` dynamic / ephemeral ports

# Socket

- Socket = IP + Port + Protocol
- Endpoint for sending or receiving data.
- Client creates socket, connects to server socket; server listens on a port.
- Example:
  - client socket: `192.168.1.10:51514 + TCP`
  - server socket: `172.217.0.14:443 + TCP`
- A TCP connection is identified by source IP, source port, destination IP, destination port.

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
5. After handshake, both sides can send and receive data.

# TCP Teardown (4-Way)

```
Client → FIN     → Server
Client ← ACK     ← Server
Client ← FIN     ← Server
Client → ACK     → Server
```

1. One side sends FIN to say it has finished sending.
2. Other side replies ACK.
3. Other side sends its own FIN when it is ready to close.
4. First side replies ACK.
5. Connection closed.

# Common Flags

- SYN: start connection
- ACK: acknowledge received data
- FIN: finish connection
- RST: reset connection immediately
- PSH: push data to application quickly

# Quick Example

```text
Open https://example.com
  -> TCP uses destination port 443
  -> client uses random source port
  -> 3-way handshake happens
  -> data is sent reliably
  -> connection closes with FIN/ACK
```
