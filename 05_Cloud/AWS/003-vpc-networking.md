# VPC and Networking

- VPC (Virtual Private Cloud) is an isolated virtual network in one AWS region; you define the CIDR block, subnets, and routing.
- Public subnets route to the Internet Gateway; private subnets use NAT Gateway for outbound-only internet access.
- Security Groups (stateful, instance-level) and NACLs (stateless, subnet-level) control traffic.

# Architecture

```text
VPC (10.0.0.0/16)
├── Public Subnet (10.0.1.0/24) — AZ-a
│     ├── Route: 0.0.0.0/0 → IGW
│     ├── ALB, NAT Gateway, Bastion
│     └── SG: allow 80, 443 from 0.0.0.0/0
│
├── Private Subnet (10.0.10.0/24) — AZ-a
│     ├── Route: 0.0.0.0/0 → NAT Gateway
│     ├── EC2 app servers, RDS
│     └── SG: allow 8080 from ALB SG
│
├── Public Subnet (10.0.2.0/24) — AZ-b    (Multi-AZ)
│     └── Route: 0.0.0.0/0 → IGW
│
└── Private Subnet (10.0.20.0/24) — AZ-b
      └── Route: 0.0.0.0/0 → NAT Gateway (AZ-b)

Internet Gateway (IGW) — attached to VPC
NAT Gateway — in public subnet, has Elastic IP
```

# Mental Model

```text
Packet flow: Internet → EC2 instance in private subnet

[1] Request hits Internet Gateway (IGW)
[2] Route table directs to public subnet
[3] NACL evaluates inbound rules (stateless -- both directions checked)
[4] ALB/NAT in public subnet receives traffic
[5] Route table directs to private subnet
[6] NACL evaluates inbound rules for private subnet
[7] Security Group evaluates inbound rules (stateful -- return traffic auto-allowed)
[8] EC2 instance receives request
```

### Concrete example: Web request through ALB to private EC2

```text
User browser → https://app.example.com
  │
  ▼
[IGW] Internet Gateway receives HTTPS request
  │
  ▼
[Route Table: public subnet] 0.0.0.0/0 → igw-xxx matches → public subnet
  │
  ▼
[NACL: public subnet] Rule 100 ALLOW TCP 443 inbound ✔
  │
  ▼
[ALB: 10.0.1.50] in public subnet, listener on 443
  ALB terminates TLS, forwards to target group on port 8080
  │
  ▼
[Route Table: private subnet] 10.0.10.0/24 → local matches → private subnet
  │
  ▼
[NACL: private subnet] Rule 100 ALLOW TCP 8080 from 10.0.1.0/24 ✔
  │
  ▼
[SG: app-server] Inbound ALLOW TCP 8080 from sg-alb ✔
  │
  ▼
[EC2: 10.0.10.20] App server receives request on port 8080
  │
  ▼
Response follows reverse path:
  EC2 → SG (stateful, auto-allowed) → NACL (must allow ephemeral ports 1024-65535 outbound)
  → ALB → NACL outbound → IGW → User browser
```

- The key difference between SG and NACL shows here: the Security Group auto-allows the return traffic (stateful), but the NACL requires explicit outbound rules for ephemeral ports (stateless).
- ALB lives in the public subnet so it can receive internet traffic; EC2 stays in the private subnet, reachable only from the ALB's Security Group.

Related notes: [000-core](./000-core.md) for generic cloud concepts, [007-elb-auto-scaling](./007-elb-auto-scaling.md) for ALB details

# Core Building Blocks

### VPC and CIDR

- VPC CIDR: typically `/16` (65,536 IPs); cannot change after creation (can add secondary CIDR).
- Subnets divide the VPC CIDR; each subnet is in **one AZ**.
- AWS reserves first 4 and last 1 IP in each subnet (5 IPs total).
- Common pattern: `/16` VPC → `/24` subnets (251 usable IPs each).
- VPC is regional; subnets are AZ-specific.
- AWS reserves 5 IPs per subnet (first 4 + last 1).
- Default VPC exists in every region but use custom VPCs for production.

### Subnets

