# DNS Resolution on Linux

- Linux resolves hostnames to IP addresses through a configurable chain of resolution sources
- Resolution order is governed by `/etc/nsswitch.conf`; actual DNS queries use `/etc/resolv.conf` or `systemd-resolved`
- `systemd-resolved` provides caching, per-link DNS config, and a local stub listener on `127.0.0.53`

# Architecture

```text
 Application (getaddrinfo)
        |
        v
 +----- nsswitch.conf -----+
 |  hosts: files dns       |
 +---+----------------+----+
     |                |
     v                v
 /etc/hosts      DNS resolver
 (static map)        |
                     v
          +--------------------+
          | /etc/resolv.conf   |   <-- may be symlink to systemd-resolved stub
          | nameserver x.x.x.x|
          | search example.com |
          +--------------------+
                     |
                     v
          +--------------------+
          | systemd-resolved   |   <-- optional, caching stub resolver
          | 127.0.0.53:53      |
          +--------+-----------+
                   |
                   v
           Upstream DNS servers
```

# Mental Model

```text
1. App calls getaddrinfo("web.example.com")
2. glibc reads /etc/nsswitch.conf  -->  hosts: files dns
3. "files" source  -->  search /etc/hosts
   - Found?  Return IP immediately
4. "dns" source    -->  read /etc/resolv.conf for nameserver
   - If resolv.conf points to 127.0.0.53  -->  systemd-resolved handles query
   - Otherwise  -->  query nameserver directly
5. DNS response returned to application (may be cached by systemd-resolved)
```

```bash
# Example: resolve "web" with search domain appended
# /etc/resolv.conf contains: search example.com
# glibc expands "web" to "web.example.com" before querying DNS
getent hosts web
```

# Core Building Blocks

### nsswitch.conf — Resolution Order

- `/etc/nsswitch.conf` defines which sources are queried and in what order
- The `hosts:` line controls hostname resolution

```bash
# Typical hosts line
hosts: files dns

# With mDNS and systemd-resolved
hosts: files mdns4_minimal [NOTFOUND=return] resolve dns
```

| Source            | Description                              |
| :---------------- | :--------------------------------------- |
| `files`          | `/etc/hosts` static mappings             |
| `dns`            | Traditional DNS via `/etc/resolv.conf`   |
| `mdns4_minimal`  | mDNS for `.local` domains               |
| `resolve`        | systemd-resolved (via D-Bus)             |

Related notes: [005-dns-resolution-linux](./005-dns-resolution-linux.md), [004-DNS](../../Networking/004-DNS.md)

### /etc/hosts — Static Mappings

- Checked before DNS when `files` precedes `dns` in nsswitch.conf
- Simple `IP hostname` format, one entry per line

```text
127.0.0.1   localhost
192.168.1.10   myserver.local
```

Related notes: [004-DNS](../../Networking/004-DNS.md)

### /etc/resolv.conf — DNS Client Config

- Configures nameservers and search domains for traditional DNS resolution
- When `systemd-resolved` is active, this file is often a symlink to its stub (`/run/systemd/resolve/stub-resolv.conf`)
- Do not edit directly if managed by systemd-resolved; use `resolvectl` instead

```text
nameserver 8.8.8.8
nameserver 8.8.4.4
search example.com
```

- `nameserver` -- IP of upstream DNS resolver (max 3)
- `search` -- domain appended to short/unqualified names (e.g., `web` becomes `web.example.com`)

Related notes: [004-DNS](../../Networking/004-DNS.md)

### systemd-resolved — Caching Stub Resolver

- Systemd's built-in DNS resolver; caches results, supports per-link upstream servers
- Listens on `127.0.0.53` as a local stub; manages `/etc/resolv.conf` via symlink
- Configuration files:
  - Main: `/etc/systemd/resolved.conf`
  - Per-link: `/etc/systemd/network/*.network` or via `resolvectl dns <iface> <server>`

```bash
# Check resolver status
systemctl status systemd-resolved
resolvectl status

# Query a domain
resolvectl query example.com

# Flush DNS cache
resolvectl flush-caches

# Set DNS for a specific interface
resolvectl dns eth0 8.8.8.8
```

Related notes: [001-Network-interface](./001-Network-interface.md)

---

# Practical Command Set (Core)

```bash
# Resolve using full nsswitch chain (honours /etc/hosts + DNS)
getent hosts example.com

# Direct DNS query (bypasses /etc/hosts)
dig example.com
dig +short example.com
nslookup example.com

# Check which resolv.conf is in use
ls -l /etc/resolv.conf

# systemd-resolved cache flush
resolvectl flush-caches

# systemd-resolved status (shows per-link DNS servers)
resolvectl status
```

# Troubleshooting Guide

```text
Name not resolving?
  |
  +-> Check /etc/nsswitch.conf hosts: line
  |     - Is "files" before "dns"?
  |     - Is "resolve" listed if using systemd-resolved?
  |
  +-> Check /etc/hosts for static override
  |
  +-> Check /etc/resolv.conf
  |     - Is it a symlink to systemd-resolved stub?
  |     - Are nameservers correct?
  |     - Is search domain correct?
  |
  +-> Test with dig (bypasses nsswitch)
  |     - dig works but getent fails?  --> nsswitch or /etc/hosts issue
  |     - dig also fails?              --> DNS server unreachable or misconfigured
  |
  +-> Check systemd-resolved
        - resolvectl status
        - resolvectl flush-caches
        - systemctl restart systemd-resolved
```

# Quick Facts (Revision)

- `nsswitch.conf` `hosts:` line controls resolution order -- typically `files dns`
- `/etc/hosts` is checked first when `files` precedes `dns`
- `/etc/resolv.conf` supports up to 3 `nameserver` entries
- `search` domain auto-appends to unqualified hostnames
- `systemd-resolved` listens on `127.0.0.53` and caches DNS responses
- `getent hosts` follows the full nsswitch chain; `dig`/`nslookup` query DNS directly
- When systemd-resolved manages resolv.conf, edit DNS via `resolvectl` not the file
- `resolvectl flush-caches` clears the local DNS cache
