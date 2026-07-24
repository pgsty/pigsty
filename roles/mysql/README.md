# Role: mysql

> Deploy native MySQL 8.4 standalone or three-node InnoDB Cluster

| **Module**   | MYSQL (PILOT)                                                           |
|--------------|-------------------------------------------------------------------------|
| **Playbook** | `mysql.yml`                                                             |
| **Removal**  | `mysql-rm.yml`, `mysql_remove`                                          |
| **Example**  | `conf/demo/mysql.yml`                                                   |
| **Stack**    | MySQL 8.4, Group Replication, MySQL Router, XtraBackup, mysqld_exporter |


## Overview

The role manages one MySQL instance per node and accepts exactly two topology
shapes:

- one member: standalone MySQL;
- three members: InnoDB Cluster using single-primary Group Replication.

MySQL is a fixed Pigsty platform, not a general MySQL installer. The server,
client, Shell, Router, and XtraBackup line is fixed at 8.4. Public variables do
not expose package versions, ports, directories, character set, TLS paths,
memory sizes, or timer expressions.

In HA mode, MySQL Shell AdminAPI forms and reconciles the cluster. `mysql_seq=1`
is only the initial coordinator; the runtime PRIMARY is discovered and is not
forced back to sequence 1 on reruns. Every member runs Router with classic RW
and RO endpoints on `6446` and `6447`.

MYSQL remains a PILOT module. Ordinary reconciliation refuses unknown datadirs,
foreign InnoDB Cluster metadata, partial HA inventory limits, destructive Clone
over non-fresh members, and complete-outage recovery.

The native package gate admits the declared x86_64 DEB/RPM matrix and EL9/EL10
ARM64. Ubuntu/Debian ARM64 is intentionally rejected because Oracle's APT
repository currently publishes the 8.4 component for `amd64`, not `arm64`.


## Public Interface

Only the following variables are intended for inventory use:

| Variable                 | Default          | Description                          |
|--------------------------|------------------|--------------------------------------|
| `mysql_cluster`          | required         | cluster name; normally group name    |
| `mysql_seq`              | required         | `1` for standalone, `1..3` for HA    |
| `mysql_root_password`    | `DBUser.Root`    | local root password                  |
| `mysql_monitor_password` | `DBUser.Monitor` | exporter account password            |
| `mysql_cluster_password` | `DBUser.Cluster` | AdminAPI and backup password         |
| `mysql_databases`        | `[]`             | additive database declarations       |
| `mysql_users`            | `[]`             | additive user and grant declarations |
| `mysql_backup_enabled`   | `true`           | enable one daily full backup timer   |
| `mysql_backup_repo`      | see defaults     | local repository and retention       |
| `mysql_exporter_enabled` | `true`           | exporter service and target state    |

The fixed defaults live in [`vars/main.yml`](vars/main.yml) and are internal.
InnoDB buffer pool and redo capacity are derived from `node_mem_mb`; replica
workers are derived from `node_cpu`. Inventory host names are the advertised
MySQL and MGR addresses, matching the rest of Pigsty's node model.

Example:

```yaml
my-test:
  hosts:
    10.10.10.11: { mysql_seq: 1 }
    10.10.10.12: { mysql_seq: 2 }
    10.10.10.13: { mysql_seq: 3 }
  vars:
    mysql_cluster: my-test
    mysql_databases:
      - { name: app }
    mysql_users:
      - name: app
        password: DBUser.App
        priv: { 'app.*': 'ALL PRIVILEGES' }
```


## Components

| Component         | Purpose                                        | Endpoint                   |
|-------------------|------------------------------------------------|----------------------------|
| `mysqld`          | standalone server or MGR member                | `3306`, X Protocol `33060` |
| Group Replication | three-member consensus and replication         | `33061`                    |
| MySQL Router      | topology-aware client routing on every HA node | RW `6446`, RO `6447`       |
| MySQL Shell       | AdminAPI cluster lifecycle                     | local control plane        |
| XtraBackup        | one daily prepared full physical backup        | local storage              |
| mysqld_exporter   | server and MGR metrics                         | `9104`                     |

