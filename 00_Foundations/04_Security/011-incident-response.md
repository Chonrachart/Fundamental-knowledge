# Incident Response

- Incident response (IR) is the structured process of detecting, containing, and recovering from security incidents while preserving evidence.
- Follows a 6-phase lifecycle (NIST SP 800-61): Preparation → Detection → Containment → Eradication → Recovery → Lessons Learned.
- Speed matters for containment, but preserving evidence matters for understanding what happened and preventing recurrence.

# Architecture

```text
NIST Incident Response Lifecycle:

  ┌──────────────┐    ┌──────────────────┐    ┌──────────────┐
  │  Preparation │───▶│  Detection &     │───▶│ Containment  │
  │              │    │  Analysis        │    │              │
  │ Runbooks     │    │ Alerts, triage   │    │ Isolate,     │
  │ Tools ready  │    │ Severity rating  │    │ block, limit │
  │ Team trained │    │ Timeline build   │    │ blast radius │
  └──────────────┘    └──────────────────┘    └──────┬───────┘
                                                      │
  ┌──────────────┐    ┌──────────────────┐    ┌──────▼───────┐
  │  Lessons     │◀───│  Recovery        │◀───│ Eradication  │
  │  Learned     │    │                  │    │              │
  │ Post-mortem  │    │ Restore service  │    │ Remove root  │
  │ Action items │    │ Verify clean     │    │ cause, patch │
  │ Update docs  │    │ Monitor closely  │    │ Rebuild      │
  └──────────────┘    └──────────────────┘    └──────────────┘

  Evidence Preservation (throughout all phases):
  ┌──────────────────────────────────────────────────┐
  │  Volatile → Non-volatile collection order:       │
  │  Memory → Network → Disk → Logs → Config        │
  │  Document everything: who, what, when, actions   │
  └──────────────────────────────────────────────────┘
```

# Mental Model

```text
"Something looks wrong" — now what?

  Alert fires / user reports anomaly
       │
       ▼
  Triage: is this real? (false positive check)
       │
       ├── not real → document, tune alert, close
       │
       ▼
  Classify severity (how bad is it?)
       │
       ├── P1: active breach, data exfiltration → all hands
       ├── P2: compromised system, no spread yet → urgent
       ├── P3: suspicious activity, unconfirmed → investigate
       ├── P4: policy violation, low risk → scheduled
       │
       ▼
  Contain the blast radius (stop the bleeding)
  - Isolate the host / revoke credentials / block IPs
  - DO NOT wipe or reboot yet (evidence!)
       │
       ▼
  Investigate root cause (what happened, how, when)
  - Build timeline from logs
  - Determine scope: what else was affected?
       │
       ▼
  Eradicate and recover (clean up and restore)
       │
       ▼
  Post-mortem (what do we fix so this doesn't happen again?)
```

```bash
# quick triage commands on a suspect Linux host
# check who is logged in
w
who

# check recent auth events
journalctl -u sshd --since "1 hour ago" --no-pager

# check for unusual processes
ps auxf | head -50

# check network connections
ss -tulnp
ss -anp | grep ESTABLISHED

# check recent file modifications
find /tmp /var/tmp -mmin -60 -ls 2>/dev/null
```

# Core Building Blocks

### IR Phases Overview

| Phase | Goal | Key Actions |
|-------|------|-------------|
| Preparation | Be ready before incidents happen | Runbooks, tools, training, contact lists |
| Detection & Analysis | Identify and understand the incident | Alert triage, severity, timeline, scope |
| Containment | Stop the spread, limit damage | Isolate, block, revoke, preserve evidence |
| Eradication | Remove the root cause | Patch, rebuild, remove malware/backdoors |
| Recovery | Restore normal operations | Deploy clean systems, verify, monitor |
| Lessons Learned | Prevent recurrence | Post-mortem, action items, update defenses |

- Phases are not strictly sequential — you may loop between containment and analysis as you learn more.
- Evidence preservation happens throughout all phases, not just in one step.

