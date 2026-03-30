# GitHub Actions

- CI/CD platform built into GitHub; workflows defined in YAML under `.github/workflows/`.
- Event-driven: triggers on push, PR, schedule, manual dispatch, or external events.
- Jobs run on runners (GitHub-hosted or self-hosted); steps execute shell commands or reusable actions.

# Architecture

```text
GitHub Event (push, PR, schedule, dispatch)
       │
       ▼
┌─────────────────────────────────┐
│  .github/workflows/ci.yml      │
│  (Workflow)                     │
│                                 │
│  ┌────────────┐  ┌───────────┐  │
│  │  Job: build │  │ Job: test │  │
│  │  runs-on:   │  │ needs:    │  │
│  │  ubuntu     │  │  [build]  │  │
│  │            │  │           │  │
│  │ Step 1     │  │ Step 1    │  │
│  │  checkout  │  │  checkout │  │
│  │ Step 2     │  │ Step 2    │  │
│  │  build     │  │  test     │  │
│  └────────────┘  └───────────┘  │
└─────────────────────────────────┘
       │
       ▼
┌──────────────────┐
│  Runner (VM)     │
│  ubuntu-latest   │
│  windows-latest  │
│  self-hosted     │
└──────────────────┘
```

# Mental Model

```text
Event → Workflow → Job(s) → Step(s) → Action or shell command

1. Event fires (push to main)
2. GitHub finds matching workflow files (on: push)
3. Jobs start on runners (parallel unless `needs:` creates dependency)
4. Steps run sequentially within a job
5. Each step either runs a shell command or uses a reusable action
```

# Core Building Blocks

### Workflow, Jobs, Steps, and Triggers

- **Workflow**: YAML file in `.github/workflows/`; triggered by events (`on:` key).
- **Job**: set of steps on one runner; parallel by default, `needs:` creates ordering.
- **Step**: single task — `run:` (shell) or `uses:` (reusable action).
- **Runner**: VM (GitHub-hosted or self-hosted) that executes jobs.

Related notes: [001-github-actions-overview](./001-github-actions-overview.md) for detailed explanations, [002-workflow-syntax](./002-workflow-syntax.md) for trigger syntax and matrix

### Secrets and Security

- **Secret**: Encrypted variable stored in repo/org Settings; `${{ secrets.NAME }}`; masked in logs.
- **GITHUB_TOKEN**: Auto-injected per run; scope with `permissions:` block.
- **Environment**: Named target (staging, prod) with protection rules and env-specific secrets.
- GITHUB_TOKEN is auto-injected per run; scope with `permissions:`
- Secrets are masked in logs; never echo them

Related notes: [004-secrets-cache](./004-secrets-cache.md)

### Cache and Artifacts

- **Cache** (`actions/cache`): Save/restore directories by key; use lockfile hash for invalidation.
- **Artifact**: Files uploaded/downloaded between jobs or runs (`actions/upload-artifact`, `actions/download-artifact`).
- Cache key should include lockfile hash for deterministic invalidation

Related notes: [004-secrets-cache](./004-secrets-cache.md)

### Expressions and Contexts

- **${{ }}**: Expression syntax for dynamic values in YAML (env, if, run).
- **Contexts**: `github`, `env`, `secrets`, `job`, `steps`, `matrix`, `needs` — provide runtime data.
- **Outputs**: Pass values between steps (`$GITHUB_OUTPUT`) and jobs (`needs.<job>.outputs`).

Related notes: [003-expressions-contexts](./003-expressions-contexts.md)

### Reuse Patterns

- **Reusable workflows**: Call a workflow from another via `workflow_call`; pass inputs and secrets.
- **Composite actions**: Bundle multiple steps into one reusable action (`action.yml` with `runs: using: composite`).
- `act` tool lets you run workflows locally via Docker
- Reusable workflows use `workflow_call`; composite actions use `action.yml`

Related notes: [006-reusable-workflows-debugging](./006-reusable-workflows-debugging.md)
# Topic Map

- [001-github-actions-overview](./001-github-actions-overview.md) — Workflows, jobs, steps, triggers, common patterns
- [002-workflow-syntax](./002-workflow-syntax.md) — Trigger syntax, matrix, needs, concurrency
- [003-expressions-contexts](./003-expressions-contexts.md) — Expressions, contexts, outputs, hashFiles
- [004-secrets-cache](./004-secrets-cache.md) — Secrets, GITHUB_TOKEN, cache, artifacts, environments
- [005-real-world-examples](./005-real-world-examples.md) — Node.js, Docker, deploy, matrix examples
- [006-reusable-workflows-debugging](./006-reusable-workflows-debugging.md) — Reusable workflows, composite actions, debugging
- [007-security-oidc](./007-security-oidc.md) — OIDC cloud auth, permissions hardening, supply chain, fork safety
- [008-self-hosted-runners](./008-self-hosted-runners.md) — Self-hosted runners, labels, groups, security, auto-scaling
