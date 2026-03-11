# IPsec and VPN

- IPsec (Internet Protocol Security) is a set of protocols used to secure IP traffic.
- It provides encryption, integrity, and authentication for packets.
- Often used for VPNs between sites or between user and company network.

# VPN

- VPN (Virtual Private Network) creates a secure connection over an untrusted network like the internet.
- It is used to connect user-to-company or site-to-site networks.
- IPsec is one common technology used to build VPNs.
- In simple words: VPN is the use case, IPsec is one of the technologies used to build it.

# What IPsec does

- Encrypts packet data so others cannot read it.
- Verifies integrity so packets are not changed in transit.
- Authenticates peers before sending protected traffic.

# Main Parts

### AH

- AH (Authentication Header) provides integrity and authentication.
- It does not encrypt the payload.
- Less common in practice.

### ESP

- ESP (Encapsulating Security Payload) provides encryption and can also provide integrity.
- Most modern IPsec setups use ESP.

### IKE

- IKE (Internet Key Exchange) is used to negotiate security settings and keys.
- IKEv2 is common in modern deployments.

# Modes

### Transport Mode

- Protects the IP payload.
- Original IP header stays visible.
- Often used for host-to-host communication.

### Tunnel Mode

- Wraps the whole original IP packet inside a new packet.
- Common for site-to-site VPN and remote access VPN.

# Common Use Cases

- Site-to-site VPN between two offices
- Remote user VPN to company network
- Protect traffic between servers over untrusted networks

# Simple Flow

```text
Original packet
  -> IPsec encrypts and/or signs it
  -> sent through internet
  -> receiver verifies and decrypts it
```

# Notes

- IPsec works at Layer 3.
- It is different from TLS, which usually protects application-layer traffic.
- If you only need secure web traffic, TLS is usually enough.
- If you need to protect network-to-network traffic, IPsec is common.
