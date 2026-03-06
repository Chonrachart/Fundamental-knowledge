# Firewall: iptables and nftables

- Linux packet filtering and NAT are implemented by **Netfilter** in the kernel.
- **iptables** and **nftables** are user-space tools that configure Netfilter rules.
- nftables is the modern replacement for iptables; more flexible and faster.

---

# Netfilter Hooks

- Netfilter hooks are points in the kernel where packets can be inspected or modified.

| Hook        | When                         | Common use           |
| :---------- | :--------------------------- | :--------------------|
| PREROUTING  | Before routing decision      | DNAT, raw            |
| INPUT       | For local host               | Filter incoming      |
| FORWARD     | For forwarded packets        | Filter/NAT forward    |
| OUTPUT      | Locally generated            | Filter outgoing      |
| POSTROUTING | After routing, before send   | SNAT, MASQUERADE     |

### Packet Flow and Hooks

```
Incoming:
  PREROUTING → routing → INPUT → local process

Forwarded:
  PREROUTING → routing → FORWARD → POSTROUTING → out

Outgoing:
  OUTPUT → routing → POSTROUTING → out
```

# iptables

- Classic tool; uses tables and chains.

### Tables

| Table   | Purpose                    |
| :------ | :------------------------- |
| filter  | Packet filtering (default) |
| nat     | NAT (SNAT, DNAT)           |
| mangle  | Packet modification        |
| raw     | Connection tracking bypass |

### Common Commands

```bash
# List rules
iptables -L -n -v
iptables -t nat -L -n -v

# Allow SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow established/related
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Default policy
iptables -P INPUT DROP
iptables -P FORWARD DROP

# NAT (masquerade for outbound)
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

### Chain Structure

- `INPUT` — packets for local host
- `OUTPUT` — packets from local host
- `FORWARD` — packets passing through

# nftables

- Newer, more efficient; single framework for IPv4, IPv6, ARP, bridge.

### Concepts

- **table** — container for chains
- **chain** — list of rules
- **rule** — match + action (accept, drop, reject, etc.)

```bash
# List tables
nft list tables

# List ruleset
nft list ruleset

# Add table
nft add table inet filter

# Add chain
nft add chain inet filter input { type filter hook input priority 0 \; }

# Add rule
nft add rule inet filter input tcp dport 22 accept
nft add rule inet filter input ct state established,related accept
nft add rule inet filter input drop
```

### nftables vs iptables

| iptables        | nftables              |
| :-------------- | :-------------------- |
| Separate for v4/v6 | Unified inet table |
| Many rules = slow | Better performance   |
| Legacy          | Modern, recommended   |

# Persistence

- Rules are lost on reboot unless saved.

```bash
# iptables
iptables-save > /etc/iptables/rules.v4
iptables-restore < /etc/iptables/rules.v4

# nftables
nft list ruleset > /etc/nftables.conf
# Enable nftables.service to load on boot
```