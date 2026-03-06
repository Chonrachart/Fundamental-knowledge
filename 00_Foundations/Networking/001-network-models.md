osi tcp/ip encapsulate packet-vs-frame

---

# OSI Model (7 Layers)

- Open Systems Interconnection model; describes how data flows through a network.
- Each layer has a role; data passes down (encapsulation) or up (decapsulation).

| Layer | Name        | Purpose                          |
| :---: | :---------- | :------------------------------- |
|   7   | Application | User interfaces, HTTP, DNS       |
|   6   | Presentation| Encoding, encryption, compression|
|   5   | Session     | Session management               |
|   4   | Transport   | TCP, UDP, ports                  |
|   3   | Network     | IP, routing                      |
|   2   | Data Link   | Ethernet, MAC, frames            |
|   1   | Physical    | Cables, signals, bits            |

# TCP/IP Model (4 Layers)

- Simpler model used in practice; maps to OSI.

| TCP/IP Layer | Maps to OSI      | Examples              |
| :----------- | :--------------- | :-------------------- |
| Application  | 7, 6, 5         | HTTP, DNS, FTP        |
| Transport    | 4               | TCP, UDP              |
| Internet     | 3               | IP                    |
| Link         | 2, 1            | Ethernet, physical    |

# Encapsulation

- Data is wrapped with headers at each layer as it travels down the stack.
- Each layer adds its own header (and sometimes trailer).

```
Application data
     ↓ + Transport header (TCP/UDP)
Segment
     ↓ + IP header
Packet
     ↓ + Ethernet header + trailer
Frame
     ↓
Bits on wire
```

# Packet vs Frame

- Packet
  - Network layer (Layer 3) unit.
  - Contains IP header + payload.
  - Used for routing between networks.
- Frame
  - Data link layer (Layer 2) unit.
  - Contains Ethernet header + trailer + payload.
  - Used for delivery on a single network segment.
- A packet is the payload inside a frame; the frame carries the packet over the local link.