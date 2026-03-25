# Items and Triggers

- Items define what data to collect, how to collect it, and how often; they are the foundation of all monitoring in Zabbix.
- Triggers evaluate item data against expressions and fire at a severity level when a condition is met.
- Together, items and triggers convert raw metrics into actionable problems that drive alerts and automation.

# Architecture

```text
Item Collection and Trigger Evaluation Flow:

+----------+     +----------------+     +-------------+     +-----------+
| Data     |---->| Item           |---->| Preprocessing|---->| History   |
| Source   |     | (key+interval) |     | Pipeline     |     | / Trends  |
| (agent,  |     +----------------+     +-------------+     +-----+-----+
|  SNMP,   |                                                       |
|  HTTP)   |                                                       v
+----------+                                               +--------------+
                                                           | Trigger      |
                                                           | Expression   |
                                                           | Evaluator    |
                                                           +------+-------+
                                                                  |
                                          +----------+------------+----------+
                                          |          |                       |
                                          v          v                       v
                                       [OK]    [PROBLEM]               [UNKNOWN]
                                                  |
                                                  v
                                           Action Engine
                                           (notify / run)
```

# Mental Model

```text
Building a trigger expression:

  [1] Select function     -->  last(), avg(), min(), max(), nodata()
  [2] Set period           -->  time window: 5m, 1h, #3 (last 3 values)
  [3] Set threshold        -->  comparison: > 80, = 0, <> "running"
  [4] Set severity         -->  Warning, Average, High, Disaster
  [5] (Optional) Recovery  -->  separate expression or auto (expression false)
```

```text
Example -- CPU trigger:

  Expression:  avg(/web-server-01/system.cpu.util,5m) > 80
               |       |               |            |    |
               func    host            item key     period threshold

  Reads as: "Fire when average CPU utilization over 5 minutes exceeds 80%"
  Severity: High
  Recovery: avg(/web-server-01/system.cpu.util,5m) < 70
```

# Core Building Blocks

### Item Types

- **Zabbix agent (passive)**: Server connects to agent port 10050 and requests a key; agent returns the value.
- **Zabbix agent (active)**: Agent connects to server port 10051, retrieves its check list, collects data, and pushes results.
- **SNMP**: Polls an OID on network devices (switches, routers, firewalls); supports SNMPv1/v2c/v3.
- **HTTP agent**: Makes HTTP/HTTPS requests; collects response body, status code, response time.
- **Script**: Runs a script on server or agent; parses output as the item value.
- **Calculated**: Formula combining other item values (e.g. percentage from two items).
- **External check**: Script executed by the server; for hosts where no agent or SNMP is available.
- **Dependent**: Does not poll; takes its value from a master item and applies preprocessing.

Related notes: [004-monitoring-patterns](./004-monitoring-patterns.md)

### Key Format

- Item key is the identifier for what to collect: `system.cpu.util`, `vfs.fs.size[/,pfree]`.
- Parameters go in square brackets: `net.tcp.port[,80]` checks if TCP port 80 is open.
- Templates define standard keys; custom keys follow the same `name[param1,param2]` format.

Related notes: [001-zabbix-overview](./001-zabbix-overview.md)

### Interval and History

- **Update interval**: How often the item collects data (e.g. 30s, 1m, 5m).
- **History**: Retention period for raw values (e.g. 7d, 30d); stores every collected value.
- **Trends**: Aggregated data (min, max, avg per hour); kept longer than history (e.g. 365d).
- **Flexible intervals**: Different collection rates for different time windows (e.g. every 10s during business hours, every 5m at night).

Related notes: [001-zabbix-overview](./001-zabbix-overview.md)

### Trigger Expression Functions

- **last()**: Most recent value; `last(/host/key) > 100`.
- **avg()**: Average over a period; `avg(/host/key,5m) > 80`.
- **min()** / **max()**: Minimum or maximum over a period.
- **nodata()**: True if no data received within a period; `nodata(/host/key,5m) = 1`.
- **change()**: Difference between last and previous value.
- **diff()**: Returns 1 if the last value differs from the previous.
- Combine with logical operators: `and`, `or`; group with parentheses.

Related notes: [003-actions-templates](./003-actions-templates.md)

### Severity Levels

```text
Level           Color      Typical Use
------          ------     ----------------
Not classified  grey       informational, no action
Information     blue       events of note (service restart)
Warning         yellow     approaching limit (disk 80%)
Average         orange     moderate impact (service degraded)
High            red-orange significant impact (service down)
Disaster        red        critical (host unreachable, data loss)
```

- Severity drives action filtering, escalation priority, and dashboard coloring.
- Choose severity based on business impact, not technical metric value.

Related notes: [003-actions-templates](./003-actions-templates.md)

### Trigger Dependencies

- Trigger A depends on trigger B: if B is in PROBLEM state, A is suppressed (not evaluated).
- Prevents alert floods when a parent condition (e.g. host unreachable) causes many child triggers to fire.
- Dependency is on the trigger object, not on the item; configured in the trigger settings.

Related notes: [004-monitoring-patterns](./004-monitoring-patterns.md)

---

# Troubleshooting Guide

### Item shows "Not supported" or no data

1. Is the item key valid on the agent? `zabbix_get -s <host-ip> -k <item-key>` -- "ZBX_NOTSUPPORTED" --> key does not exist or wrong parameters; timeout --> agent unreachable (check network / firewall).
2. Check item configuration in frontend. Is the key spelled correctly? Is the type correct (agent vs SNMP vs HTTP)? Is the host interface configured for this type?
3. Is preprocessing failing? Administration > Queue -- check if item is queued. Check item "Info" column for preprocessing errors.
4. For triggers not firing: check expression syntax in trigger config; verify item is collecting expected values (Latest data); check trigger dependencies -- is a parent trigger suppressing it?
5. Check logs for detailed errors: `/var/log/zabbix/zabbix_server.log` and `/var/log/zabbix/zabbix_agent2.log`.
