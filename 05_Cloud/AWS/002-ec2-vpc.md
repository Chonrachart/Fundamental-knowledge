EC2
AMI
instance type
security group
VPC
subnet
NAT
route table

---

# EC2

- Virtual server; choose AMI (OS image), instance type (vCPU, memory), storage (EBS), security group.
- **Key pair**: SSH key for login; create at launch or attach.
- **Elastic IP**: Static public IP; attach to instance; pay if not attached.

# AMI

- Amazon Machine Image; template for root volume (OS, pre-installed software).
- Use Amazon Linux, Ubuntu, or custom AMI; regional (copy to other regions if needed).

# Instance Type

- Family (t3, m5, c5) + size (micro, small, large); general purpose, compute-optimized, memory-optimized.
- **t3.micro**: Free tier eligible; small workloads.

# Security Group

- Stateful firewall; allow rules (inbound/outbound); no deny (default deny).
- By protocol/port and source/dest (CIDR or other security group).
- Attach to instance or ENI.

# VPC

- Virtual Private Cloud; isolated network in a region; you choose CIDR (e.g. 10.0.0.0/16).
- Default VPC per region; create custom VPC for production (subnets, routing).

# Subnet

- Segment of VPC CIDR (e.g. 10.0.1.0/24); in one AZ.
- **Public subnet**: Route to internet gateway for outbound; can have public IP.
- **Private subnet**: No direct IGW; use NAT gateway for outbound; no public IP from internet.

# Route Table

- Rules: destination CIDR → target (local, igw, nat-xxx, etc.).
- Subnet associated with route table; default route table for VPC.
- Public subnet: 0.0.0.0/0 → igw; private: 0.0.0.0/0 → nat gateway.

# NAT Gateway

- In public subnet; allows private subnet instances to reach internet (outbound); managed by AWS.
- NAT instance: self-managed alternative; less common.
