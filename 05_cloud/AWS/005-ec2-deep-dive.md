EC2
instance type
EBS
AMI
placement
user data
metadata
instance profile

---

# Instance Types — Families and Naming

- **Naming**: **family.generation.size** (e.g. t3.micro, m5.large).
- **t**: Burstable (CPU credits); **m**: General purpose; **c**: Compute-optimized; **r**: Memory-optimized; **g**: GPU; **i**: Storage-optimized.
- **Generation**: 3, 4, 5 (newer = better perf/price); **size**: micro, small, medium, large, xlarge, 2xlarge...
- **t3.micro**: 2 vCPU (burstable), 1 GiB RAM; free tier eligible. **m5.large**: 2 vCPU, 8 GiB; general purpose.

# EBS — Storage Attached to Instance

- **Volume**: Attached to one instance (in same AZ); **root** or **additional** volumes.
- **Types**: **gp3** (general SSD), **gp2**, **io1/io2** (high IOPS), **st1/sc1** (throughput/magnetic HDD).
- **Size**: GB; **IOPS** and **throughput** (for gp3/io2) for performance.
- **Root volume**: Often delete on terminate; **additional** volumes: default delete on terminate = false (data preserved if instance terminated).
- **Snapshot**: Backup of volume (stored in S3); copy to other region; create new volume from snapshot.

# AMI — What It Contains

- **Root volume** snapshot (and optionally additional EBS snapshots); **block device mapping** (which snapshot → which device).
- **Kernel**, **ramdisk** (if paravirtual); **architecture** (x86_64, arm64).
- **Source**: Amazon (Amazon Linux), **AWS Marketplace** (third-party), **your own** (create from instance or from snapshot).
- **Region-specific**; copy AMI to other regions for DR or multi-region.

# Placement and Tenancy

- **Placement group**: **Cluster** (low latency, same rack); **Spread** (one per distinct hardware); **Partition** (for HDFS-style apps).
- **Tenancy**: **Default** (shared); **Dedicated** (dedicated host or instance); **Host** (your placement on dedicated host).
- **Capacity**: If AZ has no capacity, request fails; try another AZ or different instance type.

# User Data and Metadata

- **User data**: Script or cloud-init config; runs **once** at first boot (unless configured to run every boot); base64-encoded if binary.
- Use for: install packages, write config, start services; **#!/bin/bash** for shell script.
- **Instance metadata**: **IMDS** at **http://169.254.169.254** (v1 or v2 with token); get instance-id, AMI, IAM role creds, etc.; **not** from internet.
- **IMDSv2**: Session-oriented (PUT for token, then GET with header); prefer for security.

# IAM Instance Profile

- **Instance profile** = role that EC2 can **assume**; no long-term keys on instance; app uses **metadata** to get temporary credentials.
- Attach **instance profile** (role) at launch or attach later; **aws sts get-caller-identity** from instance to verify.
- **Least privilege**: Role policy only what app needs (e.g. S3 read one bucket, SSM for parameter).

# Lifecycle and Billing

- **Running** → **Stopped**: No compute charge; EBS charged; private IP can change unless Elastic IP; **Start** again in same AZ.
- **Terminate**: Instance and (by default) root EBS deleted; **Enable termination protection** to avoid accidental terminate.
- **Spot**: Interruptible; cheaper; use for fault-tolerant or checkpointed workloads.
