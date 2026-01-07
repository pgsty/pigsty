# Grafana Dashboards

This directory contains Grafana dashboard definitions for Pigsty monitoring system.

> **License**: AGPLv3 - GNU Affero General Public License v3.0
>
> The Grafana dashboards and related tooling in this directory are licensed under AGPLv3.
> See [LICENSE](LICENSE) for the full license text.
>
> Copyright 2018-2026 Ruohang Feng / Vonng (rh@vonng.com)


## Overview

Pigsty provides **57 built-in dashboards** organized by module:

| Directory       | Count | Description                                                             |
|-----------------|-------|-------------------------------------------------------------------------|
| [pgsql](pgsql/) | 29    | PostgreSQL cluster, instance, database, and query monitoring            |
| [infra](infra/) | 11    | Infrastructure components (VictoriaMetrics, Grafana, Nginx, etcd, etc.) |
| [node](node/)   | 8     | Host-level metrics (CPU, memory, disk, network, HAProxy, VIP)           |
| [redis](redis/) | 3     | Redis cluster and instance monitoring                                   |
| [app](app/)     | 2     | Application dashboards (PostgreSQL logs analysis)                       |
| [minio](minio/) | 2     | MinIO S3-compatible storage monitoring                                  |
| [mongo](mongo/) | 1     | MongoDB/FerretDB monitoring                                             |
| -               | 1     | [pigsty.json](pigsty.json) - Main home dashboard                        |


## Dashboard Catalog

### Home

- **[pigsty.json](pigsty.json)** - Pigsty home dashboard with global overview

### PGSQL Dashboards

Core PostgreSQL monitoring dashboards:

| Dashboard           | Description                                     |
|---------------------|-------------------------------------------------|
| `pgsql-overview`    | Global PostgreSQL overview across all clusters  |
| `pgsql-cluster`     | Single cluster view with all instances          |
| `pgsql-instance`    | Single PostgreSQL instance detailed metrics     |
| `pgsql-database`    | Single database metrics                         |
| `pgsql-databases`   | Multiple databases comparison                   |
| `pgsql-table`       | Single table detailed metrics                   |
| `pgsql-tables`      | Multiple tables comparison                      |
| `pgsql-query`       | Query performance analysis (pg_stat_statements) |
| `pgsql-session`     | Active sessions and connections                 |
| `pgsql-activity`    | Database activity and workload                  |
| `pgsql-xacts`       | Transaction statistics                          |
| `pgsql-replication` | Streaming replication metrics                   |
| `pgsql-persist`     | Storage and persistence metrics                 |
| `pgsql-proxy`       | Connection pooler metrics                       |
| `pgsql-pgbouncer`   | PgBouncer detailed metrics                      |
| `pgsql-patroni`     | Patroni HA cluster status                       |
| `pgsql-service`     | Service-level metrics                           |
| `pgsql-pitr`        | Point-in-time recovery (pgBackRest)             |
| `pgsql-alert`       | PostgreSQL alerting dashboard                   |
| `pgsql-exporter`    | pg_exporter status                              |
| `pgsql-shard`       | Sharding/Citus cluster view                     |
| `pgrds-cluster`     | AWS RDS/Aurora cluster monitoring               |
| `pgrds-instance`    | AWS RDS/Aurora instance monitoring              |

PGCAT (Catalog Analysis) dashboards:

| Dashboard        | Description                   |
|------------------|-------------------------------|
| `pgcat-instance` | Catalog analysis for instance |
| `pgcat-database` | Catalog analysis for database |
| `pgcat-schema`   | Schema object analysis        |
| `pgcat-table`    | Table catalog details         |
| `pgcat-query`    | Query plan analysis           |
| `pgcat-locks`    | Lock analysis                 |

### Node Dashboards

