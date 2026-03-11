# Network Models

- Network models split communication into layers.
- Each layer has a clear job and talks to the layer above and below it.
- When sending data, headers are added as data moves down the stack.
- When receiving data, headers are removed as data moves up the stack.

# OSI Model

- The OSI model is a 7-layer conceptual model.
- Mostly used for learning, design, and troubleshooting.

| Layer | Name         | What this layer is                 | What it does                                                 |
| :---: | :----------- | :--------------------------------- | :----------------------------------------------------------- |
|   7   | Application  | Closest layer to user applications | Provides network services to apps like web, email, and DNS   |
|   6   | Presentation | Data format and translation layer  | Converts formats, encrypts/decrypts, compresses data         |
|   5   | Session      | Conversation control layer         | Starts, maintains, and ends communication sessions           |
|   4   | Transport    | End-to-end delivery layer          | Segments data, uses ports, handles reliability and flow      |
|   3   | Network      | Logical addressing layer           | Uses IP addressing and routing between networks              |
|   2   | Data Link    | Local delivery layer               | Uses MAC addressing, framing, and local error detection      |
|   1   | Physical     | Hardware signal layer              | Sends bits as electrical, optical, or radio signals          |

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

# TCP/IP Model

- The TCP/IP model is the practical model used by the internet.
- It has 4 layers.
- It is simpler than the OSI model and maps better to real protocols.
- In real networking, people usually talk in TCP/IP terms like application, TCP/UDP, IP, and Ethernet.

## Application

- Combines OSI Application, Presentation, and Session.
- This layer is where user-facing protocols work.
- Common examples: HTTP, HTTPS, DNS, SMTP, SSH, TLS.
- This is the layer applications like browsers, mail clients, and SSH clients interact with.

## Transport

- Provides end-to-end communication between processes.
- Uses port numbers to identify services.
- TCP gives reliable, ordered delivery.
- UDP gives faster, connectionless delivery with less overhead.

## Internet

- Handles logical addressing and routing between networks.
- IP works at this layer.
- Routers look at the destination IP address to decide where the packet should go next.
- Common examples: IPv4, IPv6, ICMP, IPsec.

## Link

- Handles communication on the local network.
- Works with frames and MAC addresses.
- Includes Ethernet, Wi-Fi, and the physical medium used to send bits.
- Switches mainly work at this layer.

# OSI to TCP/IP Mapping

| TCP/IP Layer | Maps to OSI | Typical Protocols               |
| :----------- | :---------- | :------------------------------ |
| Application  | 7, 6, 5     | HTTP, DNS, SMTP, SSH, TLS       |
| Transport    | 4           | TCP, UDP                        |
| Internet     | 3           | IP, ICMP, IPsec                 |
| Link         | 2, 1        | Ethernet, Wi-Fi, physical media |

# Encapsulation

- Application creates the data.
- Transport adds TCP or UDP header.
- Network adds IP header.
- Data Link adds frame header and trailer.
- Physical sends the frame as bits on the medium.

```text
Application:
  "GET / HTTP/1.1"

Transport:
  [TCP header][GET / HTTP/1.1]

Network:
  [IP header][TCP header][GET / HTTP/1.1]

Data Link:
  [Ethernet header][IP header][TCP header][GET / HTTP/1.1][Ethernet trailer]

Physical:
  Bits on cable / Wi-Fi
```

# De-encapsulation

- De-encapsulation is the reverse process on the receiver side.
- Each layer removes its own header and passes the remaining data to the upper layer.

```text
Physical:
  Bits from cable / Wi-Fi

Data Link:
  [Ethernet header][IP header][TCP header][GET / HTTP/1.1][Ethernet trailer]
  remove Ethernet header and trailer

Network:
  [IP header][TCP header][GET / HTTP/1.1]
  remove IP header

Transport:
  [TCP header][GET / HTTP/1.1]
  remove TCP header

Application:
  "GET / HTTP/1.1"
```

# PDU Names

- PDU names tell us what the data is called at each layer of the network model.

| Layer Scope                          | PDU Name                       |
| :----------------------------------- | :----------------------------- |
| Application / Presentation / Session | Data                           |
| Transport                            | Segment (TCP) / Datagram (UDP) |
| Network                              | Packet                         |
| Data Link                            | Frame                          |
| Physical                             | Bits                           |


# Devices by Layer

- Layer 1: cable, repeater, hub, transceiver
- Layer 2: switch, bridge
- Layer 3: router, Layer 3 switch
- Layer 4-7: firewall, proxy, load balancer, gateway

# Troubleshooting by Layer

- Layer 1: check cable, signal, interface up/down
- Layer 2: check VLAN, MAC table, ARP
- Layer 3: check IP, subnet, gateway, route, ping
- Layer 4: check port, TCP handshake, UDP reachability
- Layer 7: check DNS, application response, auth, config

# Example Flow: Open `https://example.com`

1. Application: browser prepares DNS lookup and HTTPS request.
2. Transport: client opens TCP connection to port `443`.
3. Network: IP packet is routed toward the destination.
4. Data Link: local frame is sent to next hop MAC, usually the gateway.
5. Physical: bits travel over cable, fiber, or Wi-Fi.
