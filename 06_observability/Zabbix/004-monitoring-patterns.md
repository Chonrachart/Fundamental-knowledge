monitoring pattern
agent
agentless
active
passive
low-level discovery
dependent item
preprocessing
trigger dependency

---

# Agent vs Agentless

- **Agent** (Zabbix agent): Installed on host; **passive** (server asks) or **active** (agent pushes to server); low overhead; many built-in keys (CPU, disk, net, custom).
- **Agentless**: **SNMP** (network devices), **IPMI** (hardware), **HTTP** (check URL), **SSH** (run command), **JMX** (Java); no agent install but often less granular or more overhead.
- **Hybrid**: Agent for OS/app; SNMP for network gear; HTTP for API health.

# Passive vs Active Agent

- **Passive**: Server connects to agent (default port 10050); server asks for key; agent returns value; **server** must reach **agent** (firewall).
- **Active**: Agent connects to server (port 10051); agent asks for **list of checks**; agent runs them and sends results; good when agent is behind NAT or firewall blocks inbound.
- **Active** reduces open ports on hosts; scale better when many agents.

# Low-Level Discovery (LLD)

- **Discovery rule**: Returns **JSON** with macro names and values (e.g. {#FSNAME}, {#FSTYPE}); Zabbix creates **items**, **triggers**, **graphs** from **item prototypes** and **trigger prototypes**.
- **Key**: e.g. `vfs.fs.discovery`; **Item prototype** key uses {#FSNAME}; **Trigger prototype** expression uses {#FSNAME}.
- Use for **filesystems**, **network interfaces**, **mount points**, **custom discovery** (script that outputs JSON).
- **Lifetime**: Discovered items/triggers are removed when host no longer returns that entity (e.g. disk removed).

# Dependent Items

- **Master item**: Item that does the “expensive” work (e.g. script that returns many values).
- **Dependent item**: No poll itself; **preprocessing** “Dependent item” with master item; parses master’s value (e.g. JSON path).
- Reduces agent load (one script run, many derived metrics); use for **custom scripts** that return structured data.

# Preprocessing

- **Steps**: JSONPath, regex, XML XPath, custom multiplier, threshold, etc.; **chain** multiple steps.
- **Dependent item** + **JSONPath** from master: e.g. master returns `{"cpu": 45, "mem": 60}`; dependent item **cpu** = JSONPath `$.cpu`.
- **Discard unchanged with heartbeat**: Reduce storage and trigger flapping; keep value only when changed or every N seconds.

# Trigger Dependencies

- **Trigger A depends on trigger B**: If B is in problem state, A is **not** evaluated (suppressed); when B recovers, A is evaluated again.
- Use when **B** = “Host unreachable” and **A** = “High CPU”; avoid hundreds of triggers firing when host is down.
- **Dependency** is on **trigger**, not item; set in trigger config “Depends on”.

# Summary

- Choose **agent** for rich OS/app metrics; **agentless** for devices or when agent not possible.
- Use **active** agents when scaling or when hosts are behind NAT.
- Use **LLD** for dynamic entities (disks, NICs); **dependent items** to parse one script into many metrics; **preprocessing** to transform and reduce noise.
- Use **trigger dependencies** to suppress cascades when a parent (e.g. host down) is in problem state.
