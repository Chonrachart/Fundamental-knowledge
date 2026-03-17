# Monitoring Patterns

- Zabbix supports multiple data collection patterns: agent-based, SNMP, HTTP, and script-based; choosing the right one depends on the target and environment.
- Passive and active agent modes solve different network topology problems; dependent items and preprocessing reduce polling overhead.
- Trigger dependencies and LLD handle scale by suppressing alert cascades and auto-discovering dynamic entities.

# Architecture

```text
Data Collection Patterns:

+-------------------+         +-------------------+
| Passive Agent     |         | Active Agent      |
| (server -> agent) |         | (agent -> server) |
|                   |         |                   |
| Server:10051      |         | Agent connects    |
|   asks agent      |         |   to Server:10051 |
|   on port 10050   |         |   pushes results  |
+-------------------+         +-------------------+

+-------------------+         +-------------------+
| SNMP Polling      |         | HTTP Agent        |
| (server -> device)|         | (server -> URL)   |
|                   |         |                   |
| GET OID via       |         | HTTP GET/POST     |
| UDP 161           |         | parse response    |
+-------------------+         +-------------------+

+-------------------+         +-------------------+
| Dependent Item    |         | Trapper           |
| (no poll)         |         | (external push)   |
|                   |         |                   |
| Master item       |         | zabbix_sender     |
| collects once;    |         | pushes data to    |
| dependents parse  |         | Server:10051      |
+-------------------+         +-------------------+
```

# Mental Model

```text
Monitoring pattern decision tree:

  What are you monitoring?
      |
      +-- OS / application on a server
      |       |
      |       +-- Can install agent? --> YES --> Agent (active or passive)
      |       |                         NO  --> SSH / script / HTTP
      |       |
      |       +-- Behind NAT/firewall? --> YES --> Active agent
      |                                   NO  --> Passive agent (default)
      |
      +-- Network device (switch, router, firewall)
      |       |
      |       +-- SNMP supported? --> YES --> SNMP polling (v2c/v3)
      |                              NO  --> HTTP API / SSH
      |
      +-- Web service / API endpoint
      |       |
      |       +-- HTTP agent (check URL, parse JSON response)
      |
      +-- Custom / structured data
              |
              +-- One call returns multiple values?
                      |
                      +-- YES --> Master item + dependent items
                      +-- NO  --> Standard item per metric
```

```text
Example -- hybrid monitoring for a web stack:

  [Agent]      Linux servers   -->  CPU, memory, disk, processes
  [SNMP]       Network switch  -->  interface traffic, errors, status
  [HTTP]       API health      -->  GET /health, check status 200
  [Dependent]  App metrics     -->  one script returns JSON,
                                    dependent items extract each field
```

# Core Building Blocks

### Agent vs Agentless

- **Agent (Zabbix agent/agent2)**: Installed on the host; rich built-in keys for OS metrics (CPU, memory, disk, network, processes); supports custom UserParameters.
- **Agentless**: No software on the target; use SNMP (network devices), IPMI (hardware), HTTP (APIs), SSH (remote commands), JMX (Java apps).
- **Hybrid approach**: Agent for servers where install is possible; SNMP for network gear; HTTP for cloud APIs and SaaS endpoints.
- Choose agent when you need deep OS/application metrics; choose agentless when agent installation is not feasible or when the protocol provides what you need.

Related notes: [001-zabbix-overview](./001-zabbix-overview.md), [002-items-triggers](./002-items-triggers.md)

### Passive vs Active Agent

- **Passive mode**: Server initiates connection to agent port 10050; server sends key name; agent returns value.
- **Active mode**: Agent initiates connection to server port 10051; agent requests its check list; agent collects and pushes results.
- Active mode advantages: works behind NAT/firewall (no inbound port needed on host); scales better (agent does scheduling); supports log monitoring.
- Passive mode advantages: simpler setup; server controls timing; easier to debug with `zabbix_get`.
- Configure in agent config: `ServerActive=` for active checks; `Server=` for passive checks; can use both simultaneously.

Related notes: [001-zabbix-overview](./001-zabbix-overview.md)

### Low-Level Discovery (LLD)

- Discovery rule runs a key (e.g. `vfs.fs.discovery`) that returns JSON with macros: `{#FSNAME}`, `{#FSTYPE}`.
- **Item prototypes** use discovery macros in the key: `vfs.fs.size[{#FSNAME},pfree]` -- one real item created per filesystem.
- **Trigger prototypes** use discovery macros in the expression: fire per discovered entity.
- **Lifetime**: Controls how long discovered objects persist after the entity disappears (default 30d).
- Common use cases: filesystems, network interfaces, Docker containers, database tables, Kubernetes pods.

