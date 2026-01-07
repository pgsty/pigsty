# Role: ferret

> Deploy FerretDB MongoDB-Compatible Interface

| **Module**        | [FERRET](https://pigsty.io/docs/ferret)        |
|-------------------|------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/ferret/                 |
| **Related Roles** | [`pgsql`](../pgsql), [`ca`](../ca)             |


## Overview

The `ferret` role deploys **FerretDB** on existing PostgreSQL clusters:

- Create mongod OS user and group
- Install FerretDB package
- Configure FerretDB environment
- Generate TLS certificates (optional)
- Launch FerretDB service
- Register to monitoring

FerretDB provides MongoDB wire protocol compatibility using PostgreSQL as the backend storage engine.


## Playbooks

| Playbook                             | Description            |
|--------------------------------------|------------------------|
| [`mongo.yml`](../../mongo.yml)       | Deploy FerretDB        |


## File Structure

```
roles/ferret/
├── defaults/
│   └── main.yml              # Default variables
├── meta/
│   └── main.yml              # Role dependencies
├── tasks/
│   ├── main.yml              # Entry point
│   └── cert.yml              # [mongo_cert] TLS certificates
└── templates/
    ├── ferretdb.env          # Environment config
    └── ferretdb.svc          # Systemd service
```


## Tags

### Tag Hierarchy

```
ferret (full role)
│
├── mongo_check                # Validate identity parameters
│
├── mongo_dbsu                 # Create mongod OS user/group
│
├── mongo_install              # Install FerretDB package
│
├── mongo_purge                # Remove existing (if enabled)
│   └── mongo_deregister       # Remove from monitoring
│
├── mongo_config               # Configure FerretDB
│   └── mongo_cert             # TLS certificates
│
├── mongo_launch               # Start FerretDB service
│
└── mongo_register             # Register to monitoring
    └── add_metrics            # Add Victoria targets
```


## Key Variables

### Identity (Required)

| Variable        | Level    | Description               |
|-----------------|----------|---------------------------|
| `mongo_cluster` | CLUSTER  | MongoDB cluster name      |
| `mongo_seq`     | INSTANCE | Instance sequence number  |
| `mongo_pgurl`   | INSTANCE | PostgreSQL connection URL |

### Network

| Variable           | Default  | Description                   |
|--------------------|----------|-------------------------------|
| `mongo_listen`     | `''`     | Listen address (empty = all)  |
| `mongo_port`       | `27017`  | MongoDB protocol port         |
| `mongo_ssl_port`   | `27018`  | TLS listen port               |

### Security

| Variable            | Default | Description              |
|---------------------|---------|--------------------------|
| `mongo_ssl_enabled` | `false` | Enable TLS connections   |

### Monitoring

| Variable              | Default | Description              |
|-----------------------|---------|--------------------------|
| `mongo_exporter_port` | `9216`  | Metrics exporter port    |


## PostgreSQL Backend

FerretDB requires a PostgreSQL database as backend storage:

```yaml
mongo:
  hosts:
    10.10.10.10:
      mongo_cluster: ferret
      mongo_seq: 1
      mongo_pgurl: 'postgres://dbuser_meta:DBUser.Meta@10.10.10.10:5432/meta'
```

The PostgreSQL connection URL must include:
- Username with appropriate privileges
- Password for authentication
- Host and port of PostgreSQL server
- Target database name


## TLS Configuration

Enable TLS for secure MongoDB connections:

```yaml
mongo_ssl_enabled: true
```

Certificates are signed by Pigsty CA:
- **CA**: `files/pki/ca/ca.crt`
- **Server Cert**: `/var/lib/mongod/server.crt`
- **Server Key**: `/var/lib/mongod/server.key`


## Purging FerretDB

To remove an existing FerretDB deployment:

```bash
./mongo.yml -l <target> -e mongo_purge=true -t mongo_purge
```


## See Also

- [`pgsql`](../pgsql): PostgreSQL cluster (backend storage)
- [`ca`](../ca): Certificate Authority
- [FerretDB Guide](https://pigsty.io/docs/ferret/): Configuration documentation
