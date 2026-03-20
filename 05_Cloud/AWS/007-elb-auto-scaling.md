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

# Core Building Blocks

### Load Balancer Types

| Type | Layer | Use Case |
|------|-------|----------|
| ALB | L7 (HTTP/HTTPS) | Web apps, path/host routing, gRPC |
| NLB | L4 (TCP/UDP) | High performance, static IP, non-HTTP |
| CLB | L4/L7 (legacy) | Avoid for new deployments |

### ALB (Application Load Balancer)

- **Listener**: Port + protocol (80/HTTP, 443/HTTPS); rules route to target groups.
- **Target Group**: Set of targets (instances, IPs, Lambda); health check configurable.
- **Routing rules**: Path-based (`/api/*`), host-based (`api.example.com`), headers, query strings.
- **SSL termination**: Attach ACM certificate; offload TLS at the ALB.

### NLB (Network Load Balancer)

- Layer 4; ultra-low latency; millions of requests/sec.
- Static IP per AZ (or Elastic IP); preserves source IP.
- Use for: TCP services, gRPC, non-HTTP protocols.

### Target Groups and Health Checks

- Health check: protocol, path, interval, threshold.
- Unhealthy targets removed from rotation; re-added when healthy.
- Target types: `instance`, `ip`, `lambda`.

### Auto Scaling Group (ASG)

- **Launch Template**: Defines AMI, instance type, key pair, security group, user data.
- **Capacity**: Min, Desired, Max instance count.
- **Scaling policies**: Target tracking (e.g. CPU 60%), step scaling, scheduled.
- **Health checks**: EC2 status checks + optional ELB health checks.

```text
Scaling Policy: Target Tracking
  Metric: Average CPU Utilization
  Target: 60%

  CPU > 60% → scale out (add instances)
  CPU < 60% → scale in (remove instances)
  Cooldown: 300 seconds between adjustments
```

### ASG + ALB Integration

- ASG registers/deregisters instances with ALB target group automatically.
- ALB health check failures trigger instance replacement by ASG.
- Connection draining: ALB waits for in-flight requests before deregistering.

Related notes: [003-vpc-networking](./003-vpc-networking.md), [004-ec2](./004-ec2.md)

---

# Troubleshooting Guide

### Targets showing "unhealthy" in target group
1. Check health check path returns 200 (e.g. `/health`); app may not be running.
2. Check Security Group: ALB SG must allow outbound to target port; target SG must allow inbound from ALB SG.
3. Check health check port matches app listening port.
4. Increase unhealthy threshold or health check interval for slow-starting apps.

### ASG not scaling out
1. Check scaling policy: is the metric breaching the threshold?
2. Check Max capacity: ASG won't exceed `max` instances.
3. Check AZ capacity: try adding more AZs to the ASG.
4. Check launch template: AMI still exists, instance type available.

### 504 Gateway Timeout from ALB
1. Backend (target) is not responding in time.
2. Check target health and logs.
3. Increase ALB idle timeout (default 60s) if backend needs more time.
4. Check Security Group allows ALB → target communication.

# Quick Facts (Revision)

- ALB operates at Layer 7 (HTTP); NLB at Layer 4 (TCP); avoid CLB (legacy).
- ALB supports path-based and host-based routing with multiple target groups.
- ASG automatically replaces unhealthy instances and scales based on policies.
- Launch Templates replace Launch Configurations (deprecated) — always use templates.
- Connection draining (deregistration delay) prevents dropped requests during scale-in.
- NLB preserves client source IP; ALB sets `X-Forwarded-For` header.
- Target tracking scaling is the simplest policy — set target CPU and let ASG manage.
- Cross-zone load balancing distributes traffic evenly across all targets in all AZs.