Related notes: [009-network-security](./009-network-security.md)

### Preparation

- **Runbooks**: step-by-step procedures for common incident types (malware, unauthorized access, data breach, DDoS).
- **Contact list**: who to call — security team, management, legal, PR, affected service owners.
- **Tooling ready**: forensic tools installed, log aggregation working, disk imaging capability.
- **Access**: ensure responders have the access they need (sudo, log systems, network devices) BEFORE an incident.
- **Regular drills**: tabletop exercises simulate incidents to find gaps in the process.
- **Backups verified**: ensure backups exist, are recent, and can actually be restored.

```bash
# verify key tools are available
which tcpdump dd journalctl aureport
# verify backup is recent
ls -la /backup/latest/
```

Related notes: [008-linux-security-hardening](./008-linux-security-hardening.md)

### Detection and Analysis

- **Alert sources**: SIEM alerts, IDS/IPS, user reports, monitoring dashboards, threat intel feeds.
- **Triage**: quickly determine if the alert is real (true positive) or noise (false positive).
- **Severity classification**:
  - **P1 (Critical)**: active data breach, ransomware spreading, attacker has admin access
  - **P2 (High)**: compromised host, credential theft, no confirmed spread
  - **P3 (Medium)**: suspicious activity, failed brute force, policy violation
  - **P4 (Low)**: informational, minor policy deviation, no immediate risk
- **Timeline construction**: build a chronological view of events using logs from multiple sources.
- **Indicators of Compromise (IoC)**: IP addresses, file hashes, domain names, registry keys associated with the attack.

```bash
# search auth logs for brute force attempts
journalctl -u sshd | grep "Failed password" | tail -20

# check audit log for suspicious file access
ausearch -k sensitive_files --start recent

# search for known malicious hash
find / -type f -exec sha256sum {} \; 2>/dev/null | grep "known_bad_hash"

# check cron for persistence mechanisms
crontab -l
ls -la /etc/cron.d/
```

Related notes: [009-network-security](./009-network-security.md)

### Containment

- **Goal**: stop the bleeding without destroying evidence.
- **Short-term containment** (immediate):
  - Isolate the host from the network (disable interface or move to quarantine VLAN)
  - Block attacker IP at the firewall
  - Revoke compromised credentials / tokens
  - Disable compromised user accounts
- **Long-term containment** (while investigating):
  - Apply emergency patches
  - Increase monitoring on related systems
  - Restrict lateral movement (tighten firewall rules between segments)
- **Critical rule**: do NOT reboot, wipe, or reinstall before capturing evidence. Memory, network connections, and running processes are volatile — they're lost on reboot.

```bash
# isolate a host (disconnect from network but keep running)
ip link set eth0 down

# block an attacker IP at the firewall
iptables -I INPUT -s 203.0.113.50 -j DROP

# revoke a user's sessions (force re-authentication)
passwd -l compromised_user         # lock the account
loginctl terminate-user compromised_user  # kill active sessions

# list all active sessions to find suspicious ones
who -a
```

Related notes: [008-linux-security-hardening](./008-linux-security-hardening.md)

### Eradication and Recovery

