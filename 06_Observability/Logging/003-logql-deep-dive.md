# LogQL Deep Dive

- LogQL is Loki's query language — structurally similar to PromQL but designed for log streams
- Queries start with a stream selector (label filter), then chain pipeline stages to filter, parse, and transform log lines
- Two query types: log queries (return log lines) and metric queries (return numeric values from logs)

# Architecture

```text
+---------------------+     +-------------------+     +------------------+     +-------------+
|  Log Stream         |     | Stream Selector   |     | Pipeline Stages  |     | Output      |
|  (stored in Loki)   |---->| {job="api"}       |---->| |= "error"       |---->| Log lines   |
|                     |     | {namespace="prod"} |     | | json           |     | or Metrics  |
+---------------------+     +-------------------+     | | status >= 500  |     +-------------+
                                                       +------------------+
```

# Mental Model

```text
LogQL query-building flow:

  [1] Select stream         -->  {job="api"}
  [2] Filter lines          -->  {job="api"} |= "error"
  [3] Parse fields          -->  {job="api"} |= "error" | json
  [4] Filter parsed fields  -->  {job="api"} |= "error" | json | status >= 500
  [5] Format output         -->  ... | line_format "{{.method}} {{.path}}"
```

```text
Example: find all 5xx errors in the api service

  {job="api"} |= "error" | json | status >= 500 | line_format "{{.method}} {{.path}} {{.status}}"
```

# Core Building Blocks

### Stream Selectors

- {job="api"} — exact match
- {namespace=~"prod.*"} — regex match
- Operators: `=`, `!=`, `=~`, `!~`
- Stream selectors are the primary index — always start queries with specific label matches for performance

Related notes: [002-loki](./002-loki.md)

### Line Filters

- `|= "text"` — line contains
- `!= "text"` — line does not contain
- `|~ "regex"` — line matches regex
- `!~ "regex"` — line does not match regex
- Line filters run BEFORE parsing — place them early in the pipeline for performance

Related notes: [002-loki](./002-loki.md)

### Parser Stages

- `| json` — parse JSON log lines into labels
- `| logfmt` — parse logfmt key=value pairs
- `| pattern "<pattern>"` — extract fields by pattern matching (e.g., `| pattern "<ip> - - <_> \"<method> <path> <_>\" <status>"`)
- `| unpack` — unpack packed JSON labels (used with Promtail pack stage)
- `| regexp "<regex>"` — extract fields by regex with named capture groups
- Parser stages create new labels from log content — these labels can then be filtered on

Related notes: [002-loki](./002-loki.md)

### Label Filters (post-parse)

- `| status >= 500` — numeric comparison on parsed field
- `| method = "GET"` — string comparison on parsed field
- `| duration > 1s` — duration comparison
- `| ip != "10.0.0.1"` — exclude specific values
- Label filters work on labels created by parser stages — they cannot filter on raw log text

Related notes: [002-loki](./002-loki.md)

### Formatting

- `| line_format "{{.method}} {{.path}} {{.status}}"` — reformat output lines using Go templates
- `| label_format new_label=combined_value` — create/modify labels
- Formatting is the last pipeline stage — use it to clean up output for readability

Related notes: [002-loki](./002-loki.md)

### Metric Queries

- `count_over_time({job="api"} |= "error" [5m])` — count matching lines in window
- `rate({job="api"} [5m])` — per-second rate of log lines
- `bytes_over_time({job="api"} [1h])` — bytes processed
- `sum by (status) (count_over_time({job="api"} | json [5m]))` — aggregate by parsed label
- Metric queries turn logs into time-series — useful for alerting on log patterns and building dashboards from log data

Related notes: [002-loki](./002-loki.md), [001-logging-overview](./001-logging-overview.md)

# Troubleshooting Guide

### LogQL query returns no results

1. Check stream selector matches existing labels: Grafana Explore → Label browser to see available labels.
2. Verify time range — Loki may have limited retention.
3. Remove pipeline stages one by one to find which stage filters out all results.
4. Check if parser matches log format: test with just `{job="api"} | json` first.

### LogQL query is slow

1. Narrow the stream selector — fewer streams = faster query.
2. Add line filter (`|= "error"`) before parser — filtering raw text is faster than parsing all lines.
3. Reduce time range.
4. Check Loki limits: `max_query_length`, `max_entries_limit_per_query`.
