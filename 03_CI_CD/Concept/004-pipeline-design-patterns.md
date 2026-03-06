pipeline design
stages
parallel
fan-out
fan-in
branch strategy
environment

---

# Pipeline Design — Stages

- **Stage** = logical group of steps (e.g. build, test, deploy); often one job per stage in GHA.
- Order: **checkout → build → test → (optional security/scan) → deploy**.
- Fail fast: put quick checks first (lint, unit); long e2e later or in parallel.
- **Gates**: Block next stage if current fails; in GHA use job **needs** so deploy job runs only after test passes.

# Parallel Jobs

- Run independent jobs in **parallel** (e.g. unit tests + lint + build on different OS) to save time.
- In GitHub Actions: multiple jobs at same level with no **needs** run in parallel.
- Use **matrix** to run same job with different configs (Node 18/20, Ubuntu/Windows) in parallel.

# Fan-Out and Fan-In

- **Fan-out**: One job triggers many (e.g. build once, then test-on-linux, test-on-windows, test-on-mac).
- **Fan-in**: Many jobs feed one (e.g. build-linux, build-windows both must succeed before deploy; deploy has needs: [build-linux, build-windows]).
- **needs** defines the DAG; fan-in = one job with multiple needs.

# Branch Strategy and Triggers

- **main/master**: Often protected; merge only via PR; CI runs on PR and on push.
- **Feature branches**: Run CI on push and on PR to main; usually do not deploy to prod from feature.
- **Environments**: Deploy staging from main (auto or on merge); deploy production from main with manual approval or from **release** branch / tag.
- Use **on.push.branches** and **on.pull_request.branches** and **if: github.ref** in jobs to control what runs where.

# Environment and Promotion

- **Environments** (e.g. staging, production): Often map to branch + approval; production may require manual approval or only from tags.
- **Promotion**: Build once (artifact or image tag), “promote” same artifact through staging then production (don’t rebuild for prod).
- Store artifact in registry or artifact store; deploy job pulls same tag in each env.

# Reusable and Callable Workflows

- **Reusable workflow**: One workflow can **call** another; caller passes inputs; callee runs in caller’s context (same repo or allowed repos).
- Use for shared “build and test” or “deploy” logic; reduce duplication.
- **Composite action**: Reuse a sequence of steps; good for “setup Node + cache + install” used in many jobs.

# Summary

- Design with **stages** and **gates**; use **needs** for ordering and fan-in.
- Use **parallel** and **matrix** for speed; **branch strategy** and **environments** for safe deploys.
- Prefer **build once, promote**; reuse workflows and actions to keep config DRY.
