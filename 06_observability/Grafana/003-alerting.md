alert rule
contact point
notification policy
silence
evaluate

---

# Alert Rule

- Based on query; condition (e.g. IS ABOVE 80, IS BELOW 1); evaluate every interval.
- **Folder**: Organize rules; permissions by folder.
- **Evaluation**: Run query; if condition true for **for** duration → firing; else → OK.
- **Annotations**: Summary and description; available in notification.

# Contact Point

- Where to send alerts: email, Slack, PagerDuty, webhook, etc.
- Configure per type (URL, channel, routing key); test from UI.
- **Grafana Contact Points** (or Alertmanager if using Prometheus stack).

# Notification Policy

- Route alerts to contact points by labels or matchers.
- **Default policy**: Catch-all; often route to default contact point.
- **Specific routes**: Match severity, team label → different Slack channel or PagerDuty.
- **Grouping**: Group alerts in one notification; **interval**: Throttle repeat notifications.

# Silence

- Temporarily stop notifications for matching alerts (e.g. during maintenance).
- Set start/end; matchers (alertname, label); silences shown in UI.

# Evaluate

- Rule runs every **evaluate** interval (e.g. 1m); query executed; condition checked.
- **For**: How long condition must be true before firing (avoids flapping).
- **No Data**: Option to alert when query returns no data (e.g. instance down).
