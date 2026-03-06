# DNS Resolution on Linux

- Linux resolves hostnames to IP addresses using a configurable resolution flow.
- Resolution order and sources depend on `/etc/nsswitch.conf` and `/etc/resolv.conf`.

---

# Resolution Order (nsswitch.conf)

- `/etc/nsswitch.conf` defines the order of resolution sources.

```bash
# Typical line for hosts
hosts: files dns
```

- `files` — `/etc/hosts` first
- `dns` — then DNS (via resolv.conf or systemd-resolved)

### Other Possible Sources

- `mdns4_minimal` — mDNS for `.local`
- `resolve` — systemd-resolved

# /etc/hosts

- Static mapping; checked before DNS (when `files` comes before `dns`).

```
127.0.0.1   localhost
192.168.1.10   myserver.local
```

- Edit: `sudo nano /etc/hosts`

# /etc/resolv.conf

- Configures DNS servers and search domains (when not using systemd-resolved).

```
nameserver 8.8.8.8
nameserver 8.8.4.4
search example.com
```

- `nameserver` — IP of DNS resolver
- `search` — domain appended for short names (e.g. `web` → `web.example.com`)

### Note on systemd-resolved

- When `systemd-resolved` is active, `/etc/resolv.conf` is often a symlink to `systemd-resolved`'s stub.
- Do not edit `/etc/resolv.conf` directly in that case; use `resolvectl` or `systemd-resolved` config.

# systemd-resolved

- systemd's DNS resolver; caches results and can use multiple upstream servers.
- Often manages `/etc/resolv.conf` (points to `127.0.0.53` stub).

```bash
# Status
systemctl status systemd-resolved

# Query
resolvectl query example.com

# Flush cache
resolvectl flush-caches
```

### Configuration

- Main config: `/etc/systemd/resolved.conf`
- Per-link config: `/etc/systemd/network/*.network` or `resolvectl dns eth0 8.8.8.8`

# getent and dig

```bash
# Resolve using nsswitch order
getent hosts example.com

# Direct DNS query (bypasses /etc/hosts)
dig example.com
nslookup example.com
```

# Resolution Flow (Summary)

```
Application calls getaddrinfo("example.com")
        ↓
nsswitch: hosts: files dns
        ↓
1. Check /etc/hosts
   → If found, return IP
        ↓
2. If not found, use DNS
   → Read /etc/resolv.conf or use systemd-resolved
   → Send query to nameserver
   → Return result (possibly cached)
```
[04-DNS.md](../../Networking/04-DNS.md)