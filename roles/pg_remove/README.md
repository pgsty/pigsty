# Role: pg_remove

> Remove PostgreSQL Cluster/Instance from Nodes

| **Module**        | [PGSQL](https://pigsty.io/docs/pgsql)                             |
|-------------------|-------------------------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/pgsql/admin/#remove-cluster                |
| **Related Roles** | [`pgsql`](../pgsql), [`pg_id`](../pg_id), [`node_id`](../node_id) |


## Overview

The `pg_remove` role is a **DANGEROUS** role that removes PostgreSQL clusters or instances from target nodes. 
It performs the reverse operation of the [`pgsql`](../pgsql) role, cleaning up:

- Monitoring targets (Victoria Metrics, Grafana datasources, Vector logs)
- Exporters (pg_exporter, pgbouncer_exporter, pgbackrest_exporter)
- Access layer (HAProxy services, VIP, DNS records, pgBouncer)
- PostgreSQL instances (Patroni, Postgres)
- Backup data (pgBackRest repo)
- Data directories
- PostgreSQL packages

**WARNING**: This role can cause **DATA LOSS**. Always ensure proper backups before execution.


## Playbooks

| Playbook                             | Description                        |
|--------------------------------------|------------------------------------|
| [`pgsql-rm.yml`](../../pgsql-rm.yml) | Remove PostgreSQL cluster/instance |


## File Structure

```
roles/pg_remove/
├── defaults/
│   └── main.yml              # Default variables
├── meta/
│   └── main.yml              # Role dependencies
└── tasks/
    ├── main.yml              # Entry point: orchestrates removal
    ├── victoria.yml          # [rm_metrics] Remove from Victoria Metrics
    ├── grafana.yml           # [rm_ds] Remove Grafana datasources
    ├── pg_exporter.yml       # [pg_exporter] Remove pg_exporter
    ├── pgbouncer_exporter.yml # [pgbouncer_exporter] Remove pgbouncer_exporter
    ├── pgbackrest_exporter.yml # [pgbackrest_exporter] Remove pgbackrest_exporter
    ├── dns.yml               # [rm_dns] Remove DNS records
    ├── vip.yml               # [vip] Remove VIP manager
    ├── pg_service.yml        # [pg_service] Remove HAProxy services
    ├── pgbouncer.yml         # [pgbouncer] Remove pgBouncer
    ├── postgres.yml          # [postgres] Stop and remove Patroni/Postgres
    ├── pgbackrest.yml        # [pgbackrest] Remove backup repo
    └── uninstall.yml         # [pg_pkg] Uninstall packages
```


## Tags

### Tag Hierarchy

```
pg_remove (full role)
│
├── pg_safeguard               # Safeguard check (always runs)
│
├── pg_monitor                 # Remove monitoring components
│   ├── pg_deregister          # Deregister from infra
│   │   ├── rm_metrics         # Remove from Victoria Metrics
│   │   ├── rm_ds              # Remove Grafana datasources
│   │   └── rm_logs            # Remove Vector log sources
│   ├── pg_exporter            # Remove pg_exporter
│   ├── pgbouncer_exporter     # Remove pgbouncer_exporter
│   └── pgbackrest_exporter    # Remove pgbackrest_exporter
│
├── pg_access                  # Remove access layer
│   ├── dns                    # Remove DNS records
│   ├── vip                    # Remove VIP manager
│   ├── pg_service / haproxy   # Remove HAProxy services
│   └── pgbouncer              # Remove pgBouncer
│
├── pg_bootstrap               # Remove PostgreSQL
│   └── postgres / patroni     # Stop Patroni and Postgres
│       ├── pg_replica         # Remove replicas first
│       ├── pg_primary         # Remove primary instance
│       └── pg_meta            # Remove DCS metadata
│
├── pg_backup                  # Remove backup (if pg_rm_backup=true)
│   └── pgbackrest             # Remove pgBackRest stanza
│
├── pg_data                    # Remove data (if pg_rm_data=true)
│
└── pg_pkg                     # Uninstall packages (if pg_rm_pkg=true)
    └── pg_ext                 # Uninstall extensions only
```

### Usage Examples

```bash
# Remove monitoring only
./pgsql-rm.yml -l pg-test -t pg_monitor

# Remove access layer only
./pgsql-rm.yml -l pg-test -t pg_access

# Remove PostgreSQL without touching packages/data
./pgsql-rm.yml -l pg-test -t postgres

# Uninstall packages only
./pgsql-rm.yml -l pg-test -t pg_pkg -e pg_rm_pkg=true
```


## Key Variables

### Control Variables

| Variable       | Default | Description                             |
|----------------|---------|-----------------------------------------|
| `pg_safeguard` | `false` | Safeguard to prevent accidental removal |
| `pg_rm_data`   | `true`  | Remove PostgreSQL data directories      |
| `pg_rm_backup` | `true`  | Remove pgBackRest backup (primary only) |
| `pg_rm_pkg`    | `true`  | Uninstall PostgreSQL packages           |

### Identity (Reference)

| Variable     | Level    | Description         |
|--------------|----------|---------------------|
| `pg_cluster` | CLUSTER  | Target cluster name |
| `pg_role`    | INSTANCE | Instance role       |
| `pg_seq`     | INSTANCE | Instance sequence   |

### Paths (Reference)

| Variable       | Default          | Description               |
|----------------|------------------|---------------------------|
| `pg_data`      | `/pg/data`       | PostgreSQL data directory |
| `pg_fs_main`   | `/data/postgres` | Main filesystem path      |
| `pg_namespace` | `/pg`            | etcd namespace            |


## Safeguard Protection

The role includes a safeguard mechanism to prevent accidental cluster removal:

```yaml
# In pigsty.yml, set safeguard for critical clusters
pg-prod:
  vars:
    pg_safeguard: true  # Prevents accidental removal
```

To override safeguard:
```bash
./pgsql-rm.yml -l pg-prod -e pg_safeguard=false
```


## Removal Order

The removal process follows a specific order to ensure clean teardown:

1. **Monitoring** - Deregister from monitoring systems first
2. **Access Layer** - Remove services, VIP, DNS, pgBouncer
3. **Replicas** - Remove replica instances before primary
4. **Primary** - Remove primary instance
5. **Metadata** - Clean up DCS (etcd) entries
6. **Backup** - Remove pgBackRest repo (optional)
7. **Data** - Remove data directories (optional)
8. **Packages** - Uninstall software (optional)


## See Also

- [`pgsql`](../pgsql): Deploy PostgreSQL cluster
- [`pg_id`](../pg_id): Get PostgreSQL identity
- [Admin Guide](https://pigsty.io/docs/pgsql/admin): Cluster administration
