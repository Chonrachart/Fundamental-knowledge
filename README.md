# Fundamental-knowledge

Personal technical knowledge base — structured Markdown reference notes covering Linux, networking, containers, Kubernetes, CI/CD, infrastructure as code, cloud, and observability.

## Repository Structure

```
00_Foundations/
   01_Linux/                  Core OS, filesystem, process, disk, logs, networking
   02_Shell_Script/           Bash scripting: variables, control flow, functions, patterns
   03_Networking/             OSI/TCP-IP models, HTTP/HTTPS, TLS, proxy, VPN
   04_DNS_Deep_Dive/          Record types, service discovery, DNS operations
   05_Security/               Cryptography, auth, PKI, hardening, network security
   06_YAML_and_JSON/          Data and config format syntax, tools, validation
   07_Git_and_Github/         Git workflow, branching, PRs, tags, strategies
   08_Python/                 Variables, control flow, OOP, decorators, generators
   09_API_and_REST/           REST concepts, authentication, curl usage
   10_Database/               SQL, replication, HA, backup, monitoring, containers

01_Containers/
   Docker/                    Images, containers, networking, volumes, Compose, security

02_Kubernetes/                Architecture, workloads, services, storage, RBAC, Helm

03_CI_CD/
   Concept/                   CI/CD lifecycle, pipeline design, deployment strategies,
                              testing, artifacts, environments, security, DORA metrics, GitOps
   Github_Action/             Workflows, actions, runners, secrets, reusable workflows
   Argo_CD/                   Applications, sync strategies, Rollouts, admin operations

04_Infrastructure_as_Code/
   Ansible/                   Playbooks, inventory, roles, vault, dynamic inventory
   Terraform/                 Providers, state, modules, workspaces

05_cloud/
   AWS/                       Core services, IAM, networking, compute, storage

06_observability/
   Prometheus/                Metrics, exporters, PromQL, Alertmanager
   Grafana/                   Dashboards, queries, alerting, PromQL deep dive
   Logging/                   Logging overview, Loki/Promtail, ELK basics
   Zabbix/                    Items, triggers, actions, templates, monitoring patterns
```

## Reading Order

The numeric prefixes enforce a learning path — each section builds on the previous:

```
Foundations (Linux, Shell, Networking, Security)
    -> Containers (Docker)
        -> Kubernetes
            -> CI/CD (Concepts, GitHub Actions, ArgoCD)
                -> Infrastructure as Code (Ansible, Terraform)
                    -> Cloud (AWS)
                        -> Observability (Prometheus, Grafana, Logging, Zabbix)
```