- **Public subnet**: Has route `0.0.0.0/0 → IGW`; instances can have public IPs.
- **Private subnet**: No IGW route; outbound via NAT Gateway; instances have private IPs only.
- Deploy across multiple AZs for high availability.
- Deploy across 2+ AZs for high availability.

### Route Tables

- **Main route table**: Default for unassociated subnets; has local route only.
- **Custom route table**: Explicit associations; add routes for IGW, NAT, peering, etc.
- One route table per subnet; one table can serve multiple subnets.
- Local route (VPC CIDR → local) is always present and cannot be removed.

### Internet Gateway (IGW)

- One per VPC; enables internet connectivity.
- Must be attached to VPC and referenced in route table (`0.0.0.0/0 → igw-xxx`).
- **Public IP**: Auto-assigned at launch (changes on stop/start) or **Elastic IP** (static; charged if unattached).
- Elastic IPs are free when attached to a running instance; charged when unattached.

### NAT Gateway

- Placed in **public** subnet; has Elastic IP; private subnet routes `0.0.0.0/0 → nat-xxx`.
- Allows outbound internet (e.g. package updates) without inbound access.
- Managed by AWS; one per AZ for HA; costs per hour + per GB.
- NAT Gateway enables outbound-only internet for private subnets.

### Security Group — Stateful Firewall

- **Stateful**: Allow outbound → return traffic automatically allowed (and vice versa).
- **Rules**: Allow only (no deny); protocol, port, source/destination (CIDR or SG reference).
- **Default**: Deny all inbound, allow all outbound.
- One SG can be applied to many instances; one instance can have multiple SGs (rules are additive).

```text
SG: web-server
  Inbound:  TCP 80  from 0.0.0.0/0
  Inbound:  TCP 443 from 0.0.0.0/0
  Inbound:  TCP 22  from 10.0.0.0/8   (SSH from VPC only)
  Outbound: All traffic → 0.0.0.0/0
```

### NACL — Stateless Subnet Firewall

- **Stateless**: Must explicitly allow both inbound and outbound (including ephemeral ports for return traffic).
- **Numbered rules**: Evaluated in order; first match wins; implicit deny at end.
- **Subnet level**: One NACL per subnet; default NACL allows all.
- Use for: IP-based deny rules, extra defense layer.

### SG vs NACL

| Feature | Security Group | NACL |
|---------|---------------|------|
| Level | Instance (ENI) | Subnet |
| Stateful | Yes | No |
| Rules | Allow only | Allow + Deny |
| Evaluation | All rules (union) | In order (first match) |
| Default | Deny in, Allow out | Allow all |
- Security Groups are stateful (return traffic auto-allowed); NACLs are stateless.

### VPC Peering

- Connect two VPCs (same/different accounts/regions); non-transitive.
- Both VPCs must add routes to each other's CIDR: `10.1.0.0/16 → pcx-xxx`.
- No overlapping CIDRs allowed.
- VPC Peering is non-transitive; use Transit Gateway for hub-and-spoke.

Related notes: [001-aws-overview](./001-aws-overview.md), [004-ec2](./004-ec2.md), [007-elb-auto-scaling](./007-elb-auto-scaling.md)

---

# Troubleshooting Guide

### Instance not reachable from internet
1. Check subnet route table: `0.0.0.0/0 → igw-xxx` present?
2. Check instance has public IP or Elastic IP.
3. Check Security Group: inbound rule for the required port from `0.0.0.0/0`.
4. Check NACL: allows inbound on port AND outbound on ephemeral ports (1024-65535).

### Private instance cannot reach internet
1. Check NAT Gateway exists in public subnet and is active.
2. Check private subnet route: `0.0.0.0/0 → nat-xxx`.
3. Check NAT Gateway's subnet has route `0.0.0.0/0 → igw-xxx`.
4. Check Security Group allows outbound traffic.

### VPC Peering not working
1. Check both VPCs have routes to each other's CIDR via peering connection.
2. Check Security Groups allow traffic from peer VPC CIDR.
3. Check CIDRs don't overlap.
4. Check peering connection is in "Active" state (both sides must accept).
