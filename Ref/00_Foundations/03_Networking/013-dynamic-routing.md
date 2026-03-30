# Dynamic Routing

- Static routes are manually configured; dynamic routing protocols let routers discover and share routes automatically.
- IGP (Interior Gateway Protocol) routes within an organization: OSPF is the most common.
- EGP (Exterior Gateway Protocol) routes between organizations: BGP is the only one used on the internet.

# Architecture

```text
The Internet: Autonomous Systems connected by BGP

     AS 64500 (ISP-A)              AS 64501 (ISP-B)
   +-------------------+         +-------------------+
   |  OSPF internally  |         |  OSPF internally  |
   |                   |  BGP    |                   |
   |  Router A --------+---------+--- Router C       |
   |     |             |         |       |           |
   |  Router B         |         |    Router D       |
   |     |             |         |       |           |
   |  10.1.0.0/16      |         |  10.2.0.0/16      |
   +-------------------+         +-------------------+
            |          BGP                 |
            +-------------+---------------+
                          |
                   AS 64502 (Your Company)
                 +-------------------+
                 |  OSPF internally  |
                 |  172.16.0.0/12    |
                 +-------------------+

  IGP (OSPF): routers within each AS share routes with each other
  EGP (BGP): routers at AS borders exchange routes between organizations
```

# Mental Model

```text
Static vs Dynamic routing:

  Static: you manually tell each router every route
    Router A: "To reach 10.2.0.0/16, send to Router C"
    Problem: if the link to Router C fails, traffic is dropped
    You must manually update every router

  Dynamic: routers talk to neighbors and learn routes automatically
    Router A learns from OSPF: "10.1.0.0/24 via Router B, cost 10"
    Router A learns from BGP: "10.2.0.0/16 via AS 64501, path [64501]"

    If a link fails:
      |
      v
    Routers detect the failure (hello packets stop)
      |
      v
    Routers recalculate and share updated routes (convergence)
      |
      v
    Traffic automatically reroutes through alternate paths
```

```bash
# view routing table (shows both static and dynamic routes)
ip route show

# example output with protocol indicators:
# 10.1.0.0/24 via 10.0.0.2 dev eth0 proto ospf metric 10
# 10.2.0.0/16 via 10.0.0.1 dev eth0 proto bgp metric 20
# default via 10.0.0.1 dev eth0 proto static
```

# Core Building Blocks

### Static vs Dynamic Routing

| Property | Static | Dynamic |
|----------|--------|---------|
| Configuration | Manual on each router | Routers learn automatically |
| Failover | None (manual reroute) | Automatic (reconvergence) |
| Scalability | Poor (dozens of routes max) | Good (thousands of routes) |
| Resource usage | None | CPU and memory for protocol |
| Best for | Small networks, default routes, specific overrides | Medium-to-large networks, redundant paths |

- Static routes are still used alongside dynamic routing for default gateways and specific policy routes.
- Dynamic routing adds complexity — only use it when you need automatic failover or have many routes.

Related notes: [003-addressing-and-routing](./003-addressing-and-routing.md)

### OSPF (Open Shortest Path First)

- Link-state IGP: every router builds a complete map of the network and calculates the shortest path using Dijkstra's algorithm.
- How it works:
  1. Routers send Hello packets to discover neighbors.
  2. Neighbors exchange LSAs (Link-State Advertisements) — descriptions of their connected links.
  3. Each router builds an identical LSDB (Link-State Database) — the full network map.
  4. Each router independently runs Dijkstra to calculate the shortest path to every destination.
- OSPF areas: large networks are divided into areas to reduce the size of the LSDB. Area 0 (backbone) connects all other areas.
- Cost metric: based on link bandwidth (lower cost = preferred path). 100 Mbps = cost 1, 10 Mbps = cost 10.
- Convergence: when a link changes state, only the affected LSA is flooded — much faster than re-sharing all routes.
- Uses multicast `224.0.0.5` (all OSPF routers) and `224.0.0.6` (designated routers).

Related notes: [012-multicast-and-broadcast](./012-multicast-and-broadcast.md)

### BGP (Border Gateway Protocol)

- Path-vector EGP: the only routing protocol used between organizations on the internet.
- BGP peers (neighbors) form TCP connections (port 179) and exchange route advertisements.
- Each route includes the AS-PATH: the list of Autonomous Systems the route has traversed.
  - Example: route to 10.2.0.0/16 has AS-PATH [64501, 64502] — it passed through two organizations.
- AS-PATH serves two purposes:
  1. Loop prevention: if a router sees its own AS in the path, it rejects the route.
  2. Path selection: shorter AS-PATH is preferred (fewer hops between organizations).
- Two types of BGP:
  - **eBGP** (external): between different Autonomous Systems — the internet backbone.
  - **iBGP** (internal): within the same AS — distributes external routes to internal routers.

Related notes: [005-transport-layer](./005-transport-layer.md)

### How BGP Selects Routes

- BGP can receive multiple routes to the same destination from different peers.
- Selection process (simplified, evaluated in order):
  1. **Local Preference**: administrator sets preference for specific paths (higher = preferred).
  2. **AS-PATH length**: shorter path preferred (fewer organizations to traverse).
  3. **Origin type**: IGP > EGP > incomplete.
  4. **MED (Multi-Exit Discriminator)**: hint from a neighboring AS about their preferred entry point.
  5. **eBGP over iBGP**: prefer routes learned from external peers.
- BGP is a policy-based protocol: network administrators control routing decisions through route maps and filters.
- Unlike OSPF (which always picks the mathematically shortest path), BGP allows business and policy decisions to influence routing.

Related notes: [003-addressing-and-routing](./003-addressing-and-routing.md)

### Why BGP Matters

- **Internet routing**: every ISP, cloud provider, and large organization uses BGP to exchange routes. Without BGP, the internet would not function.
- **Multi-homing**: connecting to multiple ISPs for redundancy. If one ISP fails, traffic automatically shifts to the other.
- **Anycast**: the same IP address announced from multiple locations (used by CDNs, DNS root servers). BGP routes users to the nearest location.
- **BGP hijacking**: if someone announces your IP prefix, traffic can be rerouted to them — this is why Route Origin Validation (ROV) and RPKI matter.
- You don't need to configure BGP in most environments, but understanding it explains why the internet routes the way it does and what happens during major outages.

Related notes: [009-tls-and-ssl-cert-chain](./009-tls-and-ssl-cert-chain.md)
