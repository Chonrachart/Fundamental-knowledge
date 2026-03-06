VPC
subnet
CIDR
route table
internet gateway
NAT gateway
security group
NACL
peering

---

# VPC and CIDR

- **VPC**: Isolated network in a region; you choose **CIDR** (e.g. 10.0.0.0/16); cannot change after creation (can add secondary CIDR in some cases).
- **Subnet**: Segment of VPC CIDR in **one AZ** (e.g. 10.0.1.0/24); first 4 and last 1 IP reserved by AWS in each subnet.
- **Public subnet**: Has route 0.0.0.0/0 → **Internet Gateway (IGW)**; instances can have public IP and be reachable from internet if allowed by security group.
- **Private subnet**: No route to IGW (or route to IGW only for specific needs); outbound via **NAT Gateway** in public subnet if you add 0.0.0.0/0 → nat-xxx.

# Route Table

- **Main route table**: Default for subnets that don’t have explicit association; local route (VPC CIDR → local) always present.
- **Custom route table**: Associate with one or more subnets; **0.0.0.0/0 → igw-xxx** = internet; **0.0.0.0/0 → nat-xxx** = outbound via NAT.
- **Subnet association**: One route table per subnet (no multiple); one route table can be associated with many subnets.

# Internet Gateway and Public IP

- **IGW**: One per VPC; allows traffic to/from internet; **attach** to VPC.
- **Public IP** (auto-assign): Assigned at launch from AWS pool; released when instance stops/terminates; not static.
- **Elastic IP**: Static; attach to instance; **charged if allocated but not attached**; use for stable public IP.

# NAT Gateway

- **NAT Gateway**: In **public** subnet; has public IP; private subnet instances route 0.0.0.0/0 → NAT → internet (outbound only).
- **Managed** by AWS; high availability in one AZ; for multi-AZ use one NAT per AZ or consider **NAT instance** (self-managed).
- **Cost**: Per hour + per GB processed; minimize egress if cost-sensitive.

# Security Group — Stateful Firewall

- **Stateful**: Allow outbound → response allowed back automatically; allow inbound only if rule exists.
- **Rules**: Inbound and outbound; **protocol**, **port range**, **source/dest** (CIDR or another security group).
- **No deny** rules; default deny; only allow rules; **evaluate all rules** (allow if any rule matches).
- **One security group** can be attached to many ENIs; **one ENI** can have multiple security groups (rules are additive).

# NACL — Stateless Subnet Firewall

- **Network ACL**: Optional; **stateless** (allow outbound does not auto-allow return); **subnet** level; **numbered rules** (e.g. 100, 200); **evaluate in order**; first match wins; default **deny** at end.
- **Ephemeral ports**: For return traffic, open high ports (e.g. 1024–65535) for outbound or inbound as needed.
- Use for **deny** by IP or as extra layer; most use cases are covered by security groups.

# VPC Peering

- **Peering**: Connect two VPCs (same or different accounts/regions); **no transitive** (VPC A ↔ B and B ↔ C does not give A ↔ C).
- **Route tables**: Add route to **peered VPC CIDR** with target **pcx-xxx** (peering connection); both sides must have routes.
- **Security groups**: Reference peer VPC security group (same account) or use CIDR of peer VPC; no overlap of CIDR between VPCs allowed.