- **Eradication**: remove the root cause — malware, backdoors, compromised accounts, vulnerable software.
- **Recovery**: restore systems to normal operation from a known-good state.
- Key steps:
  1. Identify and remove all attacker artifacts (malware, cron jobs, SSH keys, user accounts).
  2. Patch the vulnerability that allowed the initial compromise.
  3. Rebuild compromised systems from clean images (don't just "clean" them — you can't trust them).
  4. Restore data from verified backups (verify backups weren't also compromised).
  5. Reset all credentials that may have been exposed.
  6. Monitor closely after restore — attackers often return.

```bash
# check for unauthorized SSH keys
find /home -name "authorized_keys" -exec cat {} \;

# check for unauthorized cron jobs
for user in $(cut -f1 -d: /etc/passwd); do echo "=== $user ==="; crontab -l -u $user 2>/dev/null; done

# check for unusual SUID binaries
find / -perm -4000 -type f 2>/dev/null

# verify system binary integrity (if AIDE is configured)
aide --check
```

Related notes: [008-linux-security-hardening](./008-linux-security-hardening.md)

### Evidence Preservation

- **Why it matters**: evidence tells you what happened, how far the attacker got, and what data was accessed. Without evidence, you can't scope the breach or prevent recurrence.
- **Chain of custody**: document who collected what, when, and how. Evidence may be needed for legal or compliance purposes.
- **Collection order** (volatile to non-volatile — volatile data disappears first):
  1. **Memory**: running processes, network connections, open files (`/proc/`, memory dump)
  2. **Network**: active connections, ARP cache, routing table
  3. **Disk**: filesystem timestamps, log files, user files
  4. **Logs**: system logs, application logs, auth logs, audit logs
  5. **Configuration**: firewall rules, user accounts, cron jobs, startup scripts

```bash
# capture volatile data before isolation
# running processes
ps auxf > /evidence/processes_$(date +%s).txt

# network connections
ss -anp > /evidence/connections_$(date +%s).txt

# open files
lsof > /evidence/open_files_$(date +%s).txt

# create forensic disk image (bit-for-bit copy)
dd if=/dev/sda of=/evidence/disk_image.raw bs=4M status=progress

# capture system logs
journalctl --since "7 days ago" > /evidence/journal_$(date +%s).txt

# hash the evidence for integrity
sha256sum /evidence/* > /evidence/checksums.txt
```

Related notes: [006-secrets-management](./006-secrets-management.md)

### Post-Incident Review

- **Blameless post-mortem**: focus on what happened and what to improve, not who to blame.
- **Timeline document**: chronological record of the incident — when detected, what actions taken, when resolved.
- **Key questions**:
  - How did the attacker get in? (root cause)
  - How long were they in before detection? (dwell time)
  - What data or systems were affected? (scope)
  - What worked well in the response?
  - What was slow, confusing, or missing?
- **Action items**: each item gets an owner and a deadline. Examples:
  - "Enable MFA on all admin accounts" — Owner: security team — Due: 1 week
  - "Add monitoring for X alert" — Owner: SRE — Due: 2 weeks
  - "Update runbook for Y scenario" — Owner: incident lead — Due: 1 week
- **Share findings** (appropriately): team learns from incidents. Sanitized summaries help the broader organization.

Related notes: [009-network-security](./009-network-security.md)

---

# Troubleshooting Guide

### Can't determine scope of compromise
1. Start with the known compromised system: check auth logs, process list, network connections.
2. Search for the attacker's IoCs (IPs, file hashes, user accounts) across all systems: `grep -r "attacker_ip" /var/log/`.
3. Check lateral movement: did the compromised account access other systems? `ausearch -ua compromised_user`.
4. Check SIEM/log aggregation for the attacker's source IP across all services.
5. If scope is still unclear, assume worst case and contain broadly — you can release systems as you clear them.

### Logs missing or rotated
1. Check log rotation config: `cat /etc/logrotate.d/*` — are logs being rotated too aggressively?
2. Check if the attacker cleared logs: look for gaps in timestamps or truncated files.
3. Check remote log destinations: if logs are shipped to a SIEM or remote syslog, the attacker may not have reached those.
4. Check journal persistence: `journalctl --disk-usage` — is journald configured for persistent storage?
5. Prevention: ship logs to a remote system the attacker can't easily access; set `Storage=persistent` in journald.

### Unclear if system is clean after eradication
1. Do not trust a "cleaned" compromised system — rebuild from a known-good image.
2. If rebuild is not immediately possible: run integrity check (`aide --check`), scan for rootkits (`rkhunter --check`), verify all binaries against package manager (`rpm -Va` or `debsums`).
3. Check for persistence: cron jobs, systemd services, SSH authorized_keys, bashrc modifications, SUID binaries.
4. Monitor the system closely for 48-72 hours after recovery — watch for callbacks, unusual network traffic, new processes.
