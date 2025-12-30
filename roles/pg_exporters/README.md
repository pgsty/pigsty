# Role: pg_exporters

> Setup Remote PostgreSQL Monitoring via Local Exporters

| **Module**        | [PGSQL](https://pigsty.io/docs/pgsql)                   |
|-------------------|---------------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/pgsql/monitor/#remote-monitoring |
| **Related Roles** | [`pg_monitor`](../pg_monitor), [`infra`](../infra)      |


## Overview

The `pg_exporters` role enables monitoring of **remote PostgreSQL instances** that are not managed by Pigsty. It deploys `pg_exporter` on **infra nodes** to collect metrics from external PostgreSQL databases.

This is useful for:

- Monitoring RDS instances (AWS, Azure, GCP, Aliyun, etc.)
- Monitoring PostgreSQL clusters outside Pigsty's management
- Centralized monitoring without agent deployment on target hosts

**Note**: Only PostgreSQL metrics are collected. Node, pgBouncer, Patroni, and HAProxy metrics are not available for remote instances.


## Playbooks

| Playbook                                       | Description                        |
|------------------------------------------------|------------------------------------|
| [`pgsql-monitor.yml`](../../pgsql-monitor.yml) | Setup remote PostgreSQL monitoring |


## File Structure

```
roles/pg_exporters/
├── defaults/
│   └── main.yml              # Default variables
├── meta/
│   └── main.yml              # Role dependencies
├── tasks/
│   ├── main.yml              # Entry point: iterate over pg_exporters
│   ├── pg_exporter.yml       # Setup individual exporter
│   └── register_grafana.yml  # Register datasources
└── templates/
    ├── pg_exporter.yml       # Collector configuration
    ├── pg_exporter.env       # Environment variables
    └── pg_exporter.svc       # Systemd service template
```


## Tags

```
pg_exporters                   # Setup remote pg_exporter instances
├── pg_register                # Register to monitoring
│   ├── add_metrics            # Register to Victoria Metrics
│   └── add_ds                 # Register to Grafana datasources
```

### Usage Examples

```bash
# Setup all remote exporters
./pgsql-monitor.yml -t pg_exporters

# Register to monitoring only
./pgsql-monitor.yml -t pg_register

# Setup specific cluster
./pgsql-monitor.yml -e clsname=pg-foo
```


## Key Variables

### pg_exporters Definition

Each entry in `pg_exporters` maps a local port to a remote instance:

```yaml
pg_exporters:
  <local_port>:
    pg_cluster: <cluster_name>     # Required: cluster name
    pg_seq: <sequence_number>      # Required: instance sequence
    pg_host: <remote_ip>           # Required: remote PostgreSQL IP
    pg_port: 5432                  # Optional: PostgreSQL port
    pg_dbsu: postgres              # Optional: database superuser
    pg_monitor_username: dbuser_monitor  # Optional: monitor user
    pg_monitor_password: DBUser.Monitor  # Optional: monitor password
    pg_exporter_url: ''            # Optional: override connection URL
    pg_exporter_config: pg_exporter.yml  # Optional: collector config
    pg_databases: []               # Optional: databases for Grafana DS
```

### Exporter Parameters

| Variable                       | Default                        | Description             |
|--------------------------------|--------------------------------|-------------------------|
| `pg_exporter_config`           | `pg_exporter.yml`              | Collector configuration |
| `pg_exporter_cache_ttls`       | `1,10,60,300`                  | Cache TTL stages        |
| `pg_exporter_params`           | `sslmode=disable`              | Connection parameters   |
| `pg_exporter_auto_discovery`   | `true`                         | Auto-discover databases |
| `pg_exporter_include_database` | `''`                           | Databases to include    |
| `pg_exporter_exclude_database` | `template0,template1,postgres` | Databases to exclude    |
| `pg_exporter_connect_timeout`  | `200`                          | Connection timeout (ms) |

### Connection URL

The connection URL is auto-generated:

```
postgres://<pg_monitor_username>:<pg_monitor_password>@<pg_host>:<pg_port>/postgres?<pg_exporter_params>
```

Override with `pg_exporter_url` if needed:

```yaml
pg_exporters:
  20001:
    pg_cluster: pg-rds
    pg_seq: 1
    pg_host: rds.example.com
    pg_exporter_url: 'postgres://monitor:password@rds.example.com:5432/postgres?sslmode=require'
```


## Remote PostgreSQL Setup

Before monitoring, configure the remote PostgreSQL:

```sql
-- Create monitoring user
CREATE USER dbuser_monitor PASSWORD 'DBUser.Monitor';
COMMENT ON ROLE dbuser_monitor IS 'system monitor user';

-- Grant monitoring permissions
GRANT pg_monitor TO dbuser_monitor;

-- Create required extension
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "monitor";
```

### HBA Configuration

Ensure the remote PostgreSQL allows connections from infra nodes:

```
# pg_hba.conf
host    all    dbuser_monitor    <infra_ip>/32    scram-sha-256
```


## Service Naming

Each exporter runs as a unique systemd service:

```
pg_exporter_<cluster>-<seq>
```

Example:
- `pg_exporter_pg-foo-1` (port 20001)
- `pg_exporter_pg-foo-2` (port 20002)


## Limitations

Remote monitoring has limitations compared to local monitoring:

| Feature            | Local | Remote |
|--------------------|-------|--------|
| PostgreSQL metrics | ✓     | ✓      |
| Node metrics       | ✓     | ✗      |
| pgBouncer metrics  | ✓     | ✗      |
| Patroni metrics    | ✓     | ✗      |
| HAProxy metrics    | ✓     | ✗      |
| Log collection     | ✓     | ✗      |


## See Also

- [`pg_monitor`](../pg_monitor): Local PostgreSQL monitoring
- [`infra`](../infra): Infrastructure monitoring stack
- [Remote Monitoring](https://pigsty.io/docs/pgsql/monitor/#remote-monitoring): Documentation
