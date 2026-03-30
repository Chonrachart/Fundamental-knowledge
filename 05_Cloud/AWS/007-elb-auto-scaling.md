# ELB and Auto Scaling

- Elastic Load Balancing distributes traffic across targets (EC2, containers, IPs) in multiple AZs for high availability.
- Auto Scaling Groups (ASG) automatically adjust EC2 instance count based on demand, schedule, or health.
- ALB + ASG is the standard pattern for scalable, fault-tolerant web applications on AWS.

# Architecture

```text
Internet → Route 53 (DNS)
              │
              ▼
        ALB (Application Load Balancer)
        ├── Listener: 443 (HTTPS)
        │     └── Rules → Target Group
        └── Listener: 80 (HTTP → redirect 443)

Target Group
  ├── Instance A (AZ-a) ← healthy
  ├── Instance B (AZ-b) ← healthy
  └── Instance C (AZ-a) ← unhealthy (removed)

Auto Scaling Group
  ├── Min: 2, Desired: 3, Max: 10
  ├── Launch Template (AMI, instance type, user data)
  └── Scaling Policy: target CPU 60%
```

# Mental Model

```text
Request flow through ALB + ASG:
1. Client sends request to ALB DNS name
2. ALB receives on listener (port 80/443)
3. Listener rules evaluate (host, path)
4. Request forwarded to target group
5. Health check determines healthy targets
6. Target (EC2) processes request
7. CloudWatch alarm triggers ASG scaling policy
8. ASG launches/terminates instances, registers with target group
```

# Core Building Blocks

### Load Balancer Types

| Type | Layer | Use Case |
|------|-------|----------|
| ALB | L7 (HTTP/HTTPS) | Web apps, path/host routing, gRPC |
| NLB | L4 (TCP/UDP) | High performance, static IP, non-HTTP |
| CLB | L4/L7 (legacy) | Avoid for new deployments |
- ALB operates at Layer 7 (HTTP); NLB at Layer 4 (TCP); avoid CLB (legacy).

Related notes: [003-vpc-networking](./003-vpc-networking.md)

### ALB (Application Load Balancer)

- **Listener**: Port + protocol (80/HTTP, 443/HTTPS); rules route to target groups.
- **Target Group**: Set of targets (instances, IPs, Lambda); health check configurable.
- **Routing rules**: Path-based (`/api/*`), host-based (`api.example.com`), headers, query strings.
- **SSL termination**: Attach ACM certificate; offload TLS at the ALB.
- ALB supports path-based and host-based routing with multiple target groups.
- Cross-zone load balancing distributes traffic evenly across all targets in all AZs.

Related notes: [003-vpc-networking](./003-vpc-networking.md), [005-security-groups](./005-security-groups.md)

### NLB (Network Load Balancer)

- Layer 4; ultra-low latency; millions of requests/sec.
- Static IP per AZ (or Elastic IP); preserves source IP.
- Use for: TCP services, gRPC, non-HTTP protocols.
- NLB preserves client source IP; ALB sets `X-Forwarded-For` header.

Related notes: [003-vpc-networking](./003-vpc-networking.md)

### Target Groups and Health Checks

- Health check: protocol, path, interval, threshold.
- Unhealthy targets removed from rotation; re-added when healthy.
- Target types: `instance`, `ip`, `lambda`.

Related notes: [004-ec2](./004-ec2.md), [009-lambda-serverless](./009-lambda-serverless.md)

### Auto Scaling Group (ASG)

- **Launch Template**: Defines AMI, instance type, key pair, security group, user data.
- **Capacity**: Min, Desired, Max instance count.
- **Scaling policies**: Target tracking (e.g. CPU 60%), step scaling, scheduled.
- **Health checks**: EC2 status checks + optional ELB health checks.
- ASG automatically replaces unhealthy instances and scales based on policies.
- Launch Templates replace Launch Configurations (deprecated) — always use templates.
- Target tracking scaling is the simplest policy — set target CPU and let ASG manage.

```text
Scaling Policy: Target Tracking
  Metric: Average CPU Utilization
  Target: 60%

  CPU > 60% → scale out (add instances)
  CPU < 60% → scale in (remove instances)
  Cooldown: 300 seconds between adjustments
```

Related notes: [004-ec2](./004-ec2.md)

### ASG + ALB Integration

- ASG registers/deregisters instances with ALB target group automatically.
- ALB health check failures trigger instance replacement by ASG.
- Connection draining: ALB waits for in-flight requests before deregistering.
- Connection draining (deregistration delay) prevents dropped requests during scale-in.

Related notes: [003-vpc-networking](./003-vpc-networking.md), [004-ec2](./004-ec2.md)
