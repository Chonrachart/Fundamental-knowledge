# Fundamental-knowledge

Personal technical knowledge base — structured Markdown reference notes covering Linux, networking, containers, Kubernetes, CI/CD, infrastructure as code, cloud, and observability.

## Repository Structure

```
00_Foundations/
   01_Linux/                  Core OS, filesystem, process, disk, logs, services
      Networking/             Linux networking: interfaces, ip cmd, routing, sockets,
                              DNS resolution, firewall, namespaces, packet flow
   02_Shell_Script/           Bash scripting: variables, control flow, functions, patterns
   03_Networking/             OSI/TCP-IP models, physical/datalink/network layers
      REF-topic/              Extended ref: DHCP, DNS, HTTP/TLS, proxy, VPN, VXLAN
   04_Security/               Cryptography, auth, PKI, hardening, network security,
                              MFA, incident response, SIEM/EDR/XDR
   05_YAML_and_JSON/          Data and config format syntax, tools, validation
   06_Git_and_Github/         Git workflow, branching, PRs, tags, strategies
   07_Python/                 Variables, control flow, OOP, decorators, generators
   08_API_and_REST/           REST concepts, authentication, curl usage
   09_Database/               SQL, replication, HA, backup, monitoring, containers
   10_management/             LDAP and Active Directory

01_Containers/
   Docker/                    Images, containers, networking, volumes, Compose, security

02_Kubernetes/                Architecture, workloads, services, storage, RBAC, Helm
   work-specific/             Cluster-specific notes (cert-manager, etc.)

03_CI_CD/
   Concept/                   CI/CD lifecycle, pipeline design, deployment strategies,
                              testing, artifacts, environments, security, DORA metrics, GitOps
   Github_Action/             Workflows, actions, runners, secrets, reusable workflows
   Argo_CD/                   Applications, sync strategies, Rollouts, admin operations

04_Infrastructure_as_Code/
   Ansible/                   Playbooks, inventory, roles, vault, dynamic inventory
   Terraform/                 Providers, state, modules, workspaces

05_Cloud/
   AWS/                       Core services, IAM, networking, compute, storage

06_Observability/
   Prometheus/                Metrics, exporters, PromQL, Alertmanager
   Grafana/                   Dashboards, queries, alerting
   Logging/                   Logging overview, Loki, LogQL
   Tracing/                   Tempo, TraceQL
   Alloy/                     Grafana Alloy collector
   OpenTelemetry/             OTel overview
   Kafka/                     Kafka overview
   Zabbix/                    Items, triggers, actions, templates, monitoring patterns
   wazuh/                     Wazuh security monitoring

Ref/                          Mirror of main structure — original reference notes
```

## Reading Order

The numeric prefixes enforce a learning path — each section builds on the previous:

```
Foundations (Linux, Shell, Networking, Security, Git, Python, API, Database)
    -> Containers (Docker)
        -> Kubernetes
            -> CI/CD (Concepts, GitHub Actions, ArgoCD)
                -> Infrastructure as Code (Ansible, Terraform)
                    -> Cloud (AWS)
                        -> Observability (Prometheus, Grafana, Loki, Tempo, Alloy, Zabbix, Wazuh)
```
