# Role: pg_pitr

> Point-In-Time Recovery for PostgreSQL Clusters

| **Module**        | [PGSQL](https://pigsty.io/docs/pgsql)                             |
|-------------------|-------------------------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/pgsql/pitr                                 |
| **Related Roles** | [`pgsql`](../pgsql), [`pg_id`](../pg_id), [`node_id`](../node_id) |


## Overview

The `pg_pitr` role performs **Point-In-Time Recovery** (PITR) for PostgreSQL clusters using pgBackRest. It allows you to:

- Restore a cluster to a specific point in time
- Restore to a specific transaction ID (XID)
- Restore to a specific Log Sequence Number (LSN)
- Restore to a named restore point
- Restore to the end of WAL archives (latest state)
- Restore from one cluster's backup to another cluster

**WARNING**: This is a **DANGEROUS** operation that will replace existing data. Always verify backups and test in non-production environments first.


## Playbooks

| Playbook                                 | Description           |
|------------------------------------------|-----------------------|
| [`pgsql-pitr.yml`](../../pgsql-pitr.yml) | Execute PITR recovery |


## File Structure

```
roles/pg_pitr/
├── defaults/
│   └── main.yml              # Default variables and pg_pitr schema
├── meta/
│   └── main.yml              # Role dependencies
├── tasks/
│   ├── main.yml              # Entry point
│   ├── print.yml             # [print] Display PITR plan
│   ├── pause.yml             # [pause] Pause Patroni HA
│   ├── stop.yml              # [stop] Stop services
│   ├── pitr.yml              # [pitr] Execute PITR restore
│   ├── etcd.yml              # [etcd] Clean up DCS metadata
│   └── start.yml             # [start] Start services
└── templates/
    ├── command               # pgBackRest restore command
    ├── pg-restore            # Restore wrapper script
    └── pitr.conf             # PITR configuration file
```


## Tags

### Tag Hierarchy

```
pg_pitr (full role)
│
├── print (always)             # Display PITR plan
│
├── down                       # Shutdown phase
│   ├── pause                  # Pause Patroni auto-failover
│   └── stop                   # Stop services
│       ├── stop_patroni       # Stop Patroni
│       └── stop_postgres      # Stop PostgreSQL
│
├── pitr                       # Execute PITR
│   ├── config                 # Generate pgBackRest config
│   ├── backup                 # Backup existing data (optional)
│   ├── restore                # Execute pgBackRest restore
│   ├── recovery               # Start recovery and wait
│   └── verify                 # Verify recovery success
│
└── up                         # Startup phase
    ├── etcd                   # Clean DCS metadata
    └── start                  # Start services
        ├── start_postgres     # Start PostgreSQL
        └── start_patroni      # Start Patroni
```

### Usage Examples

```bash
# Execute only the restore phase (assumes services already stopped)
./pgsql-pitr.yml -l pg-meta -e '{"pg_pitr": {...}}' -t pitr

# Stop services only (for manual intervention)
./pgsql-pitr.yml -l pg-meta -e '{"pg_pitr": {...}}' -t down

# Start services after manual recovery
./pgsql-pitr.yml -l pg-meta -e '{"pg_pitr": {...}}' -t up
```


## Key Variables

### pg_pitr Configuration Object

The `pg_pitr` variable defines the recovery target:

```yaml
pg_pitr:
  # Source cluster (stanza name), defaults to pg_cluster
  cluster: "pg-meta"

  # Recovery target type: default, time, xid, name, lsn, immediate
  type: default

  # Recovery targets (mutually exclusive)
  time: "2025-01-01 10:00:00+00"  # UTC timestamp
  xid: "100000"                    # Transaction ID
  name: "restore_point_name"       # Named restore point
  lsn: "0/3000000"                 # Log Sequence Number

  # Backup set to restore from
  set: latest                      # 'latest' or specific backup label

  # Target timeline
  timeline: latest                 # 'latest' or integer timeline ID

  # Exclude the target point?
  exclusive: false

  # Post-recovery action: pause, promote, shutdown
  action: pause

  # Preserve archive settings after recovery? (set false for exploratory PITR)
  archive: true

  # Database filtering
  db_include: []                   # Include only these databases
  db_exclude: []                   # Exclude these databases

  # Tablespace mappings
  link_map: {}

  # Parallel restore processes (defaults to CPU count)
  process: 4

  # Custom repository configuration
  repo: {}

  # Backup existing data before restore?
  backup: false
```

### Recovery Target Types

| Type        | Description              | Example                  |
|-------------|--------------------------|--------------------------|
| `default`   | Latest consistent point  | End of WAL stream        |
| `time`      | Specific timestamp (UTC) | `2025-12-25 12:00:00+00` |
| `xid`       | Transaction ID           | `250000`                 |
| `name`      | Named restore point      | `before_migration`       |
| `lsn`       | Log Sequence Number      | `0/4001C80`              |
| `immediate` | First consistent point   | After base backup        |

### Post-Recovery Actions

| Action     | Description                          |
|------------|--------------------------------------|
| `pause`    | Keep cluster paused for verification |
| `promote`  | Promote to read-write immediately    |
| `shutdown` | Shutdown after recovery              |


## PITR Process

### Recovery Workflow

```
1. Print PITR Plan           [print]
   └── Display recovery target and parameters

2. Shutdown Phase            [down]
   ├── Pause Patroni         [pause]
   │   └── Disable auto-failover
   └── Stop Services         [stop]
       ├── Stop replicas first
       └── Stop primary

3. Execute PITR              [pitr]
   ├── Generate Config       [config]
   ├── Backup Existing       [backup] (optional)
   │   └── Move /pg/data to /pg/data-backup
   ├── Restore Data          [restore]
   │   └── pgbackrest restore
   ├── Start Recovery        [recovery]
   │   └── Start PostgreSQL in recovery mode
   └── Verify                [verify]
       └── Check pg_controldata

4. Startup Phase             [up]
   ├── Clean DCS             [etcd]
   │   └── Remove old cluster metadata
   └── Start Services        [start]
       ├── Start PostgreSQL
       └── Start Patroni
```

### Data Safety

The role can optionally backup existing data before restore:

```yaml
pg_pitr:
  backup: true  # Moves /pg/data to /pg/data-backup
```


## Troubleshooting

### Common Issues

1. **Recovery target not found**: Ensure the target time/xid/lsn exists in WAL archives
2. **Stanza not found**: Verify pgBackRest stanza is initialized
3. **Permission denied**: Check postgres user permissions on backup repo
4. **Timeline mismatch**: Use `timeline: latest` or specify correct timeline

### Verification Commands

```bash
# Check backup info
pgbackrest --stanza=pg-meta info

# Check WAL archives
pgbackrest --stanza=pg-meta archive-info

# Verify restore target exists
pgbackrest --stanza=pg-meta restore --dry-run \
  --target="2025-12-25 12:00:00+00" --type=time
```


## See Also

- [`pgsql`](../pgsql): Deploy PostgreSQL cluster
- [Backup Guide](https://pigsty.io/docs/pgsql/backup): Backup configuration
- [Restore Guide](https://pigsty.io/docs/pgsql/backup/restore): Detailed restore procedures
- [pgBackRest Docs](https://pgbackrest.org/user-guide.html): pgBackRest documentation
