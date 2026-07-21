# MySQL Monitoring Dashboards

Pigsty's MySQL monitoring follows the same operational drill-down used by the
PostgreSQL module:

| Dashboard | Purpose |
|-----------|---------|
| `mysql-overview` | Fleet topology, runtime health and workload |
| `mysql-cluster` | Members, current primary, quorum, GR queues, nodes and logs |
| `mysql-instance` | Query, session, InnoDB, Performance Schema, exporter and host diagnostics |
| `mysql-replication` | Group Replication roles, states, certification, apply and flow control |
| `mysql-alert` | Active alerts, recent risk signals, logs and safe triage guidance |

The dashboards use VictoriaMetrics through `ds-prometheus` and VictoriaLogs
through `ds-vlogs`. MySQL error events are mirrored to syslog and collected by
the existing node Vector pipeline. Log panels use its existing `job`, `ins`,
`ip`, `app`, and `unit` fields and filter cluster views by member IP; no MySQL
specific Vector schema is required. Slow-query SQL remains in the local slow
log by default, avoiding SQL leakage and unbounded high-cardinality streams.
Host panels also correlate existing node metrics by the MySQL targets' member
IP labels; they do not require `node_cluster` to match `mysql_cluster`.

`generate.py` is the source of truth for these JSON dashboards. Regenerate them
after changing the panel catalogue:

```bash
python3 files/grafana/mysql/generate.py
```

The role enables bounded statement digests, table/index I/O, Group Replication
member metrics, binlog size, processlist, and InnoDB metrics. Runtime role comes
only from Performance Schema; target labels never declare a primary or
secondary.
