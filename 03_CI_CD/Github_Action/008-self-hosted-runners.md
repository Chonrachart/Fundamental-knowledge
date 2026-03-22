# Self-Hosted Runners

- Self-hosted runners execute GitHub Actions workflows on your own infrastructure instead of GitHub-hosted VMs.
- Use cases: private network access, custom hardware (GPU, ARM), cost control for heavy CI, compliance requirements.
- Runners register at repo, org, or enterprise level; labels control which jobs target which runners.

# Architecture

```text
GitHub.com
  └── Webhook event (push, PR)
        │
        ▼
  Actions orchestrator selects runner
  matching `runs-on:` labels
        │
        ▼
┌─────────────────────────────┐
│  Your Infrastructure        │
│                             │
│  ┌───────────────────────┐  │
│  │  Runner Agent         │  │
│  │  (actions/runner)     │  │
│  │                       │  │
│  │  Polls GitHub API     │  │
│  │  for queued jobs      │  │
│  │                       │  │
│  │  Executes steps in    │  │
│  │  local environment    │  │
│  └───────────────────────┘  │
│                             │
│  VM / Container / Bare metal│
└─────────────────────────────┘
```

# Mental Model

```text
1. Admin registers runner → gets token from GitHub
2. Runner agent starts → polls GitHub for jobs
3. Workflow with `runs-on: [self-hosted, linux]` queued
4. Matching runner picks up the job
5. Steps execute on the runner's local environment
6. Results and logs streamed back to GitHub
```

Example:
```bash
# On the runner machine
./config.sh --url https://github.com/ORG/REPO --token TOKEN
./run.sh                    # start runner (foreground)
# or install as service:
sudo ./svc.sh install
sudo ./svc.sh start
```

# Core Building Blocks

### Registration Levels

| Level | Scope | Use case |
|-------|-------|----------|
| Repository | One repo only | Small projects, specific needs |
| Organization | All repos in org (or restricted via runner groups) | Shared CI infrastructure |
| Enterprise | All orgs in enterprise | Centralized fleet management |

### Labels and Targeting

- Default labels: `self-hosted`, OS (`linux`, `windows`, `macos`), architecture (`x64`, `arm64`).
- Custom labels: add during registration or via Settings → Actions → Runners.
- Target in workflow: `runs-on: [self-hosted, linux, gpu]`.

```yaml
jobs:
  train:
    runs-on: [self-hosted, linux, gpu]
    steps:
    - uses: actions/checkout@v4
    - run: python train.py
```

### Runner Groups

- Organization/enterprise feature; control which repos can use which runners.
- Default group: all repos can access. Create custom groups for restricted runners.
- Use for security boundaries: production deploy runners vs. general CI runners.

### Security Considerations

- Self-hosted runners persist state between jobs — previous job's files, env vars, or credentials may leak.
- **Never use self-hosted runners on public repos** — anyone can submit a PR that runs code on your infrastructure.
- Mitigation: use ephemeral runners (`--ephemeral` flag) that reset after each job.
- Container isolation: run jobs inside Docker containers to limit access to the host.

### Ephemeral and Auto-Scaling Runners

- `--ephemeral`: Runner picks up one job, then de-registers. Clean environment each time.
- **actions-runner-controller (ARC)**: Kubernetes-based auto-scaler; spins up runner pods on demand.
- **VM scale sets**: Cloud-native auto-scaling (Azure VMSS, AWS ASG + custom AMI).

```bash
# Register ephemeral runner
./config.sh --url https://github.com/ORG/REPO --token TOKEN --ephemeral
```

### Maintenance

- Runner agent auto-updates by default; can disable with `RUNNER_ALLOW_RUNASROOT`.
- Monitor runner status: Settings → Actions → Runners (online/offline/busy).
- Clean up work directories periodically: `_work/` grows with each job.
- Check runner logs: `_diag/` directory for troubleshooting.

Related notes: [001-github-actions-overview](./001-github-actions-overview.md), [002-workflow-syntax](./002-workflow-syntax.md)


- Self-hosted runners poll GitHub; GitHub doesn't push to them — no inbound firewall rules needed.
- Default labels are auto-detected: `self-hosted`, OS, architecture.
- `--ephemeral` runners handle one job then exit — best for security and clean state.
- Never use self-hosted runners for public repos — fork PRs can execute arbitrary code.
- Runner groups (org/enterprise) restrict which repos can target which runners.
- actions-runner-controller (ARC) is the standard solution for auto-scaling runners on Kubernetes.
- Runner agent auto-updates; logs are in `_diag/` directory.
- Self-hosted runners have access to the host network — useful for private registries and internal services.
---

# Troubleshooting Guide

### Runner shows "Offline" in GitHub
1. Check runner process: `systemctl status actions.runner.*` or check if `./run.sh` is running.
2. Check network: runner must reach `github.com` and `*.actions.githubusercontent.com` on HTTPS (443).
3. Check token: expired registration token; re-register with a new token.
4. Check logs: `_diag/Runner_*.log` for errors.

### Job queued but no runner picks it up
1. Check `runs-on:` labels match runner labels exactly (case-sensitive).
2. Check runner is online and idle (not busy with another job).
3. Check runner group: repo must be allowed to use the runner's group.
4. If using `--ephemeral`: runner may have already processed one job and de-registered.

### Artifacts or state leaking between jobs
1. Runner is not ephemeral: previous job's files remain in `_work/` directory.
2. Use `--ephemeral` flag for clean environment per job.
3. Add cleanup step at end of workflow: `- run: rm -rf $GITHUB_WORKSPACE/*`.
4. Use container-based jobs (`container:` in job spec) for isolation.
