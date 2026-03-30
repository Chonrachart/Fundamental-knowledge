# Alertmanager

- Alertmanager receives alerts from Prometheus, groups and deduplicates them, applies inhibition rules, and routes notifications to configured receivers.
- Core features: alert grouping (`group_by` labels), grouping behavior (`group_wait`, `group_interval`, `repeat_interval`), inhibition rules, silence management.
- Notification integrations: Slack, email, PagerDuty, Opsgenie, webhook, generic HTTP, SMS, chat (Discord, Mattermost, Telegram).

# Architecture

```text
+---------------------+
| Prometheus Server    |
| (fires alerts)       |
+----------+----------+
           |
           | HTTP POST
           | /api/v1/alerts
           v
+---------------------+
| Alertmanager        |
| (single node)       |
|                     |
| +-------+--------+  |
| | Alert |Dedup & |  |
| | Store |Group  |  |
| +---+---+---+----+  |
|     |       |       |
| +---v-------v---+   |
| | Routes &      |   |
| | Inhibition    |   |
| +---+-----------+   |
|     |               |
| +---v-----------+   |
| | Notification  |   |
| | Dispatcher    |   |
| +---+-----------+   |
+-----+-----------+--+
      |
      +--------+--------+--------+--------+
      |        |        |        |        |
      v        v        v        v        v
   Slack    Email   PagerDuty  Webhook  SMS
```

# Mental Model

```text
Alert lifecycle in Alertmanager:

  [1] Prometheus fires alert (alert rule condition met)
      HTTP POST /api/v1/alerts with alert JSON
      |
      v
  [2] Alertmanager receives alert
      Stores in memory, starts group aggregation timer (group_wait)
      |
      v
  [3] Deduplication & Grouping
      Match incoming alert to existing groups by group_by labels
      If new, create group; if existing, add to group
      Wait group_wait duration before sending (allows related alerts to arrive)
      |
      v
  [4] Apply Inhibition Rules
      Check if alert matches any inhibition condition
      If matches, suppress (do not send)
      |
      v
  [5] Apply Silences
      Check if alert matches any silence (time window, label filters)
      If silenced, skip notification
      |
      v
  [6] Route Alert
      Walk routing tree (top-level route + nested routes)
      Match on labels, determine receiver and repeating behavior
      |
      v
  [7] Send Notifications
      Dispatch to receiver (Slack webhook, email, PagerDuty API, etc.)
      If fails, retry exponentially
      |
      v
  [8] Track and Re-send
      Wait repeat_interval before sending same alert again
      If alert resolves, send resolved notification (if enabled)
```

```text
Example alert lifecycle:

Prometheus fires: alert HighCPU{instance="host1", severity="warning"}
                  alert HighCPU{instance="host1", severity="critical"}
                  alert HighMemory{instance="host1", severity="warning"}

Alertmanager:
  [1] group_by: [severity] groups by severity label
      Group "warning": contains HighCPU and HighMemory
      Group "critical": contains HighCPU
  [2] group_wait: 30s
      Wait 30 seconds for more related alerts
      Time expires, dispatch both groups
  [3] route:
      Group "warning" matches severity=warning route -> @slack-ops
      Group "critical" matches severity=critical route -> @pagerduty-oncall
  [4] inhibit_rules:
      If severity=critical exists, inhibit severity=warning (same instance)
      Group "warning" suppressed
  [5] send notifications:
      "@slack-ops": HighMemory alert only (warning)
      "@pagerduty-oncall": HighCPU alert (critical)
  [6] repeat_interval: 4h
      If alerts still firing, re-send after 4 hours
```

```yaml
# simplified alertmanager.yml structure
global:
  resolve_timeout: 5m
  slack_api_url: '{{ SLACK_WEBHOOK_URL }}'

route:
  receiver: 'slack-default'
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

  routes:
    - match:
        severity: critical
      receiver: 'pagerduty'
      repeat_interval: 1h

    - match_re:
        alertname: 'Prom.*'
      receiver: 'slack-sre'

inhibit_rules:
  - source_match:
      severity: critical
    target_match:
      severity: warning
    equal: [instance, alertname]

receivers:
  - name: 'slack-default'
    slack_configs:
      - channel: '#alerts'

  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: '{{ PAGERDUTY_KEY }}'

  - name: 'slack-sre'
    slack_configs:
      - channel: '#sre-alerts'
```

