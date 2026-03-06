item
key
type
interval
trigger
expression
severity
recovery

---

# Item Types

- **Zabbix agent**: Passive (server asks) or active (agent pushes); metrics from host.
- **SNMP**: Poll SNMP OID; network devices, hardware.
- **HTTP**: Check URL; response time, status code.
- **Script**: Run script on server or agent; parse output.
- **Calculated**: Formula from other items.
- **External**: Script on server; custom collection.
- **Dependent**: Derive from master item; reduce polling.

# Key

- Identifier for item; e.g. `system.cpu.util`, `vfs.fs.size[/,pfree]`, `net.tcp.port[,80]`.
- Item key + parameters (in brackets) define what to collect.
- Templates define standard keys; copy or create custom keys.

# Interval and History

- **Update interval**: How often to collect (e.g. 30s, 1m).
- **History**: How long to keep raw values; **Trends**: Aggregated (min, max, avg) for long retention.
- Flexible intervals: different interval for different time periods.

# Trigger Expression

- Expression on item value(s); when true, trigger fires.
- **last()**, **avg()**, **min()**, **max()** over period; **nodata()** for no data.
- Example: `avg(/Linux CPU/system.cpu.util,5m)}>80` — CPU avg over 5m above 80%.
- **Recovery expression**: Optional; when true, trigger recovers (default: expression false).

# Severity

- Not classified, Information, Warning, Average, High, Disaster.
- Used for filtering and actions; escalation by severity.

# Dependencies

- Trigger can depend on another trigger; if parent fires, dependent is not evaluated (avoids flood when host down).
