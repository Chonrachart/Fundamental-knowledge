# CLAUDE.md — Fundamental-knowledge

## Purpose

Personal technical knowledge base for a System Engineer.
The user writes all notes themselves for deeper understanding — Claude does NOT write note content.

## Note Writing Rules

- Claude must **NOT** create or write note content for the user
- Claude **CAN**: answer questions while the user is writing, review notes for accuracy/completeness when asked
- Claude **CAN**: help with structure, suggest topics to cover, point to `Ref/` for reference
- Claude must **NOT**: fill in placeholder sections or auto-generate note content

## Repository Layout

```
Ref/                           # Original reference notes (mirror of main structure)
00_Foundations/
  01_Linux/                  # Core OS, filesystem, process, networking
  02_Shell_Script/           # Bash scripting
  03_Networking/             # OSI, TCP/IP, HTTP, TLS, VPN
    004_DNS_Deep_Dive/       # Record types, service discovery, operations
  04_Security/               # Crypto, auth, PKI, hardening
  05_YAML_and_JSON/          # Data/config formats
  06_Git_and_Github/         # Version control
  07_Python/                 # Scripting and automation
  08_API_and_REST/           # REST concepts, auth, curl
  09_Database/               # SQL, replication, backup, containers
01_Containers/               # Docker
02_Kubernetes/
03_CI_CD/                    # Concepts + GitHub Actions + Argo CD
04_Infrastructure_as_Code/   # Ansible, Terraform
05_cloud/                    # AWS
06_observability/            # Prometheus, Grafana, Zabbix, Logging
```

Directories use a numeric prefix (`00_`, `01_`, …) to enforce reading order from fundamentals to specialised topics.

`Ref/` mirrors the full directory structure and contains the original pre-written reference notes. Main directories contain user-written notes (placeholder skeletons until rewritten). Images (`pic/` folders) remain in the main directories.

## Note Conventions

### File naming

- `00-core.md`  — topic entry point with overview + Topic Map
- `001-`, `002-`, … — 3 digit mean unrevise or read yet


### Style rules

- `Related notes:` uses relative Markdown links: `[note-name](./note-name.md)`
- Prefer bullet points over prose paragraphs
- Keep headings consistent: `#` for top-level section, `###` for subsection within a section

## What NOT to Include

- Verbose prose where bullets suffice
- Duplicate content already covered in a linked note
