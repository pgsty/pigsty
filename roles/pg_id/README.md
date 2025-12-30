# Role: pg_id

> Derive PostgreSQL Cluster Identity and Membership Information

| **Module**        | [PGSQL](https://pigsty.io/docs/pgsql)                                                              |
|-------------------|----------------------------------------------------------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/pgsql/config/#identity                                                      |
| **Related Roles** | [`pgsql`](../pgsql), [`node_id`](../node_id), [`pg_remove`](../pg_remove), [`pg_pitr`](../pg_pitr) |


## Overview

The `pg_id` role derives and calculates PostgreSQL identity information from inventory variables. It runs on the **control node** (connection: local) and computes:

- Instance identity (`pg_instance`, `pg_service`)
- Cluster membership (`pg_cluster_members`, `pg_cluster_size`)
- Primary/replica relationships (`pg_primary_ip`, `pg_is_primary`)
- Replication topology (`pg_cluster_replicas`, `pg_upstream`)

This role is a **prerequisite** for most PostgreSQL operations and always runs with the `always` tag.


## Playbooks

This role is included in most PGSQL playbooks:

| Playbook                                 | Description            |
|------------------------------------------|------------------------|
| [`pgsql.yml`](../../pgsql.yml)           | Full deployment        |
| [`pgsql-rm.yml`](../../pgsql-rm.yml)     | Cluster removal        |
| [`pgsql-pitr.yml`](../../pgsql-pitr.yml) | Point-in-time recovery |
| [`pgsql-user.yml`](../../pgsql-user.yml) | User management        |
| [`pgsql-db.yml`](../../pgsql-db.yml)     | Database management    |


## File Structure

```
roles/pg_id/
├── defaults/
│   └── main.yml              # Default variables (identity params)
├── meta/
│   └── main.yml              # Role dependencies
└── tasks/
    └── main.yml              # Identity derivation logic
```


## Tags

```
pg-id (always)                 # PostgreSQL identity derivation
```

The role runs with `tags: [always, pg-id]`, ensuring it executes regardless of tag filters.


## Derived Variables

### Instance Identity

| Variable        | Example           | Description                       |
|-----------------|-------------------|-----------------------------------|
| `pg_instance`   | `pg-test-1`       | Instance name (`<cluster>-<seq>`) |
| `pg_service`    | `pg-test-primary` | Service name (`<cluster>-<role>`) |
| `pg_is_primary` | `true`            | Whether this instance is primary  |

### Cluster Membership

| Variable              | Example                      | Description                    |
|-----------------------|------------------------------|--------------------------------|
| `pg_meta`             | `[...]`                      | All instances in the cluster   |
| `pg_cluster_size`     | `3`                          | Number of instances            |
| `pg_cluster_members`  | `[10.10.10.11, 10.10.10.12]` | All member IPs                 |
| `pg_cluster_replicas` | `[10.10.10.12, 10.10.10.13]` | Replica IPs                    |
| `pg_seq_next`         | `4`                          | Next available sequence number |

### Primary Information

| Variable          | Example         | Description             |
|-------------------|-----------------|-------------------------|
| `pg_primary_list` | `[10.10.10.11]` | Primary instance IP(s)  |
| `pg_primary_ip`   | `10.10.10.11`   | Primary IP address      |
| `pg_primary_seq`  | `1`             | Primary sequence number |
| `pg_primary_ins`  | `pg-test-1`     | Primary instance name   |


## Input Variables

### Required Identity

| Variable     | Level    | Description                                    |
|--------------|----------|------------------------------------------------|
| `pg_cluster` | CLUSTER  | Cluster name (required)                        |
| `pg_role`    | INSTANCE | Instance role: `primary`, `replica`, `offline` |
| `pg_seq`     | INSTANCE | Instance sequence number                       |

### Optional Identity

| Variable           | Level    | Default      | Description                     |
|--------------------|----------|--------------|---------------------------------|
| `pg_mode`          | CLUSTER  | `pgsql`      | Cluster mode                    |
| `pg_shard`         | CLUSTER  | `pg_cluster` | Shard name                      |
| `pg_group`         | CLUSTER  | `0`          | Shard group number              |
| `pg_upstream`      | INSTANCE | (none)       | Upstream IP for cascade replica |
| `pg_offline_query` | INSTANCE | `false`      | Enable offline queries          |
| `pg_weight`        | INSTANCE | `100`        | Load balance weight             |
| `pg_port`          | INSTANCE | `5432`       | PostgreSQL port                 |


## Identity Derivation

### Computation Logic

```yaml
# 1. Query all hosts with same pg_cluster
pg_meta: "{{ hostvars|json_query(cluster_query) }}"

# 2. Derive instance identity
pg_instance: "{{ pg_cluster }}-{{ pg_seq }}"
pg_service: "{{ pg_cluster }}-{{ pg_role }}"
pg_is_primary: "{{ pg_role == 'primary' }}"

# 3. Extract cluster membership
pg_cluster_size: <count of unique hosts>
pg_cluster_members: <sorted list of all IPs>
pg_cluster_replicas: <IPs where pg_role != 'primary'>
pg_seq_next: <max(pg_seq) + 1>

# 4. Identify primary
pg_primary_list: <IPs where pg_role == 'primary'>
pg_primary_ip: <single primary IP or 'unknown'>
pg_primary_seq: <primary's pg_seq>
pg_primary_ins: "<pg_cluster>-<pg_primary_seq>"
```

### Output Example

```
[primary] pg-test-1 @ 10.10.10.11 , ins = pg-test-1 , cls = pg-test ,
CLUSTER LEADER @ pg-test-1 , postgres://10.10.10.11:5432/postgres

[replica] pg-test-2 @ 10.10.10.12 , ins = pg-test-2 , cls = pg-test ,
REPLICATE PRIMARY pg-test-1 @ 10.10.10.11 -> pg-test-2 , postgres://10.10.10.12:5432/postgres
```


## Warnings

The role prints warnings for cluster configuration issues:

| Warning                     | Meaning                                    |
|-----------------------------|--------------------------------------------|
| `[WARN: NO CLUSTER LEADER]` | No instance with `pg_role: primary`        |
| `[WARN: MULTIPLE LEADER]`   | Multiple instances with `pg_role: primary` |


## Cluster Modes

The `pg_mode` parameter affects cluster behavior:

| Mode    | Description                       |
|---------|-----------------------------------|
| `pgsql` | Standard PostgreSQL cluster       |
| `citus` | Citus distributed cluster         |
| `gpsql` | Greenplum cluster                 |
| `mssql` | Babelfish (SQL Server compatible) |
| `mysql` | MySQL compatible mode             |
| `ivory` | IvorySQL (Oracle compatible)      |
| `polar` | PolarDB compatible                |


## See Also

- [`node_id`](../node_id): Node identity derivation
- [`pgsql`](../pgsql): PostgreSQL cluster deployment
- [Identity Parameters](https://pigsty.io/docs/pgsql/config/#identity): Configuration documentation