Related notes: [003-actions-templates](./003-actions-templates.md)

### Dependent Items

- **Master item**: Performs the actual data collection (e.g. a script that returns JSON with multiple metrics).
- **Dependent item**: References the master item; applies preprocessing to extract its specific value.
- One poll, many metrics: reduces agent load and network traffic.
- Example: master item runs a script returning `{"cpu":45,"mem":60,"disk":72}`; three dependent items use JSONPath `$.cpu`, `$.mem`, `$.disk`.

Related notes: [002-items-triggers](./002-items-triggers.md)

### Preprocessing

- **Steps** applied to item value before storage: JSONPath, regex, XML XPath, JavaScript, custom multiplier, change per second.
- **JSONPath**: Extract a field from JSON; e.g. `$.data.cpu_usage` from an API response.
- **Regex**: Match and extract with capture groups; e.g. `Temperature: (\d+)` to extract the number.
- **Discard unchanged (with heartbeat)**: Store value only when it changes or every N seconds; reduces storage and prevents trigger flapping.
- Steps are chained: output of step 1 becomes input of step 2.

Related notes: [002-items-triggers](./002-items-triggers.md)

### Trigger Dependencies

- Trigger A depends on Trigger B: if B is in PROBLEM state, A is suppressed (not evaluated).
- Prevents alert floods: when "Host unreachable" fires, all other triggers on that host are suppressed.
- Cascade pattern: Host down -> Service down -> Application error; only the root cause fires.
- Dependency is configured on the trigger object; a trigger can have multiple dependencies.

Related notes: [002-items-triggers](./002-items-triggers.md), [003-actions-templates](./003-actions-templates.md)

---

# Practical Command Set (Core)

```bash
# test passive agent key
zabbix_get -s 10.0.1.10 -k system.cpu.util

# send a value via trapper (external push)
zabbix_sender -z zabbix-server -s "web-server-01" -k custom.metric -o 42

# test SNMP connectivity
snmpwalk -v2c -c public 10.0.1.1 .1.3.6.1.2.1.2.2.1.2

# check agent configuration (active vs passive)
grep -E '^Server=|^ServerActive=' /etc/zabbix/zabbix_agent2.conf

# list agent supported keys
zabbix_agent2 -p

# test a UserParameter on the agent
zabbix_agent2 -t custom.script.key
```

# Troubleshooting Guide

```text
Problem: data collection not working for a specific pattern
    |
    v
[1] Which collection method is configured?
    Check item type in Configuration > Hosts > Items
    |
    +-- Agent (passive) --> can server reach agent port 10050?
    |       zabbix_get -s <host> -k <key>
    |
    +-- Agent (active) --> is agent connecting to server port 10051?
    |       check agent log: /var/log/zabbix/zabbix_agent2.log
    |       verify ServerActive= in agent config
    |
    +-- SNMP --> can server reach device on UDP 161?
    |       snmpget -v2c -c <community> <host> <oid>
    |
    +-- HTTP --> does the URL respond?
    |       curl -v <url>
    |
    v
[2] Is the item in "Not supported" state?
    Check item info column in Latest data
    |
    +-- key error --> fix key name or parameters
    +-- preprocessing error --> check preprocessing steps
    |
    v
[3] For dependent items: is the master item collecting?
    Check master item value in Latest data
    |
    +-- no data --> fix master item first
    +-- data present --> check preprocessing (JSONPath, regex)
    |
    v
[4] For LLD: are prototypes creating items?
    Configuration > Hosts > Discovery rules -- check discovered items
    |
    +-- no items --> discovery rule not returning data; test key manually
```

# Quick Facts (Revision)

- Agent = install on host, rich OS metrics; Agentless = SNMP, HTTP, SSH, IPMI, JMX for devices and services.
- Passive agent: server asks on port 10050; Active agent: agent pushes to server on port 10051.
- Use active mode for hosts behind NAT, large-scale deployments, and log monitoring.
- LLD auto-discovers entities and creates items/triggers from prototypes; lifetime controls cleanup.
- Dependent items reduce polling: one master item, many derived metrics via preprocessing.
- Preprocessing chain: JSONPath, regex, JavaScript, discard unchanged; steps execute in order.
- Trigger dependencies suppress child triggers when a parent is in PROBLEM state; prevents alert storms.
- Hybrid approach is common: agent for servers, SNMP for network, HTTP for APIs.

Related notes: [../000-core](../000-core.md), [001-zabbix-overview](./001-zabbix-overview.md), [002-items-triggers](./002-items-triggers.md), [003-actions-templates](./003-actions-templates.md), [../Grafana/001-grafana-overview](../Grafana/001-grafana-overview.md)
