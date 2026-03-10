# Network Models: OSI and TCP/IP

- Network models split communication into layers so each layer has a clear responsibility.
- Data moves down layers when sending (encapsulation) and up layers when receiving (decapsulation).

# OSI Model (7 Layers)

The OSI model is a conceptual framework used for learning, design, and troubleshooting.

| Layer | Name         | What this layer is                 | What it does                                                 |
| :---: | :----------- | :--------------------------------- | :----------------------------------------------------------- |
|   7   | Application  | Closest layer to user applications | Provides network services to apps (web, email, name lookup)  |
|   6   | Presentation | Data format/translation layer      | Converts formats, encrypts/decrypts, compresses/decompresses |
|   5   | Session      | Conversation control layer         | Starts, maintains, and ends communication sessions           |
|   4   | Transport    | End-to-end delivery layer          | Segments data, uses ports, handles reliability/flow control  |
|   3   | Network      | Logical addressing layer           | Uses IP addressing and routing between different networks    |
|   2   | Data Link    | Local network delivery layer       | Uses MAC addressing, framing, error detection on local link  |
|   1   | Physical     | Hardware signal layer              | Sends raw bits as electrical/optical/radio signals           |

# OSI Layers with Examples

| Layer | Common Protocols / Technologies                          | Common Devices / Functions                        |
| :---: | :------------------------------------------------------- | :------------------------------------------------ |
|   7   | HTTP/HTTPS, DNS, SMTP, SSH                               | Web server, DNS resolver, application gateway     |
|   6   | TLS/SSL, UTF-8, JPEG                                     | Encryption engines, data format translation       |
|   5   | RPC, session control in app protocols                    | Session setup/teardown, dialog control            |
|   4   | TCP, UDP                                                 | Firewall rules by port, load balancer L4 behavior |
|   3   | IPv4/IPv6, ICMP, IPsec                                   | Router, L3 switch, routing table decisions        |
|   2   | Ethernet (802.3), Wi-Fi MAC (802.11), ARP, VLAN (802.1Q) | Switch, bridge, MAC table forwarding              |
|   1   | Copper, fiber, radio                                     | Cables, transceivers, hubs, signal repeaters      |

# TCP/IP Model (4 Layers)

The TCP/IP model is the practical model used by the internet stack.

| TCP/IP Layer | Maps to OSI | Typical Protocols               |
| :----------- | :---------- | :------------------------------ |
| Application  | 7, 6, 5     | HTTP, DNS, SMTP, SSH, TLS       |
| Transport    | 4           | TCP, UDP                        |
| Internet     | 3           | IP, ICMP, IPsec                 |
| Link         | 2, 1        | Ethernet, Wi-Fi, physical media |

# Encapsulation and PDU Names

Each layer wraps data with protocol information.

| Layer Scope                          | PDU Name                       |
| :----------------------------------- | :----------------------------- |
| Application / Presentation / Session | Data                           |
| Transport                            | Segment (TCP) / Datagram (UDP) |
| Network                              | Packet                         |
| Data Link                            | Frame                          |
| Physical                             | Bits                           |

```text
Application data
  + TCP/UDP header  -> Segment/Datagram
  + IP header       -> Packet
  + L2 header/trailer -> Frame
  transmitted as      Bits
```

# Packet vs Frame

- Packet (Layer 3): IP header + payload; used for routing across networks.
- Frame (Layer 2): L2 header + payload + trailer; used on a local link.
- On Ethernet, the packet is carried inside the frame payload.

# Quick Troubleshooting by Layer (Bottom-Up)

1. Layer 1 (Physical): Check cable, signal strength, interface status.
2. Layer 2 (Data Link): Check VLAN, MAC learning, ARP entry.
3. Layer 3 (Network): Check IP/subnet/gateway, route path, ICMP reachability.
4. Layer 4 (Transport): Check TCP handshake, UDP reachability, open ports.
5. Layer 7 (Application): Check DNS answers, service health, app credentials/config.

# Example Flow: Opening `https://example.com`

1. Application: Browser requests DNS and prepares HTTPS request.
2. Transport: Client opens TCP connection to destination port `443`.
3. Network: IP packet is routed to remote destination.
4. Data Link: Frame is sent to next-hop MAC (usually default gateway).
5. Physical: Bits travel through cable/fiber/Wi-Fi signals.