The role creates three platform identities:

- `dbuser_cluster@'%'`: TLS-only AdminAPI account;
- `dbuser_monitor@'127.0.0.1'`: least-privilege exporter account;
- `dbuser_backup@'localhost'`: local XtraBackup account.

Declared databases and users are additive. The role does not implicitly drop
objects or revoke grants.


## PKI

`node_ca` owns the trusted node CA and installs it once at
`/etc/pki/ca.crt`. The MySQL role requires that prerequisite and never copies
the CA into MySQL, Router, or Exporter directories.

The controller-side CA is used only to sign the MySQL leaf certificate:

```text
files/pki/
├── ca/ca.crt
├── ca/ca.key
├── csr/<instance>.csr
└── mysql/<instance>.{key,crt}
```

Each node gets one certificate containing its address, instance name, cluster
name, and localhost SANs. Mysqld and Router share that same leaf certificate;
the private key is readable only by their service identities. All clients and
services reference the shared `/etc/pki/ca.crt` trust anchor.


## Monitoring

Each node has one VictoriaMetrics file-SD document:

```text
/infra/targets/mysql/<instance>.yml
```

The document contains only the mysqld_exporter target. Vector journal
registration remains in the existing per-node Pigsty configuration. Ordinary
reconciliation overwrites this document, using `[]` when the exporter is not
enabled; only `mysql_remove` deletes target files.


## Backup

The v1 backup contract is deliberately small:

- fixed daily systemd timer;
- full physical XtraBackup only;
- backup runs on standalone or the current MGR PRIMARY;
- local repository and retention are configured inside `mysql_backup_repo`.

There is no public schedule expression, incremental chain, continuous binlog
archive, PITR, or restore automation. Physical restore is a separate,
destructive operator runbook rather than an executable installed by this role.


## Tasks and Tags

```text
mysql
├── mysql_check       validate topology, scope, credentials, and retained state
├── mysql_install     install the fixed 8.4 platform package set
├── mysql_bootstrap
│   ├── mysql_cert    issue and install node TLS certificate
│   ├── mysql_config  render config and initialize an empty datadir
│   ├── mysql_launch  start mysqld and prepare AdminAPI identity
│   └── mysql_cluster reconcile the three-node InnoDB Cluster
├── mysql_access
│   └── mysql_router  reconcile Router on HA nodes
├── mysql_provision   reconcile platform and declared business objects
├── mysql_backup      configure daily full backup
└── mysql_monitor     exporter and unified file-SD target
```


## Safety and Operation

The normal role never clears a datadir, deletes InnoDB Cluster metadata,
performs forced removal, or recovers a complete outage. A non-empty datadir
must carry Pigsty's exact cluster/instance/topology marker. A retired marker
blocks normal reconciliation. In HA mode, ordinary reconciliation also refuses
an implicit `mysql_cluster_password` rotation; password rotation requires a
dedicated operator procedure.

Member retirement is isolated in `mysql_remove`. It requires
`mysql_safeguard=false` plus exact `mysql_rm_confirm`, preserves local data and
configuration, and can detach only an ONLINE SECONDARY with `force: false`.
The v1 replacement contract reuses the same advertised service address on a
fresh machine; changing a member address during replacement is not supported.

Before a real run, inspect the selected nodes and backups, then preview the
complete cluster scope:

```bash
./mysql.yml -l my-test --check
./mysql.yml -l my-test                 # requires explicit change approval
```

Syntax-only validation does not touch target nodes:

```bash
ansible-playbook -i conf/demo/mysql.yml mysql.yml --syntax-check
ansible-playbook -i conf/demo/mysql.yml mysql-rm.yml --syntax-check
```
