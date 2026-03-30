# DHCP (Dynamic Host Configuration Protocol)

- DHCP automatically assigns IP addresses and network configuration to devices when they join a network.
- Uses a 4-step broadcast-based handshake (DORA): Discover, Offer, Request, Acknowledge.
- Runs over UDP — client uses port 68, server uses port 67.

# Architecture

```text
                    Network with DHCP
+----------------------------------------------------------------+
|                                                                |
|  New Device (no IP yet)         DHCP Server (192.168.1.1)      |
|  "I need an IP address"         "I manage 192.168.1.100-200"  |
|       |                                   |                    |
|       |--- DHCP Discover (broadcast) ---->|                    |
|       |<-- DHCP Offer (192.168.1.105) ----|                    |
|       |--- DHCP Request (I want .105) --->|                    |
|       |<-- DHCP Acknowledge (confirmed) --|                    |
|       |                                   |                    |
|  Now configured:                          Lease recorded:      |
|  IP: 192.168.1.105                        .105 → device MAC   |
|  Mask: 255.255.255.0                      Lease: 8 hours      |
|  Gateway: 192.168.1.1                                          |
|  DNS: 8.8.8.8                                                  |
+----------------------------------------------------------------+

    Cross-subnet with DHCP Relay:
+------------------+          +------------------+
|  Subnet A        |          |  Subnet B        |
|  192.168.1.0/24  |          |  192.168.2.0/24  |
|                  |          |                  |
|  New Device      |          |  DHCP Server     |
|       |          |          |  192.168.2.10    |
|       |  broadcast cannot   |       ^          |
|       |  cross routers      |       |          |
|       v          |          |       |          |
|  DHCP Relay -----+--- unicast forward ---------+
|  (on router)     |          |                  |
+------------------+          +------------------+
```

# Mental Model

```text
What happens when you plug a new device into the network?

1. Device has no IP — sends DHCP Discover as broadcast
   - Src IP: 0.0.0.0    Dst IP: 255.255.255.255
   - Src MAC: device     Dst MAC: FF:FF:FF:FF:FF:FF
      |
      v
2. DHCP Server receives Discover, picks an available IP from its pool
   - Sends DHCP Offer with: IP, subnet mask, gateway, DNS, lease time
      |
      v
3. Device sends DHCP Request (broadcast) — "I accept this offer"
   - Broadcast because there might be multiple DHCP servers
   - This tells other servers their offer was not accepted
      |
      v
4. Server sends DHCP Acknowledge — lease is active
   - Device configures its network interface with the received settings
      |
      v
5. Lease lifecycle begins:
   - At 50% of lease time (T1): device tries to renew with same server
   - At 87.5% of lease time (T2): device tries any DHCP server
   - At 100%: lease expires, device must start over with Discover
```

```bash
# view current DHCP lease on Linux
cat /var/lib/dhcp/dhclient.leases
# or with NetworkManager
nmcli device show eth0 | grep -i dhcp

# release and renew DHCP lease
sudo dhclient -r eth0    # release
sudo dhclient eth0       # renew
```

# Core Building Blocks

### DORA Process

- **Discover**: client broadcasts to find DHCP servers. Uses UDP src port 68, dst port 67.
- **Offer**: server responds with an available IP and configuration parameters.
- **Request**: client broadcasts acceptance of a specific offer (identifies the server).
- **Acknowledge**: server confirms the lease and the client configures its interface.
- All four messages use UDP (not TCP) because the client has no IP yet and cannot establish a connection.
- If no server responds to Discover, client retries with exponential backoff, then falls back to APIPA (169.254.x.x) on some systems.

Related notes: [005-transport-layer](./005-transport-layer.md)

### Leases

- Every DHCP assignment has a lease duration — the client borrows the IP, it does not own it.
- Lease renewal (T1): at 50% of lease time, client sends a unicast Request to the original server.
- Rebinding (T2): at 87.5%, if the original server didn't respond, client broadcasts a Request to any server.
- Expiration: at 100%, the IP is released and the client must restart the DORA process.
- Lease times vary: home networks often 24 hours; enterprise networks 4-8 hours; public Wi-Fi may be 1 hour.
- Short leases recycle IPs faster but increase DHCP traffic; long leases are stable but can waste addresses.

Related notes: [003-addressing-and-routing](./003-addressing-and-routing.md)

### DHCP Relay

- Broadcast messages cannot cross routers — they are confined to the local subnet.
- DHCP Relay Agent (usually configured on the router) listens for DHCP broadcasts, then forwards them as unicast to a DHCP server on another subnet.
- This allows one centralized DHCP server to serve multiple subnets.
- The relay adds a `giaddr` (Gateway IP Address) field so the server knows which subnet the request came from and can assign an IP from the correct pool.

```text
Client → broadcast → Router (relay agent) → unicast → DHCP Server
                                                         |
Server → unicast → Router (relay agent) → unicast → Client
```

Related notes: [003-addressing-and-routing](./003-addressing-and-routing.md)

### DHCP Options

- DHCP doesn't just assign an IP — it delivers a full set of network configuration via numbered options:
  - **Option 1**: Subnet Mask (255.255.255.0)
  - **Option 3**: Default Gateway (router IP)
  - **Option 6**: DNS Servers (can provide multiple)
  - **Option 15**: Domain Name (e.g., `corp.example.com`)
  - **Option 42**: NTP Servers (time synchronization)
  - **Option 51**: Lease Time (in seconds)
- Custom options can be defined for specific applications (e.g., PXE boot server for network installs).

Related notes: [006-dns](./006-dns.md)

### Static vs Dynamic Allocation

| Type | How it works | Use case |
|------|-------------|----------|
| Dynamic | Server assigns any available IP from pool | Laptops, phones, general clients |
| Reserved (Static DHCP) | Server always assigns same IP based on MAC address | Printers, servers that need stable IPs |
| Manual (Static IP) | Configured directly on the device, no DHCP | Infrastructure: routers, DNS servers, DHCP server itself |

- DHCP reservations combine the convenience of DHCP (centralized config, automatic DNS/gateway) with the predictability of static IPs.
- Devices that other services depend on (printers, file servers) should use reservations, not purely dynamic assignment.

Related notes: [003-addressing-and-routing](./003-addressing-and-routing.md)
