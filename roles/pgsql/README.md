# Role: pgsql

> Deploy Production-Ready PostgreSQL HA Cluster with Patroni

| **Module**        | [PGSQL](https://pigsty.io/docs/pgsql)                                                                                                                                |
|-------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/pgsql                                                                                                                                         |
| **Related Roles** | [`pg_id`](../pg_id), [`pg_remove`](../pg_remove), [`pg_monitor`](../pg_monitor), [`pg_pitr`](../pg_pitr), [`pg_exporters`](../pg_exporters), [`haproxy`](../haproxy) |


## Overview

The `pgsql` role is the **core role** for deploying PostgreSQL clusters in Pigsty. It provisions a complete, production-ready PostgreSQL HA cluster with:

- **Patroni** for HA orchestration with automatic failover
- **pgBackRest** for PITR backup and recovery
- **pgBouncer** for connection pooling
- **VIP Manager** for L2 VIP binding
- **HAProxy** for service exposure and load balancing
- **DNS** registration for service discovery


## Playbooks

| Playbook                                 | Description                                      |
|------------------------------------------|--------------------------------------------------|
| [`pgsql.yml`](../../pgsql.yml)           | Full cluster deployment (id + pgsql + monitor)   |
| [`pgsql-user.yml`](../../pgsql-user.yml) | Manage business users only                       |
| [`pgsql-db.yml`](../../pgsql-db.yml)     | Manage databases only                            |
| [`pgsql-rm.yml`](../../pgsql-rm.yml)     | Remove cluster (use [`pg_remove`](../pg_remove)) |


## File Structure

```
roles/pgsql/
├── defaults/
│   └── main.yml              # Default variables (lowest priority)
├── handlers/
│   └── main.yml              # Event handlers (reload/restart)
├── meta/
│   └── main.yml              # Role dependencies
├── tasks/
│   ├── main.yml              # Entry point: orchestrates all subtasks
│   ├── dbsu.yml              # [pg_dbsu] Create postgres OS user
│   ├── install.yml           # [pg_install] Install packages & extensions
│   ├── config.yml            # [pg_config] Generate patroni/postgres config
│   ├── cert.yml              # [pg_cert] Issue SSL certificates
│   ├── patroni.yml           # [pg_launch] Bootstrap Patroni cluster
│   ├── user.yml              # [pg_user] Provision business users
│   ├── database.yml          # [pg_db] Provision business databases
│   ├── pgbackrest.yml        # [pgbackrest] Setup backup
│   ├── pgbouncer.yml         # [pgbouncer] Deploy connection pooler
│   ├── vip.yml               # [pg_vip] Configure L2 VIP
│   ├── dns.yml               # [pg_dns] Register DNS names
│   ├── service_local.yml     # [pg_service] Local HAProxy config
│   └── service_remote.yml    # [pg_service] Remote HAProxy config
├── templates/
│   ├── patroni.svc           # Patroni systemd service
│   ├── oltp.yml / olap.yml / crit.yml / tiny.yml  # Patroni config templates
│   ├── pg_hba.conf           # PostgreSQL HBA template
│   ├── pg-init               # Cluster initialization script
│   ├── pg-init-roles.sql     # Default roles SQL
│   ├── pg-init-template.sql  # Template database SQL
│   ├── pg-user.sql           # User creation template
│   ├── pg-db.sql             # Database creation template
│   ├── pgbackrest.conf       # pgBackRest configuration
│   ├── pgbouncer.ini         # pgBouncer configuration
│   ├── pgbouncer.svc         # pgBouncer systemd service
│   ├── pgbouncer.hba         # pgBouncer HBA template
│   ├── vip-manager.yml       # VIP Manager configuration
│   ├── vip-manager.svc       # VIP Manager systemd service
│   ├── service.cfg           # HAProxy service template
│   └── ...
└── vars/
    └── main.yml              # Internal variables (do not override)
```


## Tags

### Tag Hierarchy

```
pgsql (full role)
│
├── pg_install                 # Software installation
│   └── pg_dbsu                # Create postgres superuser
│       ├── pg_dbsu_create     # Create postgres OS user
│       ├── pg_dbsu_sudo       # Configure sudo permissions
│       └── pg_ssh             # Exchange SSH keys among cluster
│   ├── pg_pkg                 # Install postgres packages
│   │   ├── pg_pre             # Pre-install tasks
│   │   ├── pg_ext             # Install extensions
│   │   └── pg_post            # Post-install tasks
│   ├── pg_link                # Link pg version to /usr/pgsql
│   ├── pg_path                # Add pg bin to PATH
│   ├── pg_dir                 # Create data directories
│   ├── pg_bin                 # Sync /pg/bin scripts
│   ├── pg_alias               # Write shell aliases
│   └── pg_dummy               # Create dummy placeholder file
│
├── pg_bootstrap               # Cluster bootstrap
│   ├── pg_config              # Generate configuration files
│   │   ├── pg_conf            # Generate patroni config
│   │   └── pg_key             # Generate pgsodium key
│   ├── pg_cert                # Issue SSL certificates
│   │   ├── pg_cert_private    # Check private key
│   │   ├── pg_cert_issue      # Sign certificates
│   │   └── pg_cert_copy       # Copy certs to node
│   └── pg_launch              # Launch Patroni cluster
│       ├── pg_watchdog        # Setup watchdog permission
│       ├── pg_primary         # Bootstrap primary
│       ├── pg_init            # Initialize cluster
│       ├── pg_pass            # Write .pgpass file
│       ├── pg_replica         # Bootstrap replicas
│       ├── pg_hba             # Generate HBA rules
│       ├── patroni_reload     # Reload patroni config
│       └── pg_patroni         # Patroni mode control
│
├── pg_provision               # Business object provisioning
│   ├── pg_user                # Create business users
│   │   ├── pg_user_config     # Render user SQL
│   │   └── pg_user_create     # Execute user creation
│   └── pg_db                  # Create business databases
│       ├── pg_db_drop         # Drop database if needed
│       ├── pg_db_config       # Render database SQL
│       ├── pg_db_create       # Execute database creation
│       └── pg_db_baseline     # Apply baseline schema
│
├── pg_backup                  # Backup initialization
│   └── pgbackrest             # pgBackRest setup
│       ├── pgbackrest_config  # Generate config
│       ├── pgbackrest_init    # Initialize stanza
│       └── pgbackrest_backup  # Initial full backup
│
└── pg_access                  # Access layer setup
    ├── pgbouncer              # Connection pooling
    │   ├── pgbouncer_dir      # Create directories
    │   ├── pgbouncer_config   # Generate config
    │   ├── pgbouncer_hba      # Generate HBA
    │   ├── pgbouncer_user     # Generate userlist
    │   ├── pgbouncer_launch   # Start service
    │   └── pgbouncer_reload   # Reload config
    ├── pg_vip                 # L2 VIP binding
    │   ├── pg_vip_config      # Generate VIP config
    │   └── pg_vip_launch      # Start VIP manager
    ├── pg_dns                 # DNS registration
    │   ├── pg_dns_ins         # Register instance
    │   └── pg_dns_cls         # Register cluster
    └── pg_service             # HAProxy services
        ├── pg_service_config  # Generate HAProxy config
        └── pg_service_reload  # Reload HAProxy
```

### Usage Examples

```bash
# Full deployment
./pgsql.yml -l pg-test

# Install packages only
./pgsql.yml -l pg-test -t pg_install

# Bootstrap cluster only
./pgsql.yml -l pg-test -t pg_bootstrap

# Provision users and databases
./pgsql.yml -l pg-test -t pg_provision

# Refresh pgbouncer config
./pgsql.yml -l pg-test -t pgbouncer_config,pgbouncer_reload

# Refresh HBA rules
./pgsql.yml -l pg-test -t pg_hba,pgbouncer_hba -e pg_reload=true

# Refresh services only
./pgsql.yml -l pg-test -t pg_service
```


## Key Variables

### Identity (Required)

| Variable     | Level        | Description                                    |
|--------------|--------------|------------------------------------------------|
| `pg_cluster` | **CLUSTER**  | Cluster name (required)                        |
| `pg_role`    | **INSTANCE** | Instance role: `primary`, `replica`, `offline` |
| `pg_seq`     | **INSTANCE** | Instance sequence number                       |

### Installation

| Variable        | Default                     | Description               |
|-----------------|-----------------------------|---------------------------|
| `pg_version`    | `17`                        | PostgreSQL major version  |
| `pg_packages`   | `[pgsql-main pgsql-common]` | Packages to install       |
| `pg_extensions` | `[]`                        | Extensions to install     |
| `pg_dbsu`       | `postgres`                  | Database superuser name   |
| `pg_dbsu_uid`   | `26`                        | UID/GID for postgres user |
| `pg_dbsu_sudo`  | `limit`                     | Sudo privilege level      |

### Bootstrap

| Variable                 | Default    | Description          |
|--------------------------|------------|----------------------|
| `pg_data`                | `/pg/data` | Data directory       |
| `pg_port`                | `5432`     | Listen port          |
| `pg_conf`                | `oltp.yml` | Config template      |
| `pg_max_conn`            | `auto`     | Max connections      |
| `pg_shared_buffer_ratio` | `0.25`     | Shared buffers ratio |
| `patroni_enabled`        | `true`     | Enable Patroni       |
| `patroni_port`           | `8008`     | Patroni API port     |

### Backup

| Variable             | Default | Description              |
|----------------------|---------|--------------------------|
| `pgbackrest_enabled` | `true`  | Enable pgBackRest        |
| `pgbackrest_method`  | `local` | Repo method: local/minio |
| `pgbackrest_repo`    | `{...}` | Repository configuration |

### Access

| Variable             | Default        | Description      |
|----------------------|----------------|------------------|
| `pgbouncer_enabled`  | `true`         | Enable pgBouncer |
| `pgbouncer_port`     | `6432`         | pgBouncer port   |
| `pgbouncer_poolmode` | `transaction`  | Pooling mode     |
| `pg_vip_enabled`     | `false`        | Enable L2 VIP    |
| `pg_vip_address`     | `127.0.0.1/24` | VIP address      |

### Business Objects

| Variable       | Default | Description               |
|----------------|---------|---------------------------|
| `pg_users`     | `[]`    | Business user definitions |
| `pg_databases` | `[]`    | Database definitions      |
| `pg_services`  | `[]`    | Service definitions       |
| `pg_hba_rules` | `[]`    | Custom HBA rules          |

Full parameter list: [PGSQL Configuration](https://pigsty.io/docs/pgsql/config)


## See Also

- [`pg_id`](../pg_id): Get PostgreSQL identity information
- [`pg_remove`](../pg_remove): Remove PostgreSQL cluster
- [`pg_monitor`](../pg_monitor): Setup monitoring exporters
- [`pg_pitr`](../pg_pitr): Point-in-time recovery
- [`pg_exporters`](../pg_exporters): Remote monitoring setup
