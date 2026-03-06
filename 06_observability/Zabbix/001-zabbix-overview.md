Zabbix
host
item
trigger
action
template

---

# Zabbix

- Open-source monitoring solution; collect metrics, detect problems, alert.
- Agent-based or agentless (SNMP, IPMI, etc.); central server and optional proxy.

# Host

- Monitored entity (server, device); has interface (IP, port) and can be linked to templates.
- Groups organize hosts (e.g. Linux servers, network devices).

# Item

- Single metric to collect (e.g. CPU load, free disk, response time).
- Type: Zabbix agent, SNMP, HTTP, script, etc.; key and interval.

# Trigger

- Expression on item data; when true, trigger fires (e.g. "avg(5m) > 80" for CPU).
- Severity: Not classified, Info, Warning, Average, High, Disaster.
- Recover when expression becomes false.

# Action

- React to trigger: send notification (email, Slack, webhook), run remote command.
- Conditions (host group, trigger severity, time); operations (send message, execute script).

# Template

- Reusable set of items, triggers, graphs, dashboards; link to hosts.
- Use built-in or community templates (e.g. Linux, MySQL, Docker).

# Flow

```
Host → Items (collect) → Triggers (evaluate) → Actions (notify / run)
```
