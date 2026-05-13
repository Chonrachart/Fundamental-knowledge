# Issue Title Conventions

> Last updated: 2026-05-11 ICT (Asia/Bangkok)

This repo uses **title prefixes** (not Gitea labels) to signal issue type. Prefixes are visible at a glance in lists, in search results, and in commit messages that reference the issue — without needing labels to be set up or filtered.

## TL;DR

| Prefix | Use for | Closes on PR merge? |
|---|---|---|
| `[FEAT]` | New functionality / Application / capability | Yes |
| `[FIX]` | Bug or broken behavior | Yes |
| `[DOCS]` | Documentation-only change | Yes |
| `[CHORE]` | Maintenance, dep/chart bumps, repo housekeeping | Yes |
| `[INFO]` | Permanent reference entry / heads-up | **No — stays open** |

## When to use each

### `[FEAT]` — new capability

New ArgoCD Application, new chart adoption, new feature on an existing app, new manifest, new IRSA role, new S3 bucket, new umbrella rollout.

Examples:
- `[FEAT] keda — adopt event-driven autoscaling controller`
- `[FEAT] keycloak SSO — operator 26.4.2 + 2 HA instances AZ-spread` (#179)

### `[FIX]` — broken behavior

Something doesn't work as designed and needs fixing. Covers both "bug reports" (someone observed an issue) and "fix-this-thing tasks" (we already know what's wrong).

Examples:
- `[FIX] tempo OTLP receiver binds to localhost — external traces dropped` (#79)
- `[FIX] external-dns: regex filter missing TXT registry prefix coverage`

### `[DOCS]` — documentation only

Specs, plans, runbooks, README updates, architecture diagrams, this conventions doc.

Examples:
- `[DOCS] ArgoCD AppProject architecture diagram`
- `[DOCS] reconciliation behavior section — why config-only changes don't roll pods`

### `[CHORE]` — maintenance

Dependency or chart version bumps with no behavior change, tooling tweaks, cleanup of merged branches, repo housekeeping that isn't user-facing.

Examples:
- `[CHORE] bump cert-manager chart 1.18.2 → 1.19.0 (no value changes)`
- `[CHORE] prune stale [gone] local branches`

### `[INFO]` — permanent reference

Long-lived informational reference. **Does not auto-close.** Use when you want a permanent searchable knowledge entry — "this is intentionally fail-closed", "design preserved but not active here", "this error means X".

`[INFO]` issues should include a sentence at the top like *"This is a permanent reference entry. Do not close."* so the convention is explicit, not just folklore.

Examples:
- `[INFO] default AppProject is fail-closed — use lbr-eks-prd or lbr-argocd for new Applications` (#220)
- `[INFO] external-dns domainFilter tightening — preserved design for future cluster setup (not active in lbr-ees)` (#221)

## Choosing between `[FIX]` and `[FEAT]`

If the change **adds** something that wasn't there before → `[FEAT]`.
If the change **restores** expected behavior or stops something from breaking → `[FIX]`.

When unsure, pick `[FEAT]` — most chart adoptions look like fixes from outside but are new capabilities from the repo's perspective.

## Closing conventions

### Default: `Fixes #N`

For `[FEAT]`, `[FIX]`, `[DOCS]`, `[CHORE]` issues, the PR that does the work should use `Fixes #N` in the PR body. Gitea closes the issue automatically when the PR merges.

### Exception: explicit closing gate → `Refs #N`

If an issue has a checklist or explicit closing condition (e.g. *"close after Phase 2 verifies green in prod"*, *"close after umbrella's children all merge"*), use `Refs #N` instead of `Fixes #N` in the PR body **and in commit messages**.

Gitea's auto-close fires on `Fixes #N` regardless of the gate — using it on a gated issue closes the umbrella prematurely and breaks multi-PR / multi-phase workflows.

### `[INFO]` issues

Never use `Fixes #N` referring to an `[INFO]` issue. They are not work items; they are reference entries. If an `[INFO]` issue becomes outdated, edit the body or close it manually with an explanation — don't link it from a PR.

## Sub-tasks under an umbrella

Umbrella issues (e.g. #147 Grafana dashboard audit, #122 stateful AZ posture) stay `[FEAT]` even though their children may be `[FIX]`. The umbrella tracks the overall capability; the children track their individual changes with whatever prefix fits.

## Gitea labels

Five `type:` labels mirror the title prefixes, for filterable queries in the Gitea UI / API:

| Label | Color | Mirrors |
|---|---|---|
| `type:feat` | green (`#22c55e`) | `[FEAT]` |
| `type:fix` | red (`#ef4444`) | `[FIX]` |
| `type:docs` | blue (`#3b82f6`) | `[DOCS]` |
| `type:chore` | gray (`#6b7280`) | `[CHORE]` |
| `type:info` | amber (`#eab308`) | `[INFO]` |

**Apply both** the title prefix *and* the matching `type:` label when creating an issue or PR. They are not interchangeable:

- **Prefix** is visible in issue lists, commit messages, search results, and Gitea notifications — works without any label configuration on a fresh clone or external mirror.
- **Label** is filterable in the Gitea UI (`label:type:fix`) and queryable via API — works for tooling and dashboards.

Each carries the other's blind spot. Use both.

### No other label categories (for now)

Priority (`P0`/`P1`/`P2`), status (`blocked`/`in-progress`), and domain (`argocd`/`observability`/`security`) labels are **not** in use in this repo. Each extra category creates compliance overhead — pick the wrong one, leave it stale, or forget to apply it. Revisit only when there is concrete pain from not having them.

If you encounter labels like `P2` or `known-issue` on issues in sibling repos (e.g. `itarun.p/sit-kube-report`), those are that team's conventions, not ours. Do not import them.
