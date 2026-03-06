action
operation
condition
escalation
template
macro
discovery

---

# Action

- React to trigger state change (Problem, OK); **conditions** filter when action runs.
- **Operations**: Steps to run (send message, run remote command, add to group, etc.).
- **Recovery** and **Update** operations: Run when trigger recovers or when severity/ack changes.
- **Conditions**: Trigger severity, host group, host, template, tag, time; all must match.

# Operation

- **Send message**: To user groups (media: email, Slack, webhook); use message template with macros.
- **Remote command**: Run on host (via agent) or on Zabbix server; e.g. restart service.
- **Add host to group**, **Remove from group**: Change host group.
- **Notify** (in newer versions): Rich notifications with event details.
- **Escalation**: Next step after N minutes if not acknowledged or not resolved.

# Escalation

- **Escalation steps**: Step 1 at 0m (notify L1), Step 2 at 5m (notify L2), etc.
- **Conditions**: Only escalate if not acknowledged, or if severity is High/Disaster.
- **Recovery**: Optional operations when trigger recovers at each step.

# Template

- Set of items, triggers, graphs, dashboards, discovery rules; link to hosts.
- **Link** template to host; host gets all template objects; **Unlink** removes them.
- **Template hierarchy**: Template can link another template; host inherits from chain.
- Use for OS (Linux, Windows), apps (MySQL, Nginx), devices; customize with macros.

# Macro

- Variable in template: `{$MACRO}`; override at host or template level.
- Example: `{$PG_PORT}` = 5432; use in item key or trigger name.
- **User macro** on host: Override template macro for that host.

# Discovery

- **Low-level discovery (LLD)**: Rule returns list (e.g. filesystems, network interfaces); prototype items/triggers/graphs create objects per discovered entity.
- Use for dynamic hosts (many filesystems, many NICs) without defining each item by hand.
