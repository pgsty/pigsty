# Role: pg_monitor

> Setup PostgreSQL Monitoring Exporters and Register to Infra

| **Module**        | [PGSQL](https://pigsty.io/docs/pgsql)                                       |
|-------------------|-----------------------------------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/pgsql/monitor                                        |
| **Related Roles** | [`pgsql`](../pgsql), [`pg_exporters`](../pg_exporters), [`infra`](../infra) |


## Overview

The `pg_monitor` role sets up monitoring components for PostgreSQL clusters:

- **pg_exporter**: Collects PostgreSQL metrics (port 9630)
- **pgbouncer_exporter**: Collects pgBouncer metrics (port 9631)
- **pgbackrest_exporter**: Collects backup metrics (port 9854)

It also registers the cluster to infrastructure monitoring:

- **Victoria Metrics**: Register as scrape targets
- **Vector**: Configure log collection
- **Grafana**: Register databases as datasources


## Playbooks

| Playbook                                       | Description                                             |
|------------------------------------------------|---------------------------------------------------------|
| [`pgsql.yml`](../../pgsql.yml)                 | Full deployment (includes monitoring setup)             |
| [`pgsql-monitor.yml`](../../pgsql-monitor.yml) | Remote monitoring via [`pg_exporters`](../pg_exporters) |


## File Structure

```
roles/pg_monitor/
├── defaults/
│   └── main.yml                  # Default variables
├── handlers/
│   └── main.yml                  # Reload handlers
├── meta/
│   └── main.yml                  # Role dependencies
├── tasks/
│   ├── main.yml                  # Entry point
│   ├── pg_exporter.yml           # [pg_exporter] Setup pg_exporter
│   ├── pgbouncer_exporter.yml    # [pgbouncer_exporter] Setup pgbouncer_exporter
│   ├── pgbackrest_exporter.yml   # [pgbackrest_exporter] Setup pgbackrest_exporter
│   ├── register_victoria.yml     # [add_metrics] Register to Victoria Metrics
│   ├── register_vector.yml       # [add_logs] Register to Vector
│   └── register_grafana.yml      # [add_ds] Register to Grafana
└── templates/
    ├── pg_exporter.yml           # pg_exporter collector config
    ├── pg_exporter.env           # pg_exporter environment
    ├── pg_exporter.svc           # pg_exporter systemd service
    ├── pgbouncer_exporter.yml    # pgbouncer_exporter config
    ├── pgbouncer_exporter.env    # pgbouncer_exporter environment
    ├── pgbouncer_exporter.svc    # pgbouncer_exporter systemd service
    ├── pgbackrest_exporter.env   # pgbackrest_exporter environment
    ├── pgbackrest_exporter.svc   # pgbackrest_exporter systemd service
    ├── postgres.yaml             # Vector postgres log config
    └── pgbackrest.yaml           # Vector pgbackrest log config
```


## Tags

### Tag Hierarchy

```
pg_monitor (from pgsql.yml: -t monitor)
│
├── pg_exporter                    # PostgreSQL metrics exporter
│   ├── pg_exporter_config         # Generate exporter config
│   └── pg_exporter_launch         # Start exporter service
│
├── pgbouncer_exporter             # pgBouncer metrics exporter
│   ├── pgbouncer_exporter_config  # Generate exporter config
│   └── pgbouncer_exporter_launch  # Start exporter service
│
├── pgbackrest_exporter            # Backup metrics exporter
│   ├── pgbackrest_exporter_config # Generate exporter config
│   └── pgbackrest_exporter_launch # Start exporter service
│
└── pg_register                    # Register to infra services
    ├── add_metrics                # Register to Victoria Metrics
    ├── add_logs                   # Register to Vector
    └── add_ds                     # Register databases to Grafana
```

### Usage Examples

```bash
# Setup all exporters
./pgsql.yml -l pg-test -t pg_exporter,pgbouncer_exporter,pgbackrest_exporter

# Re-register to all infra services
./pgsql.yml -l pg-test -t pg_register

# Only add Grafana datasources
./pgsql.yml -l pg-test -t add_ds

# Only setup pg_exporter
./pgsql.yml -l pg-test -t pg_exporter
```


## Key Variables

### Exporter Settings

| Variable                     | Default           | Description               |
|------------------------------|-------------------|---------------------------|
| `pg_exporter_enabled`        | `true`            | Enable pg_exporter        |
| `pg_exporter_port`           | `9630`            | pg_exporter listen port   |
| `pg_exporter_config`         | `pg_exporter.yml` | Collector config file     |
| `pg_exporter_cache_ttls`     | `1,10,60,300`     | Collector TTL stages      |
| `pg_exporter_auto_discovery` | `true`            | Auto-discover databases   |
| `pg_exporter_url`            | (auto)            | Override DSN if specified |

### pgBouncer Exporter

| Variable                     | Default | Description               |
|------------------------------|---------|---------------------------|
| `pgbouncer_exporter_enabled` | `true`  | Enable pgbouncer_exporter |
| `pgbouncer_exporter_port`    | `9631`  | Listen port               |
| `pgbouncer_exporter_url`     | (auto)  | Override DSN if specified |

### pgBackRest Exporter

| Variable                      | Default        | Description                |
|-------------------------------|----------------|----------------------------|
| `pgbackrest_exporter_enabled` | `true`         | Enable pgbackrest_exporter |
| `pgbackrest_exporter_port`    | `9854`         | Listen port                |
| `pgbackrest_exporter_options` | (see defaults) | CLI options                |

### Database Discovery

| Variable                       | Default                        | Description                |
|--------------------------------|--------------------------------|----------------------------|
| `pg_exporter_include_database` | `''`                           | Databases to monitor (CSV) |
| `pg_exporter_exclude_database` | `template0,template1,postgres` | Databases to exclude       |
| `pg_exporter_connect_timeout`  | `200`                          | Connection timeout (ms)    |

### Credentials

| Variable              | Default          | Description      |
|-----------------------|------------------|------------------|
| `pg_monitor_username` | `dbuser_monitor` | Monitor user     |
| `pg_monitor_password` | `DBUser.Monitor` | Monitor password |


## Exporter Ports

| Exporter            | Default Port | Description                 |
|---------------------|--------------|-----------------------------|
| pg_exporter         | 9630         | PostgreSQL metrics          |
| pgbouncer_exporter  | 9631         | pgBouncer metrics           |
| pgbackrest_exporter | 9854         | Backup metrics              |
| patroni             | 8008         | Patroni API (health checks) |


## Auto Discovery

pg_exporter supports automatic database discovery:

```yaml
pg_exporter_auto_discovery: true
pg_exporter_exclude_database: 'template0,template1,postgres'
pg_exporter_include_database: ''  # Empty = all databases
```

When enabled, pg_exporter will:
1. Connect to the default database
2. List all databases (excluding template0, template1, postgres)
3. Collect per-database metrics from each


## Registered Targets

### Victoria Metrics

Creates target files at `/infra/targets/pgsql/<cluster>.yml`:
```yaml
- labels: { cls: pg-test, ins: pg-test-1, ip: 10.10.10.11, job: pgsql }
  targets: [ 10.10.10.11:9630 ]
```

### Vector Logs

Configures Vector to collect logs from:
- PostgreSQL: `/pg/log/postgres/*.csv`
- pgBackRest: `/pg/log/pgbackrest/*.log`
- Patroni: syslog
- pgBouncer: syslog

### Grafana Datasources

Registers each database as a Grafana PostgreSQL datasource:
- Name: `<cluster>.<database>`
- URL: `<primary_ip>:<pgbouncer_port>/<database>`


## See Also

- [`pgsql`](../pgsql): Deploy PostgreSQL cluster
- [`pg_exporters`](../pg_exporters): Remote PostgreSQL monitoring
- [`infra`](../infra): Infrastructure monitoring stack
- [Monitoring Guide](https://pigsty.io/docs/pgsql/monitor): PGSQL monitoring
