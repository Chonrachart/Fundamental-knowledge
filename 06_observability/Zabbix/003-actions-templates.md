# Actions and Templates

- Actions automate responses to trigger events through conditional operations, escalation steps, and recovery handlers.
- Templates package items, triggers, graphs, and discovery rules into reusable units that are linked to hosts.
- Macros and low-level discovery make templates flexible enough to handle diverse hosts with a single configuration.

# Architecture

```text
Action Processing Pipeline:

+---------+     +------------+     +------------+     +----------------+
| Trigger |---->| Condition  |---->| Operation  |---->| Media /        |
| fires   |     | Evaluator  |     | Executor   |     | Remote Command |
| (PROBLEM|     |            |     |            |     |                |
|  state) |     | - severity |     | Step 1:    |     | - Email        |
+---------+     | - host grp |     |   notify   |     | - Slack        |
                | - tags     |     | Step 2:    |     | - Webhook      |
                | - time     |     |   escalate |     | - Script       |
                +-----+------+     | Step 3:    |     +----------------+
                      |            |   command  |
                      | no match   +------+-----+
                      v                   |
                   [skip]                 v
                                  +-------------+
                                  | Recovery /   |
                                  | Update ops   |
                                  | (on resolve) |
                                  +-------------+
```

# Mental Model

```text
Template design workflow:

  [1] Define items         -->  what to collect (keys, types, intervals)
  [2] Define triggers      -->  what conditions are problems (expressions, severity)
  [3] Add macros           -->  make thresholds configurable ({$CPU_THRESHOLD})
  [4] Add discovery rules  -->  auto-create items for dynamic entities (disks, NICs)
  [5] Link to hosts        -->  hosts inherit everything; override macros per host
```

```text
Example -- escalation for a database alert:

  Action: "DB Critical Alert"
  Conditions: severity >= High AND host group = "Databases"

  Step 1 (0 min):   Send Slack to #db-ops
  Step 2 (15 min):  Send email to DBA team (if not acknowledged)
  Step 3 (30 min):  Send SMS to on-call DBA (if not resolved)
  Recovery:         Send Slack "Resolved" to #db-ops
```

# Core Building Blocks

### Action

- Triggered by a state change: PROBLEM (trigger fires), OK (trigger recovers), or internal events.
- **Conditions** filter which events activate the action: trigger severity, host group, host, template, tag, time period.
- All conditions must match (AND logic by default; can switch to custom formula with AND/OR).
- Each action has three operation sections: Operations, Recovery operations, Update operations.

Related notes: [001-zabbix-overview](./001-zabbix-overview.md), [002-items-triggers](./002-items-triggers.md)

### Operation Types

- **Send message**: Notify user groups via media type (email, Slack, webhook, SMS, custom script).
- **Remote command**: Execute a command on the host (via agent) or on the Zabbix server (e.g. restart a service).
- **Add to host group** / **Remove from host group**: Dynamically change host group membership.
- Message templates support macros: `{HOST.NAME}`, `{TRIGGER.NAME}`, `{EVENT.SEVERITY}`, `{ITEM.LASTVALUE}`.

Related notes: [001-zabbix-overview](./001-zabbix-overview.md)

### Escalation

- Operations run in numbered steps; each step has a time delay from the previous.
- Step 1 at 0 minutes (immediate), Step 2 at N minutes, Step 3 at M minutes.
- Escalation continues only if the problem is not acknowledged or not resolved (configurable).
- Each step can target different user groups or media types (L1 -> L2 -> management).

Related notes: [002-items-triggers](./002-items-triggers.md)

### Template

- A container of items, triggers, graphs, dashboards, discovery rules, and web scenarios.
- **Link** a template to a host: all template objects are applied to the host instantly.
- **Unlink**: Detach template but keep objects on the host. **Unlink and clear**: Remove all inherited objects.
- **Template hierarchy**: A template can link to another template; the host inherits the full chain.
- Standard templates exist for OS (Linux, Windows), applications (MySQL, Nginx, Docker), and devices (Cisco, MikroTik).

Related notes: [001-zabbix-overview](./001-zabbix-overview.md), [004-monitoring-patterns](./004-monitoring-patterns.md)

### Macro

- Template-level variable: `{$MACRO_NAME}`; used in item keys, trigger expressions, intervals.
- Example: `{$CPU_THRESHOLD}` = 80; trigger expression: `avg(/host/system.cpu.util,5m) > {$CPU_THRESHOLD}`.
- **Override hierarchy**: Global macro -> Template macro -> Host macro (most specific wins).
- Allows one template to serve many hosts with different thresholds without duplication.

Related notes: [004-monitoring-patterns](./004-monitoring-patterns.md)

### Low-Level Discovery (LLD)

- Discovery rule returns JSON with macro names and values (e.g. `{#FSNAME}`, `{#IFNAME}`).
- **Item prototypes** and **trigger prototypes** use discovery macros; Zabbix creates real objects per discovered entity.
- Key example: `vfs.fs.discovery` returns all filesystems; item prototype `vfs.fs.size[{#FSNAME},pfree]` creates one item per filesystem.
- **Lifetime**: Discovered objects are removed when the entity is no longer returned by the discovery rule.

Related notes: [004-monitoring-patterns](./004-monitoring-patterns.md)

---

# Troubleshooting Flow (Quick)

```text
Problem: action not sending notifications
    |
    v
[1] Is the action enabled?
    Configuration > Actions -- check status column
    |
    +-- disabled --> enable the action
    |
    v
[2] Do conditions match the trigger event?
    Check: severity, host group, tags, time period
    |
    +-- mismatch --> adjust conditions or create new action
    |
    v
[3] Is the media type configured and working?
    Administration > Media types -- test the media type
    |
    +-- test fails --> check webhook URL / SMTP settings / credentials
    |
    v
[4] Does the user have media configured?
    Administration > Users > Media tab
    |
    +-- no media --> add email/Slack/webhook to user profile
    |
    v
[5] Check action log for errors
    Reports > Action log -- shows sent/failed per event
    /var/log/zabbix/zabbix_server.log -- detailed errors
```

# Quick Facts (Revision)

- Action = conditions + operations; fires on trigger state change (PROBLEM, OK, or update).
- Operations: send message, run remote command, change host group; executed in escalation steps.
- Escalation steps run at timed intervals; stop when acknowledged or resolved (configurable).
- Template = reusable bundle of items, triggers, graphs, discovery rules; link to hosts to apply.
- Macro `{$NAME}` provides host-level overrides for template thresholds and parameters.
- Override priority: host macro > template macro > global macro.
- LLD auto-creates monitoring objects from discovered entities (filesystems, interfaces, services).
- Unlink removes the template association; unlink-and-clear also deletes inherited objects from the host.

Related notes: [../000-core](../000-core.md), [001-zabbix-overview](./001-zabbix-overview.md), [002-items-triggers](./002-items-triggers.md), [004-monitoring-patterns](./004-monitoring-patterns.md), [../Grafana/001-grafana-overview](../Grafana/001-grafana-overview.md)
