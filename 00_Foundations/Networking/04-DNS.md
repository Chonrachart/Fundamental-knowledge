# DNS (Domain Name System)

- DNS is essentially a name-to-address translation system.
- Allows organizations to change IP addresses without users noticing.
- DNS can return different IP addresses based on policies such as geographic location, load balancing, or latency.
- DNS performs this mapping:
  - `www.example.com → 93.184.216.34`

| sub domian | domain | top level domain |
| :--------: | :----: | :--------------: |
|    www     | google |       com        |

### How DNS Works (Resolution Process)

- When you access a website, several steps occur before the IP is returned.

1. Browser cache    
   - The browser first checks its local cache if you previously visited `example.com`
  the browser may already know the IP, If found, the DNS query stop.
  ```
    Browser cache
    example.com → 93.184.216.34
  ```

1. OS cache
   - If the browser does not know the address, the operating system checks its cache.
     - ex. in `/etc/host`, `systemd-resolved`

2. Recursive resolver
   - If the OS still does not know, it sends the query to a recursive DNS resolver.
   - The resolver is responsible for finding the answer.
  
3. Root server
   - The resolver asks a root DNS server.
   - Root servers **do not know** the final IP.
   - They only tell where the TLD servers are.
   - There are 13 logical root server clusters globally.

4. TLD server
   - The Top Level Domain (TLD) server manages domains like:
     - `.com`, `.org`, `.net`
     - The TLD server returns the address of the authoritative nameserver.
  
5. Authoritative server
   - The authoritative DNS server holds the real DNS records.
   - The resolver receives the IP and returns it to the client.

### DNS Components

- Domain Name
- IP Address
- DNS Resolver
  - Server that performs DNS lookup on behalf of clients.
- Root Servers
- TLD Servers
- Authoritative Servers

### DNS Types

- Forward DNS
  - Domain → IP

- Reverse DNS
  - IP → Domain
  - Uses PTR records

### DNS Record Types

These are entries stored in a DNS zone.

- A Record
  - Maps a domain to an IPv4 address.
  - `example.com   A   10.100.100.106`
- AAAA Record
  - Maps a domain to an IPv6 address.
  - `example.com   AAAA   2606:2800:220:1:248:1893:25c8:1946`
- CNAME
  - Alias record.
  - `www.example.com → example.com`
  - Meaning www points to another domain.
- MX Record
  - Mail server for a domain.
  - `example.com   MX   mail.example.com`
  - Used by email systems.
- NS Record
  - Defines the nameservers responsible for the domain.
  - `example.com   NS   ns1.example.com`
  - `example.com   NS   ns2.example.com`
- PTR Record
  - Used for reverse DNS.
  - `34.216.184.93 → example.com`
- TXT Record
  - Stores text information.

### TTL (Time To Live)

- DNS records contain a TTL value that determines how long results can be cached.
- Example:
  - `example.com  A  10.100.100.106  TTL=3600`

### Example DNS Lookup (End-to-End)

User types:
```
www.example.com
```
Process:
```
Browser cache
   ↓
OS cache
   ↓
Recursive resolver
   ↓
Root server
   ↓
TLD server (.com)
   ↓
Authoritative server
   ↓
IP returned: 93.184.216.34
```
Then the browser connects to the web server at that IP.

![DNS](./pic/56275.jpg)