# Zabbix Overview

- Zabbix is an open-source enterprise monitoring platform that collects metrics, detects problems, and sends alerts.
- Architecture follows a central server model with optional proxies for distributed environments; supports agent-based and agentless collection.
- Core workflow: hosts hold items that collect data, triggers evaluate conditions, and actions respond to problems.

# Architecture

```text
                         Remote Site
                     +----------------+
                     | Zabbix Proxy   |
                     |  (buffering)   |
                     +-------+--------+
                             |
  +----------+       +-------v--------+       +-----------+       +-----------+
  | Agent    |------>|                |       |           |       |           |
  | (10050)  |       |  Zabbix Server |------>| Database  |<------| Frontend  |
  +----------+       |   (10051)      |       | (PgSQL /  |       | (Web UI)  |
  +----------+       |                |<------| MySQL)    |       |           |
  | SNMP     |------>|                |       |           |       |           |
  | device   |       +-------+--------+       +-----------+       +-----------+
  +----------+               |
  +----------+               |
  | HTTP     |------>--------+
  | endpoint |
  +----------+

  Agents/devices -----> Server -----> Database -----> Frontend
  (collect)             (process)     (store)         (visualize)
```

# Mental Model

```text
Monitoring setup workflow:

  [1] Add host            -->  define IP/DNS, interface, host group
  [2] Link template       -->  host inherits items, triggers, graphs
  [3] Items collect       -->  agent/SNMP/HTTP gathers metrics on interval
  [4] Triggers evaluate   -->  expressions check thresholds on item data
  [5] Actions notify      -->  send alert or run command when trigger fires
```

```text
Example -- monitor a Linux server:

  Host: web-server-01 (10.0.1.10, agent port 10050)
    |
    +-- Link template: "Linux by Zabbix agent"
          |
          +-- Item: system.cpu.util  (every 30s)
          +-- Item: vm.memory.size[available]  (every 60s)
          +-- Trigger: avg(/host/system.cpu.util,5m) > 80
          +-- Action: send Slack message to #ops when trigger fires
```

# Core Building Blocks

### Host

- Monitored entity: physical server, VM, container, network device, or cloud resource.
- Has one or more interfaces: agent (IP + port 10050), SNMP, IPMI, JMX.
- Belongs to one or more host groups (e.g. "Linux servers", "Production").
- Hosts are linked to templates to receive monitoring configuration.

Related notes: [002-items-triggers](./002-items-triggers.md), [003-actions-templates](./003-actions-templates.md)

### Item

- Single metric to collect: CPU load, free disk, response time, custom script output.
- Defined by type (agent, SNMP, HTTP, calculated), key, and update interval.
- Collected values are stored as history (raw) and trends (aggregated).

Related notes: [002-items-triggers](./002-items-triggers.md)

### Trigger

- Boolean expression evaluated against item data; fires when expression becomes true.
- Severity levels: Not classified, Information, Warning, Average, High, Disaster.
- Recovers when expression becomes false (or when a separate recovery expression is true).

Related notes: [002-items-triggers](./002-items-triggers.md)

### Action

- Automated response to a trigger state change (Problem or OK).
- Conditions filter which triggers activate the action (host group, severity, tags, time period).
- Operations define what happens: send message, run remote command, add host to group.

Related notes: [003-actions-templates](./003-actions-templates.md)

### Template

- Reusable package of items, triggers, graphs, dashboards, and discovery rules.
- Link a template to a host; the host inherits all template objects instantly.
- Use built-in templates (Linux, Windows, MySQL, Docker) or create custom ones.
- Unlink to detach; unlink-and-clear removes all inherited objects.

Related notes: [003-actions-templates](./003-actions-templates.md)

---

# Practical Command Set (Core)

```bash
# check Zabbix server status
systemctl status zabbix-server

# check Zabbix agent status on monitored host
systemctl status zabbix-agent2

# test agent connectivity from server
zabbix_get -s 10.0.1.10 -k system.cpu.util

# check what keys an agent supports
zabbix_agentd -p

# tail Zabbix server log for errors
tail -f /var/log/zabbix/zabbix_server.log

# tail Zabbix agent log
tail -f /var/log/zabbix/zabbix_agent2.log

# check Zabbix server config
grep -v '^#\|^$' /etc/zabbix/zabbix_server.conf
```

# Troubleshooting Flow (Quick)

```text
Problem: host shows "Unavailable" in Zabbix frontend
    |
    v
[1] Is Zabbix agent running on the host?
    systemctl status zabbix-agent2
    |
    +-- not running --> start agent, check config (Server= directive)
    |
    v
[2] Can the server reach the agent port?
    nc -zv <host-ip> 10050
    |
    +-- timeout --> firewall blocking; check iptables / security group
    +-- refused --> agent not listening; check ListenPort config
    |
    v
[3] Does zabbix_get return data?
    zabbix_get -s <host-ip> -k agent.ping
    |
    +-- error --> check Server= in agent config (must include server IP)
    |
    v
[4] Check server and agent logs for detailed errors
    /var/log/zabbix/zabbix_server.log
    /var/log/zabbix/zabbix_agent2.log
```

# Quick Facts (Revision)

- Zabbix server listens on port 10051 (trapper); agent listens on port 10050 (passive checks).
- Host = monitored entity; must have at least one interface and belong to a host group.
- Item = single metric; defined by type + key + interval; stored as history and trends.
- Trigger = expression on item data; fires at a severity level; recovers when expression is false.
- Action = conditions + operations; runs when a trigger changes state.
- Template = reusable config bundle; link to host to apply, unlink to remove.
- Proxy = optional relay for remote sites; buffers data and forwards to server.
- Frontend connects to the database, not directly to the server process.

Related notes: [../000-core](../000-core.md), [002-items-triggers](./002-items-triggers.md), [003-actions-templates](./003-actions-templates.md), [004-monitoring-patterns](./004-monitoring-patterns.md), [../Grafana/001-grafana-overview](../Grafana/001-grafana-overview.md)
