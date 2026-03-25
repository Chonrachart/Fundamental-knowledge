# TraceQL Deep Dive

- TraceQL is Tempo's query language for searching and filtering distributed traces by span attributes
- Queries use curly-brace selectors similar to PromQL/LogQL but target span and resource attributes
- Two search modes: span-level (find individual spans) and trace-level (find traces where any span matches)

# Architecture

```text
+------------------+     +------------------+     +----------------+     +-------------+
|  Trace Storage   |     | TraceQL Engine   |     | Span Selector  |     | Results     |
|  (Tempo backend) |---->| (parse, plan,    |---->| + Filters      |---->| Matching    |
|                  |     |  execute)        |     | + Structural   |     | traces/spans|
+------------------+     +------------------+     +----------------+     +-------------+
```

# Mental Model

```text
TraceQL query-building flow:

  [1] Select by resource    -->  {resource.service.name="api"}
  [2] Filter by span attr   -->  {resource.service.name="api" && span.http.status_code >= 500}
  [3] Add duration filter   -->  {... && duration > 500ms}
  [4] Structural query      -->  {resource.service.name="api"} >> {resource.service.name="db"}
```

```text
Example: find slow error requests from api service calling database

  {resource.service.name="api" && span.http.status_code >= 500 && duration > 500ms}
```

# Core Building Blocks

### Span Selectors

- `{resource.service.name="api"}` — match spans by resource attribute
- `{span.http.method="GET"}` — match by span attribute
- `{name="HTTP GET /users"}` — match by span name
- `{status=error}` — match error spans
- Combine with `&&`: `{resource.service.name="api" && span.http.status_code >= 500}`

Related notes: [001-tempo-overview](./001-tempo-overview.md)

### Intrinsic Attributes

- `duration` — span duration: `{duration > 500ms}`
- `status` — span status: `{status=error}`, `{status=ok}`, `{status=unset}`
- `name` — span name: `{name="HTTP GET"}`
- `kind` — span kind: `{kind=server}`, `{kind=client}`
- Intrinsic attributes are built into every span — no prefix needed

Related notes: [001-tempo-overview](./001-tempo-overview.md)

### Resource vs Span Attributes

- `resource.*` — attributes set on the resource (service name, namespace, pod): `{resource.k8s.namespace.name="prod"}`
- `span.*` — attributes set on the individual span (HTTP method, status code, db statement): `{span.http.method="POST"}`
- Resource attributes are shared across all spans from the same service instance
- Span attributes are unique per operation
- Use `resource.service.name` as the primary filter — it's the most indexed attribute

Related notes: [001-tempo-overview](./001-tempo-overview.md)

### Structural Queries

- `>>` — descendant: `{resource.service.name="api"} >> {resource.service.name="db"}` — find traces where api calls db (at any depth)
- `>` — direct child: `{name="HTTP GET"} > {name="SQL SELECT"}` — parent-child relationship
- `~` — sibling: spans sharing the same parent
- Structural queries are TraceQL's unique power — find traces by service interaction patterns
- Always include `resource.service.name` in structural queries for performance

Related notes: [001-tempo-overview](./001-tempo-overview.md)

### Aggregate Queries

- `{resource.service.name="api"} | count()` — count matching spans
- `{resource.service.name="api"} | avg(duration)` — average duration
- `{resource.service.name="api"} | quantile_over_time(duration, 0.99)` — p99 latency
- `{status=error} | rate()` — error span rate
- Aggregates return metrics from traces — useful for service-level performance analysis

Related notes: [001-tempo-overview](./001-tempo-overview.md)

# Troubleshooting Guide

### TraceQL query returns no results

1. Check service name exists: Grafana Explore → Tempo → Service Name dropdown.
2. Verify attribute names: use `span.http.status_code` not `span.status_code` (check OTel semantic conventions).
3. Check time range — Tempo retention may be limited.
4. Try simpler query first: `{resource.service.name="api"}` without filters to verify data exists.

### TraceQL query is slow

1. Add `resource.service.name` filter — it's the primary index.
2. Narrow time range.
3. Avoid broad structural queries (`>>`) without resource filters.
4. Check Tempo query-frontend limits and timeout settings.