# Core Building Blocks

### Alert Routing

- Routing is a tree of rules that match incoming alerts to receivers.
- Root route defines default receiver and grouping behavior.
- Nested routes override parent settings for specific label matches.
- Matching operators: `match` (equality), `match_re` (regex), `match_re_inverse`.

```yaml
route:
  receiver: 'default'
  group_by: ['alertname']

  routes:
    # all alerts with severity=critical go to pagerduty
    - match:
        severity: critical
      receiver: 'pagerduty'

    # alerts matching alertname=AlertX and team=backend go to slack-backend
    - match:
        alertname: AlertX
        team: backend
      receiver: 'slack-backend'

    # alerts with alertname starting with "Prom" go to slack-sre
    - match_re:
        alertname: 'Prom.*'
      receiver: 'slack-sre'

    # catch-all for remaining
    - receiver: 'slack-general'
```

Related notes: [001-prometheus-overview](./001-prometheus-overview.md), [../Grafana/003-alerting](../Grafana/003-alerting.md)

### Grouping Behavior

- **`group_by`**: list of label names to group alerts by. Example: `group_by: [alertname, severity]` groups alerts by alert name and severity.
- **`group_wait`**: wait time before sending first notification for a new group (default 10s). Allows related alerts to arrive together.
- **`group_interval`**: wait time between sending successive notifications for the same group (default 5m). Lower = more frequent batches.
- **`repeat_interval`**: wait time before re-sending a group notification if alert still active (default 4h).

```text
Timing example:

  t=0:   alert fires, group created, starts group_wait (10s)
  t=8:   another alert arrives in same group
  t=10:  group_wait expires, send grouped notification (2 alerts)
  t=10-300: wait group_interval (5m)
  t=300: if alerts still active, send new notification
  t=300-240m: wait repeat_interval (4h)
  t=14400: if alerts still active, send repeat notification
```

Related notes: [001-prometheus-overview](./001-prometheus-overview.md)

### Inhibition Rules

- Inhibition suppresses certain alerts when others are firing.
- Use case: suppress low-severity alerts when high-severity ones exist (e.g. suppress warning when critical exists).
- Matched via `source_match`/`source_match_re` (condition to check) and `target_match`/`target_match_re` (alerts to suppress).
- `equal` labels must have the same value in both source and target for inhibition to apply.

```yaml
inhibit_rules:
  # suppress warning if critical already exists for same instance
  - source_match:
      severity: critical
    target_match:
      severity: warning
    equal: [instance, alertname]

  # suppress page_team_required if page_team_on_call fires
  - source_match:
      alertname: page_team_on_call
    target_match:
      alertname: page_team_required
    equal: [instance]

  # suppress non-critical alerts if KubernetesPodCrashLooping exists
  - source_match:
      alertname: KubernetesPodCrashLooping
    target_match:
      severity: warning
    equal: [namespace]
```

Related notes: [001-prometheus-overview](./001-prometheus-overview.md), [../000-core](../000-core.md)

### Silences

- Silence is a time-window filter that suppresses notifications for alerts matching certain labels.
- Useful for maintenance windows, testing, or temporary suppression without changing alerting rules.
- Can be set via UI, CLI, or API; persists to disk.

```bash
# Create silence via API
curl -X POST http://alertmanager:9093/api/v1/silences \
  -H 'Content-Type: application/json' \
  -d '{
    "matchers": [
      {
        "name": "instance",
        "value": "host1",
        "isRegex": false
      }
    ],
    "startsAt": "2024-01-15T10:00:00Z",
    "endsAt": "2024-01-15T12:00:00Z",
    "createdBy": "admin",
    "comment": "maintenance window"
  }'

# List active silences
curl http://alertmanager:9093/api/v1/silences | jq '.data'

# View UI (easier)
http://alertmanager:9093/
```

