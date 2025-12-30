# Role: pg_migration

> Generate Migration Plan for PostgreSQL Logical Replication

| **Module**        | [PGSQL](https://pigsty.io/docs/pgsql)  |
|-------------------|----------------------------------------|
| **Docs**          | https://pigsty.io/docs/pgsql/migration |
| **Related Roles** | [`pgsql`](../pgsql)                    |


## Overview

The `pg_migration` role generates migration scripts and documentation for performing **zero-downtime database migration** between PostgreSQL clusters using **logical replication**.

This role does NOT perform the migration automatically. Instead, it generates:

- A detailed migration manual (`README.md`)
- Executable scripts for each migration step
- Pre-flight check scripts for validation

The actual migration is executed manually by operators following the generated plan.


## Playbooks

| Playbook                                           | Description             |
|----------------------------------------------------|-------------------------|
| [`pgsql-migration.yml`](../../pgsql-migration.yml) | Generate migration plan |


## File Structure

```
roles/pg_migration/
├── defaults/
│   └── main.yml              # Default variables
├── meta/
│   └── main.yml              # Role dependencies
├── tasks/
│   └── main.yml              # Generate migration scripts
└── templates/
    ├── manual.md             # Migration manual template
    ├── activate              # Environment activation script
    ├── check-user            # User validation script
    ├── check-db              # Database validation script
    ├── check-hba             # HBA rules validation script
    ├── check-repl            # Replica identity validation
    ├── check-misc            # Miscellaneous checks
    ├── copy-schema           # Schema copy script
    ├── copy-seq              # Sequence sync script
    ├── copy-progress         # Replication progress monitor
    ├── copy-diff             # Table count diff checker
    ├── create-pub            # Create publication script
    ├── drop-pub              # Drop publication script
    ├── create-sub            # Create subscription script
    └── drop-sub              # Drop subscription script
```


## Tags

### Tag Hierarchy

```
pg_migration
├── check                      # Parameter validation
├── dir                        # Create migration context
├── manual                     # Generate migration manual
└── script                     # Generate migration scripts
    ├── activate               # Environment setup
    ├── check-user             # User checks
    ├── check-db               # Database checks
    ├── check-hba              # HBA checks
    ├── check-repl             # Replica identity checks
    ├── check-misc             # Miscellaneous checks
    ├── copy-schema            # Schema migration
    ├── copy-seq               # Sequence synchronization
    ├── copy-progress          # Progress monitoring
    ├── copy-diff              # Data diff checking
    ├── create-pub             # Publication creation
    ├── drop-pub               # Publication removal
    ├── create-sub             # Subscription creation
    └── drop-sub               # Subscription removal
```


## Key Variables

### Required Parameters

| Variable  | Description                    |
|-----------|--------------------------------|
| `src_cls` | Source cluster name            |
| `src_db`  | Source database name           |
| `src_ip`  | Source cluster primary IP      |
| `dst_cls` | Destination cluster name       |
| `dst_db`  | Destination database name      |
| `dst_ip`  | Destination cluster primary IP |

### Optional Parameters

| Variable      | Default       | Description                 |
|---------------|---------------|-----------------------------|
| `context_dir` | `~/migration` | Migration context directory |
| `src_list`    | `[]`          | Source replica IPs          |
| `src_dns`     | (none)        | Source DNS name             |
| `src_vip`     | (none)        | Source VIP address          |
| `dst_dns`     | (none)        | Destination DNS name        |
| `dst_vip`     | (none)        | Destination VIP address     |

### Credential Parameters

| Variable                  | Default             | Description          |
|---------------------------|---------------------|----------------------|
| `pg_dbsu`                 | `postgres`          | Database superuser   |
| `pg_replication_username` | `replicator`        | Replication user     |
| `pg_replication_password` | `DBUser.Replicator` | Replication password |
| `pg_admin_username`       | `dbuser_dba`        | Admin user           |
| `pg_admin_password`       | `DBUser.DBA`        | Admin password       |


## Generated Scripts

### Environment Setup

| Script     | Purpose                                 |
|------------|-----------------------------------------|
| `activate` | Set environment variables for migration |

### Pre-Flight Checks

| Script       | Purpose                             |
|--------------|-------------------------------------|
| `check-user` | Verify users exist on both clusters |
| `check-db`   | Verify database settings match      |
| `check-hba`  | Verify HBA rules allow replication  |
| `check-repl` | Verify replica identities are set   |
| `check-misc` | Check for unsupported objects       |

### Data Migration

| Script          | Purpose                                |
|-----------------|----------------------------------------|
| `copy-schema`   | Copy schema from source to destination |
| `copy-seq`      | Synchronize sequences after migration  |
| `copy-progress` | Monitor logical replication progress   |
| `copy-diff`     | Compare row counts between clusters    |

### Logical Replication

| Script       | Purpose                            |
|--------------|------------------------------------|
| `create-pub` | Create publication on source       |
| `drop-pub`   | Drop publication on source         |
| `create-sub` | Create subscription on destination |
| `drop-sub`   | Drop subscription on destination   |


## Migration Workflow

### Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Migration Process                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. Pre-Flight Checks                                   │
│     └── check-user, check-db, check-hba, check-repl     │
│                                                         │
│  2. Schema Migration                                    │
│     └── copy-schema (pg_dump -s | psql)                 │
│                                                         │
│  3. Setup Logical Replication                           │
│     ├── create-pub (on source)                          │
│     └── create-sub (on destination)                     │
│                                                         │
│  4. Wait for Initial Sync                               │
│     └── copy-progress (monitor until 100%)              │
│                                                         │
│  5. Switchover                                          │
│     ├── Stop writes to source                           │
│     ├── copy-seq (sync sequences)                       │
│     ├── copy-diff (verify data)                         │
│     └── Switch application connections                  │
│                                                         │
│  6. Cleanup                                             │
│     ├── drop-sub (on destination)                       │
│     └── drop-pub (on source)                            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Detailed Steps

1. **Generate Plan**: Run `pgsql-migration.yml` with task definition
2. **Pre-Flight**: Execute check scripts to validate environment
3. **Schema Copy**: Transfer schema without data
4. **Publication**: Create publication on source for all tables
5. **Subscription**: Create subscription on destination to replicate data
6. **Initial Sync**: Wait for logical replication to catch up
7. **Verify**: Compare row counts between source and destination
8. **Switchover**: Stop source writes, sync sequences, redirect traffic
9. **Cleanup**: Remove publication and subscription


## Limitations

- Requires PostgreSQL 10+ for logical replication
- Tables must have primary keys or replica identity
- Large objects (LOBs) are not replicated
- DDL changes during migration require manual handling
- Sequences require manual synchronization at cutover


## See Also

- [`pgsql`](../pgsql): Deploy PostgreSQL cluster
- [Migration Guide](https://pigsty.io/docs/pgsql/migration): Detailed migration documentation
- [Logical Replication](https://www.postgresql.org/docs/current/logical-replication.html): PostgreSQL documentation