| Dashboard       | Description                  |
|-----------------|------------------------------|
| `node-overview` | Global node overview         |
| `node-cluster`  | Node cluster view            |
| `node-instance` | Single node detailed metrics |
| `node-disk`     | Disk I/O and storage         |
| `node-haproxy`  | HAProxy load balancer        |
| `node-vip`      | Virtual IP (vip-manager)     |
| `node-vector`   | Vector log collector         |
| `node-alert`    | Node alerting dashboard      |

### Infra Dashboards

| Dashboard               | Description             |
|-------------------------|-------------------------|
| `infra-overview`        | Infrastructure overview |
| `vmetrics-instance`     | VictoriaMetrics TSDB    |
| `vlogs-instance`        | VictoriaLogs            |
| `vtraces-instance`      | VictoriaTraces          |
| `vmalert-instance`      | VMAlert rules engine    |
| `alertmanager-instance` | Alertmanager            |
| `grafana-instance`      | Grafana self-monitoring |
| `nginx-instance`        | Nginx web server        |
| `etcd-overview`         | etcd cluster status     |
| `logs-instance`         | Log analysis (legacy)   |
| `inventory-cmdb`        | CMDB inventory view     |

### Redis Dashboards

| Dashboard        | Description           |
|------------------|-----------------------|
| `redis-overview` | Global Redis overview |
| `redis-cluster`  | Redis cluster view    |
| `redis-instance` | Single Redis instance |

### MinIO Dashboards

| Dashboard        | Description            |
|------------------|------------------------|
| `minio-overview` | MinIO overview         |
| `minio-instance` | MinIO instance metrics |

### MongoDB Dashboards

| Dashboard        | Description               |
|------------------|---------------------------|
| `mongo-overview` | MongoDB/FerretDB overview |

### Application Dashboards

| Dashboard        | Description                      |
|------------------|----------------------------------|
| `pglog-overview` | PostgreSQL log analysis overview |
| `pglog-session`  | PostgreSQL log session analysis  |


## Utilities

The [`grafana.py`](grafana.py) script provides utilities to manage Grafana dashboards.

### Environment Variables

```bash
# Grafana connection settings
export GRAFANA_ENDPOINT='http://i.pigsty/ui'  # Grafana URL
export GRAFANA_USERNAME='admin'                # Username
export GRAFANA_PASSWORD='pigsty'               # Password

# Optional: Domain replacement
export NGINX_UPSTREAM=""
export NGINX_SSL_ENABLED="false"
```

### Commands

```bash
# Initialize baseline dashboards
./grafana.py init

# Dump all dashboards to current directory
./grafana.py dump .

# Load dashboards from current directory
./grafana.py load .

# Remove dashboards and folders from Grafana
./grafana.py clean .
```

### Makefile Shortcuts

From the Pigsty root directory:

```bash
make di   # dashboard init  - Initialize dashboards
make dd   # dashboard dump  - Export dashboards to files
make dc   # dashboard clean - Remove dashboards from Grafana
```


## Data Sources

Dashboards use the following Grafana data sources:

| UID             | Name       | Type            | Description                   |
|-----------------|------------|-----------------|-------------------------------|
| `ds-prometheus` | Prometheus | VictoriaMetrics | Time-series metrics (default) |
| `ds-meta`       | Meta       | PostgreSQL      | CMDB metadata queries         |
| `ds-vlogs`      | Loki       | VictoriaLogs    | Log queries                   |


## Customization

To customize dashboards:

1. Export existing dashboards: `./grafana.py dump .`
2. Edit the JSON files as needed
3. Reload dashboards: `./grafana.py load .`

Dashboard JSON files follow the standard Grafana dashboard format and can be edited using:
- Grafana UI (export after editing)
- Direct JSON editing
- Grafana dashboard provisioning


## References

- [Pigsty Monitoring Documentation](https://pigsty.io/docs/infra/grafana/)
- [Grafana Dashboard JSON Model](https://grafana.com/docs/grafana/latest/dashboards/json-model/)
- [VictoriaMetrics Documentation](https://docs.victoriametrics.com/)
