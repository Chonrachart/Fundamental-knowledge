# ECS and EKS — Container Services

- ECS (Elastic Container Service) is AWS-native container orchestration; simpler than Kubernetes, tightly integrated with AWS.
- EKS (Elastic Kubernetes Service) runs managed Kubernetes control plane; use standard K8s tools and APIs.
- Fargate provides serverless compute for both ECS and EKS — no EC2 instances to manage.

# Architecture

```text
ECS Architecture:
  Cluster → Service → Task (= running container group)

  Task Definition (= pod spec equivalent)
    ├── Container 1: app image, port, env
    └── Container 2: sidecar image

  Launch Type:
    ├── Fargate: serverless (no EC2 management)
    └── EC2: your instances in the cluster

EKS Architecture:
  AWS manages control plane (API server, etcd, scheduler)
  You manage worker nodes (or use Fargate)

  Node Groups:
    ├── Managed Node Group (AWS manages EC2)
    ├── Self-managed Node Group (you manage EC2)
    └── Fargate Profile (serverless pods)
```

# Mental Model

```text
ECS container deployment flow:
1. Build container image, push to ECR
2. Create task definition (image, CPU, memory, ports, env vars)
3. Create ECS service (desired count, launch type: Fargate/EC2)
4. Service scheduler places tasks across AZs
5. Register tasks with ALB target group
6. ALB routes traffic to running containers
7. Service auto-scales based on CloudWatch metrics
```

# Core Building Blocks

### ECS Concepts

| ECS Term | K8s Equivalent | Description |
|----------|---------------|-------------|
| Cluster | Cluster | Group of services and tasks |
| Task Definition | Pod spec | Container images, ports, env, resources |
| Task | Pod | Running instance of a task definition |
| Service | Deployment | Maintains desired count of tasks |
| Container | Container | Single container in a task |
- Task definition is to ECS what a Pod spec is to Kubernetes.

Related notes: [001-aws-overview](./001-aws-overview.md)

### ECS Launch Types

| Type | Manage | Cost | Use Case |
|------|--------|------|----------|
| Fargate | No EC2 | Per vCPU + memory/second | Simplicity, variable workloads |
| EC2 | Your instances | Instance cost | GPU, custom AMI, cost optimization |
- Fargate eliminates EC2 management for both ECS and EKS — pay per task resources.
- Fargate tasks in private subnets need NAT Gateway for internet access (pull images, etc.).

Related notes: [004-ec2](./004-ec2.md), [003-vpc-networking](./003-vpc-networking.md)

### ECS Service with ALB

```text
ALB → Target Group → ECS Service (desired: 3 tasks)
                       ├── Task 1 (Fargate, AZ-a)
                       ├── Task 2 (Fargate, AZ-b)
                       └── Task 3 (Fargate, AZ-a)
```

- ECS service auto-registers tasks with ALB target group.
- Health checks: ALB health check + ECS container health check.
- Service auto-scaling: target tracking on CPU, memory, or ALB request count.
- ECS service auto-scaling uses Application Auto Scaling (not EC2 ASG).

Related notes: [007-elb-auto-scaling](./007-elb-auto-scaling.md)

### ECR (Elastic Container Registry)

- Private Docker registry on AWS; stores container images.
- Integrates with ECS, EKS, and Lambda for pulling images.
- Image scanning for vulnerabilities; lifecycle policies for cleanup.
- ECR is the standard private registry for AWS container workloads.

Related notes: [002-iam](./002-iam.md)

```bash
# Login, build, push
aws ecr get-login-password | docker login --username AWS --password-stdin <account>.dkr.ecr.<region>.amazonaws.com
docker build -t my-app .
docker tag my-app:latest <account>.dkr.ecr.<region>.amazonaws.com/my-app:latest
docker push <account>.dkr.ecr.<region>.amazonaws.com/my-app:latest
```

### EKS Basics

- AWS manages the Kubernetes control plane (API server, etcd, scheduler, controller-manager).
- You interact with standard `kubectl`; use `aws eks update-kubeconfig` to configure.
- Node options: Managed Node Groups (recommended), self-managed, or Fargate profiles.
- EKS control plane is managed by AWS; you manage worker nodes (or use Fargate).
- `aws eks update-kubeconfig` configures kubectl for EKS cluster access.

Related notes: [002-iam](./002-iam.md), [003-vpc-networking](./003-vpc-networking.md)

```bash
# Configure kubectl for EKS
aws eks update-kubeconfig --name my-cluster --region us-east-1
kubectl get nodes
kubectl get pods -A
```

### ECS vs EKS

| Factor | ECS | EKS |
|--------|-----|-----|
| Complexity | Simpler (AWS-native) | More complex (full K8s) |
| Portability | AWS-only | Multi-cloud (standard K8s) |
| Ecosystem | AWS tools only | Helm, Argo, Istio, etc. |
| Learning curve | Lower | Higher (K8s knowledge required) |
| Best for | AWS-only shops, simpler apps | K8s expertise, multi-cloud, complex apps |
- ECS is AWS-native and simpler; EKS is standard Kubernetes — choose based on team expertise.

Related notes: [001-aws-overview](./001-aws-overview.md), [004-ec2](./004-ec2.md), [007-elb-auto-scaling](./007-elb-auto-scaling.md)

---

# Troubleshooting Guide

### ECS task keeps stopping (essential container exited)
1. Check task stopped reason: ECS Console → Cluster → Tasks → Stopped tab.
2. Check container logs: CloudWatch Logs (configure `awslogs` log driver in task definition).
3. Common: missing env var, wrong image tag, app crash, health check failure.
4. Test image locally: `docker run` with same env vars.

### ECS service stuck at 0 running tasks
1. Check task definition: image exists in ECR, ports match.
2. Check IAM: task execution role needs `ecr:GetDownloadUrlForLayer` and `logs:CreateLogStream`.
3. Check VPC: Fargate tasks need NAT Gateway (private subnet) or IGW (public subnet with `assignPublicIp: ENABLED`).

### kubectl cannot connect to EKS cluster
1. Update kubeconfig: `aws eks update-kubeconfig --name <cluster>`.
2. Check IAM identity: `aws sts get-caller-identity` — must match cluster creator or aws-auth ConfigMap.
3. Check cluster endpoint access: public, private, or both.