Related notes: [../Grafana/003-alerting](../Grafana/003-alerting.md), [001-prometheus-overview](./001-prometheus-overview.md)

### Notification Integrations

- **Slack**: webhook URL, channel, custom messages, formatted fields.
- **Email**: SMTP configuration, recipient list, subject/body templates.
- **PagerDuty**: service key, event action (trigger/resolve/acknowledge).
- **Opsgenie**: API key, responder types (teams, users, schedules).
- **Webhook**: generic HTTP POST to any URL; Alertmanager sends JSON.
- **SMS**: Twilio or similar via custom webhook.
- **Chat**: Discord, Mattermost, Telegram via webhooks.

```yaml
receivers:
  - name: 'slack-team'
    slack_configs:
      - api_url: '{{ SLACK_WEBHOOK_URL }}'
        channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
        send_resolved: true

  - name: 'email-ops'
    email_configs:
      - to: 'ops@company.com'
        from: 'alertmanager@company.com'
        smarthost: 'smtp.company.com:587'
        auth_username: 'alertmanager'
        auth_password: '{{ SMTP_PASSWORD }}'

  - name: 'pagerduty-critical'
    pagerduty_configs:
      - service_key: '{{ PAGERDUTY_KEY }}'
        severity: 'critical'

  - name: 'webhook-custom'
    webhook_configs:
      - url: 'http://myapp:5000/webhooks/alerts'
        send_resolved: true
```

Related notes: [../000-core](../000-core.md), [../Grafana/003-alerting](../Grafana/003-alerting.md)

### Alertmanager High Availability

- Alertmanager can run in a cluster for high availability.
- Gossip protocol syncs state (silences, alerts) between peers.
- Configure via `--cluster.peer-address` and `--cluster.listen-address` flags.
- All instances listen on the same address; clients send to any instance via load balancer.

```bash
# start 3-node Alertmanager cluster
# node 1
alertmanager --config.file=alertmanager.yml --storage.path=/data/alertmanager \
  --cluster.listen-address=0.0.0.0:6783 --cluster.peer-address=node2:6783 --cluster.peer-address=node3:6783

# node 2
alertmanager --config.file=alertmanager.yml --storage.path=/data/alertmanager \
  --cluster.listen-address=0.0.0.0:6783 --cluster.peer-address=node1:6783 --cluster.peer-address=node3:6783

# node 3
alertmanager --config.file=alertmanager.yml --storage.path=/data/alertmanager \
  --cluster.listen-address=0.0.0.0:6783 --cluster.peer-address=node1:6783 --cluster.peer-address=node2:6783
```

Related notes: [001-prometheus-overview](./001-prometheus-overview.md), [../000-core](../000-core.md)

### Alert States and Lifecycle

- Alertmanager tracks alerts as **firing** (condition true, notification sent) or **resolved** (condition false, resolve notification sent if enabled).
- **Suppressed**: alert fired but inhibited by inhibition rules or matched by a silence.
- For generic alert states (Normal, Pending, Firing, Resolved) and the "for" duration concept, see Grafana alerting.

Related notes: [001-prometheus-overview](./001-prometheus-overview.md), [../Grafana/003-alerting](../Grafana/003-alerting.md)
Related notes: [../Grafana/003-alerting](../Grafana/003-alerting.md) for Grafana-native alerting UI workflow

### Alert Annotations and Labels

- **Labels**: used for routing and grouping in Alertmanager (e.g. severity, team, env).
- **Annotations**: human-readable descriptions displayed in notifications (e.g. summary, description, runbook).
- Both defined in Prometheus alert rules; passed to Alertmanager.

```yaml
# in Prometheus alert rule:
alert: HighCPU
annotations:
  summary: "CPU high on {{ $labels.instance }}"
  description: "CPU usage is {{ $value }}% (threshold: 90%)"
  runbook: "https://wiki.company.com/runbooks/high-cpu"
labels:
  severity: warning
  team: platform
```

Related notes: [001-prometheus-overview](./001-prometheus-overview.md)
