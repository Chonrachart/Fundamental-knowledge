# Grafana Alerting

- Grafana alerting evaluates queries on a schedule, fires when conditions breach thresholds for a sustained duration, and routes notifications through policies to contact points.
- The pipeline is: alert rule (query + condition) -> notification policy (label routing) -> contact point (delivery channel).
- Silences suppress notifications during maintenance; the "for" duration prevents flapping by requiring the condition to hold before firing.

# Architecture

```text
+--------------+     +-----------------+     +---------------------+
|  Data Source  |     |   Alert Rule    |     | Notification Policy |
| (Prometheus,  |---->| - query         |---->| - label matchers    |
|  Loki, etc.)  |     | - condition     |     | - grouping          |
+--------------+     | - for duration  |     | - timing intervals  |
                      | - folder        |     +---------------------+
                      | - annotations   |              |
                      +-----------------+              |
                                                       v
                                              +------------------+
                                              |  Contact Point   |
                                              | - Email          |
                                              | - Slack          |
                                              | - PagerDuty      |
                                              | - Webhook        |
                                              +------------------+
                                                       |
                                                       v
                                              +------------------+
                                              |    Delivery      |
                                              | (message sent)   |
                                              +------------------+

  Silence -----> suppresses notifications for matching alerts
                 (applied before delivery, based on matchers)
```

# Mental Model

```text
Alert lifecycle (state transitions):

  [Normal] --condition true--> [Pending] --"for" elapsed--> [Firing] --condition false--> [Resolved]
     ^                            |                            |                              |
     |                            |                            v                              |
     +---condition false----------+                       [Silence]                           |
                                                       (suppresses                            |
                                                        notification                          |
                                                        only)                                 |
     ^                                                                                        |
     +----------------------------------------------------------------------------------------+
```

```text
Example: CPU alert pipeline

  [1] Alert rule: query = avg(cpu_usage{job="app"})
                  condition = IS ABOVE 80
                  for = 5m
                  evaluate every = 1m

  [2] Evaluation cycle:
      t=0  cpu=75  -> Normal
      t=1  cpu=82  -> Pending (condition true, "for" timer starts)
      t=5  cpu=85  -> Pending (condition true for 4m, not yet 5m)
      t=6  cpu=88  -> Firing  (condition true for 5m, "for" elapsed)

  [3] Notification policy: severity=critical -> route to "ops-team"
  [4] Contact point "ops-team": Slack channel #ops-alerts
  [5] Slack message delivered with annotations (summary, description)
```

# Core Building Blocks

### Alert Rule

- Based on a data source query; condition defines the threshold (e.g. IS ABOVE 80, IS BELOW 1).
- Evaluated every interval (e.g. 1m); query runs and result is checked against the condition.
- **Folder**: Organizes rules; permissions are scoped by folder.
- **For duration**: How long the condition must be continuously true before the alert fires (avoids flapping on transient spikes).
- **Annotations**: Summary and description fields; available in the notification message via templates.

Related notes: [002-dashboards-queries](./002-dashboards-queries.md), [004-promql-deep-dive](./004-promql-deep-dive.md)

### Contact Point

- Defines where to send alert notifications: email, Slack, PagerDuty, webhook, and more.
- Configure per type: Slack needs a webhook URL and channel; PagerDuty needs a routing key; email needs SMTP settings.
- Test delivery from the Grafana UI before relying on it in production.
- **Grafana Contact Points** are built-in; alternatively use an external Alertmanager if running a Prometheus stack.

Related notes: [001-grafana-overview](./001-grafana-overview.md)

### Notification Policy

- Routes alerts to contact points based on label matchers (e.g. severity="critical", team="platform").
- **Default policy**: Catch-all route; sends unmatched alerts to a default contact point.
- **Specific routes**: Match on labels to send to different channels (e.g. severity=warning -> email, severity=critical -> PagerDuty).
- **Grouping**: Combine related alerts into a single notification (group by alertname, cluster, namespace).
- **Timing intervals**: group_wait (initial delay), group_interval (batch window), repeat_interval (re-notify throttle).

Related notes: [001-grafana-overview](./001-grafana-overview.md)

### Silence

- Temporarily suppresses notifications for alerts matching specific criteria (e.g. during planned maintenance).
- Set start time, end time, and matchers (alertname, label key/value pairs).
- The alert still evaluates and fires -- only the notification delivery is silenced.
- Active silences are visible in the Grafana Alerting UI.

Related notes: [001-grafana-overview](./001-grafana-overview.md)

### Evaluation Behavior

- Rule runs every **evaluate** interval (e.g. 1m); the query is executed and the condition is checked each cycle.
- **For**: The pending duration -- condition must be true for this long before the state transitions from Pending to Firing.
- **No Data handling**: Configurable behavior when the query returns no data -- can be set to Alerting, No Data, OK, or Keep Last State.
- No Data is useful for detecting instance-down scenarios (e.g. a target stopped reporting metrics).

Related notes: [002-dashboards-queries](./002-dashboards-queries.md), [../Zabbix/001-zabbix-overview](../Zabbix/001-zabbix-overview.md)

---

# Troubleshooting Guide

```text
Problem: alert not firing or not delivering notifications
    |
    v
[1] Is the alert rule evaluating?
    Alerting > Alert Rules > check state and last evaluation time
    |
    +-- state = Normal --> condition not met; verify query in Explore
    +-- state = Error  --> query syntax error or data source issue
    |
    v
[2] Is the alert stuck in Pending?
    |
    +-- yes --> "for" duration not elapsed yet, or condition is flapping
    |           (true then false before "for" completes)
    |
    v
[3] Is the alert Firing but no notification received?
    Check Notification Policy: does a matcher route this alert?
    |
    +-- no matching route --> alert goes to default policy; check default contact point
    |
    v
[4] Is the contact point configured correctly?
    Test the contact point from Alerting > Contact Points > Test
    |
    +-- test fails --> check credentials, URLs, network connectivity
    |
    v
[5] Is a Silence active for this alert?
    Alerting > Silences > check matchers and time window
    |
    +-- silence active --> wait for expiry or remove the silence
    |
    v
[6] Check Grafana server logs for delivery errors
    grep "alerting" /var/log/grafana/grafana.log
```

# Quick Facts (Revision)

- Alert rule = query + condition + for duration + folder + annotations.
- Alert states: Normal -> Pending -> Firing -> Resolved.
- "For" duration prevents flapping: condition must hold continuously before firing.
- Contact points: email, Slack, PagerDuty, webhook -- configured and tested from UI.
- Notification policies route alerts by label matchers; default policy is the catch-all.
- Silences suppress notifications (not evaluation) for a time window using matchers.
- No Data handling: configurable per rule -- alert, OK, keep last state, or no data state.
- Grouping reduces noise: related alerts are batched into a single notification.
