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

### Workflow and Triggers

- **Workflow**: YAML file in `.github/workflows/`; triggered by events.
- **Triggers** (`on:`): push, pull_request, schedule, workflow_dispatch, workflow_call, repository_dispatch.
- Filters: branches, tags, paths, paths-ignore.

Related notes: [001-github-actions-overview](./001-github-actions-overview.md), [002-workflow-syntax](./002-workflow-syntax.md)

### Jobs and Steps

- **Job**: Set of steps on one runner; jobs can depend on each other via `needs:`.
- **Step**: Single task — `run:` (shell command) or `uses:` (reusable action).
- **Runner**: VM that executes jobs; GitHub-hosted (ubuntu-latest, windows-latest) or self-hosted.
- **Matrix**: Run job with multiple parameter combinations (e.g. node version, OS).

Related notes: [002-workflow-syntax](./002-workflow-syntax.md), [005-real-world-examples](./005-real-world-examples.md)

### Secrets and Security

- **Secret**: Encrypted variable stored in repo/org Settings; `${{ secrets.NAME }}`; masked in logs.
- **GITHUB_TOKEN**: Auto-injected per run; scope with `permissions:` block.
- **Environment**: Named target (staging, prod) with protection rules and env-specific secrets.

Related notes: [004-secrets-cache](./004-secrets-cache.md)

### Cache and Artifacts

- **Cache** (`actions/cache`): Save/restore directories by key; use lockfile hash for invalidation.
- **Artifact**: Files uploaded/downloaded between jobs or runs (`actions/upload-artifact`, `actions/download-artifact`).

Related notes: [004-secrets-cache](./004-secrets-cache.md)

### Expressions and Contexts

- **${{ }}**: Expression syntax for dynamic values in YAML (env, if, run).
- **Contexts**: `github`, `env`, `secrets`, `job`, `steps`, `matrix`, `needs` — provide runtime data.
- **Outputs**: Pass values between steps (`$GITHUB_OUTPUT`) and jobs (`needs.<job>.outputs`).

Related notes: [003-expressions-contexts](./003-expressions-contexts.md)

### Reuse Patterns

- **Reusable workflows**: Call a workflow from another via `workflow_call`; pass inputs and secrets.
- **Composite actions**: Bundle multiple steps into one reusable action (`action.yml` with `runs: using: composite`).

Related notes: [006-reusable-workflows-debugging](./006-reusable-workflows-debugging.md)

---

# Troubleshooting Guide

### Workflow not triggering
1. Check `on:` event matches what happened (push vs pull_request, correct branch).
2. Verify workflow file is on the **default branch** for schedule and workflow_dispatch triggers.
3. Check file path: must be `.github/workflows/*.yml` (not `.yaml` for older setups — both work now).
4. Check if workflow is disabled: Actions tab → select workflow → Enable.

### Job skipped unexpectedly
1. Check `if:` condition on the job — evaluate the expression manually.
2. Check `needs:` — if upstream job failed or was skipped, dependent jobs skip too.
3. For pull_request from forks: secrets are not available; steps using secrets may be skipped.

### Action version mismatch
1. Pin actions to major version (`@v4`) or commit SHA for stability.
2. Check action's changelog for breaking changes between versions.
3. Use Dependabot to track action updates.

---

# Quick Facts (Revision)

- Workflows live in `.github/workflows/` and are YAML files
- Jobs run in parallel by default; use `needs:` to create dependencies
- `GITHUB_TOKEN` is auto-injected per run; scope with `permissions:`
- Matrix strategy runs the same job with different parameter combinations
- Secrets are masked in logs; never echo them
- `act` tool lets you run workflows locally via Docker
- Reusable workflows use `workflow_call`; composite actions use `action.yml`
- Cache key should include lockfile hash for deterministic invalidation

# Topic Map

- [001-github-actions-overview](./001-github-actions-overview.md) — Workflows, jobs, steps, triggers, common patterns
- [002-workflow-syntax](./002-workflow-syntax.md) — Trigger syntax, matrix, needs, concurrency
- [003-expressions-contexts](./003-expressions-contexts.md) — Expressions, contexts, outputs, hashFiles
- [004-secrets-cache](./004-secrets-cache.md) — Secrets, GITHUB_TOKEN, cache, artifacts, environments
- [005-real-world-examples](./005-real-world-examples.md) — Node.js, Docker, deploy, matrix examples
- [006-reusable-workflows-debugging](./006-reusable-workflows-debugging.md) — Reusable workflows, composite actions, debugging
- [007-security-oidc](./007-security-oidc.md) — OIDC cloud auth, permissions hardening, supply chain, fork safety
- [008-self-hosted-runners](./008-self-hosted-runners.md) — Self-hosted runners, labels, groups, security, auto-scaling
